package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/jwtauth/v5"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"-"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type AuthResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

var (
	tokenAuth *jwtauth.JWTAuth
	db        *sql.DB
)

func main() {
	// Inicializar o JWT Auth
	tokenAuth = jwtauth.New("HS256", []byte(getEnv("JWT_SECRET", "secret_change_me")), nil)

	// Conectar ao banco de dados
	var err error
	dbHost := getEnv("DB_HOST", "postgres")
	dbPort := getEnv("DB_PORT", "5432")
	dbName := getEnv("DB_NAME", "fiapx_auth")
	dbUser := getEnv("DB_USER", "postgres")
	dbPassword := getEnv("DB_PASSWORD", "postgres")

	dbInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword, dbName)

	db, err = sql.Open("postgres", dbInfo)
	if err != nil {
		log.Fatalf("Erro ao conectar ao banco de dados: %v", err)
	}
	defer db.Close()

	// Verificar conexão com o banco de dados
	err = db.Ping()
	if err != nil {
		log.Fatalf("Erro ao conectar ao banco de dados: %v", err)
	}

	// Criar tabela de usuários se não existir
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id SERIAL PRIMARY KEY,
			username VARCHAR(100) NOT NULL,
			email VARCHAR(100) NOT NULL UNIQUE,
			password VARCHAR(100) NOT NULL,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		log.Fatalf("Erro ao criar tabela de usuários: %v", err)
	}

	// Inicializar o router
	r := chi.NewRouter()

	// Middleware básico
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))

	// Rotas públicas
	r.Group(func(r chi.Router) {
		r.Get("/", func(w http.ResponseWriter, r *http.Request) {
			w.Write([]byte("Auth Service - FiapX Video Processing"))
		})

		r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
			w.Write([]byte("OK"))
		})

		r.Post("/register", handleRegister)
		r.Post("/login", handleLogin)
	})

	// Rotas protegidas (requerem JWT)
	r.Group(func(r chi.Router) {
		// Middleware JWT
		r.Use(jwtauth.Verifier(tokenAuth))
		r.Use(jwtauth.Authenticator)

		r.Get("/me", handleGetMe)
	})

	// Iniciar o servidor
	port := getEnv("PORT", "8081")
	fmt.Printf("Starting Auth service on port %s...\n", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func handleRegister(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Validar campos
	if req.Username == "" || req.Email == "" || req.Password == "" {
		http.Error(w, "Username, email e password são obrigatórios", http.StatusBadRequest)
		return
	}

	// Verificar se o email já existe
	var exists bool
	err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", req.Email).Scan(&exists)
	if err != nil {
		http.Error(w, "Erro ao verificar usuário", http.StatusInternalServerError)
		return
	}

	if exists {
		http.Error(w, "Email já cadastrado", http.StatusConflict)
		return
	}

	// Hash da senha
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "Erro ao processar senha", http.StatusInternalServerError)
		return
	}

	// Inserir novo usuário
	var userID int
	err = db.QueryRow(
		"INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING id",
		req.Username, req.Email, string(hashedPassword),
	).Scan(&userID)

	if err != nil {
		http.Error(w, "Erro ao criar usuário", http.StatusInternalServerError)
		return
	}

	// Gerar JWT
	_, tokenString, _ := tokenAuth.Encode(map[string]interface{}{
		"user_id":  userID,
		"username": req.Username,
		"email":    req.Email,
		"exp":      time.Now().Add(24 * time.Hour).Unix(),
	})

	// Retornar resposta
	user := User{
		ID:       userID,
		Username: req.Username,
		Email:    req.Email,
	}

	response := AuthResponse{
		Token: tokenString,
		User:  user,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Validar campos
	if req.Email == "" || req.Password == "" {
		http.Error(w, "Email e password são obrigatórios", http.StatusBadRequest)
		return
	}

	// Buscar usuário
	var user User
	var hashedPassword string
	err = db.QueryRow(
		"SELECT id, username, email, password FROM users WHERE email = $1",
		req.Email,
	).Scan(&user.ID, &user.Username, &user.Email, &hashedPassword)

	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "Credenciais inválidas", http.StatusUnauthorized)
		} else {
			http.Error(w, "Erro ao buscar usuário", http.StatusInternalServerError)
		}
		return
	}

	// Verificar senha
	err = bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(req.Password))
	if err != nil {
		http.Error(w, "Credenciais inválidas", http.StatusUnauthorized)
		return
	}

	// Gerar JWT
	_, tokenString, _ := tokenAuth.Encode(map[string]interface{}{
		"user_id":  user.ID,
		"username": user.Username,
		"email":    user.Email,
		"exp":      time.Now().Add(24 * time.Hour).Unix(),
	})

	// Retornar resposta
	response := AuthResponse{
		Token: tokenString,
		User:  user,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func handleGetMe(w http.ResponseWriter, r *http.Request) {
	_, claims, _ := jwtauth.FromContext(r.Context())
	
	userID := int(claims["user_id"].(float64))
	
	var user User
	err := db.QueryRow(
		"SELECT id, username, email FROM users WHERE id = $1",
		userID,
	).Scan(&user.ID, &user.Username, &user.Email)

	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "Usuário não encontrado", http.StatusNotFound)
		} else {
			http.Error(w, "Erro ao buscar usuário", http.StatusInternalServerError)
		}
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

// Obter variável de ambiente com valor padrão
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
