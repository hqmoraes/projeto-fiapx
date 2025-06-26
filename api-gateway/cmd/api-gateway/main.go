package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/go-chi/jwtauth/v5"
)

var (
	tokenAuth *jwtauth.JWTAuth
)

func main() {
	// Inicializar o router
	r := chi.NewRouter()

	// Middleware básico
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))

	// Configurar CORS
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Rotas públicas
	r.Group(func(r chi.Router) {
		r.Get("/", func(w http.ResponseWriter, r *http.Request) {
			w.Write([]byte("API Gateway - FiapX Video Processing"))
		})

		r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
			w.Write([]byte("OK"))
		})

		// Rota para o serviço de autenticação
		r.Route("/auth", func(r chi.Router) {
			r.Post("/login", forwardToService("auth-service", "/login"))
			r.Post("/register", forwardToService("auth-service", "/register"))
		})
	})

	// Rotas protegidas
	r.Group(func(r chi.Router) {
		// Middleware JWT
		tokenAuth = jwtauth.New("HS256", []byte(getEnv("JWT_SECRET", "secret_change_me")), nil)
		r.Use(jwtauth.Verifier(tokenAuth))
		r.Use(jwtauth.Authenticator)

		// Rotas para o serviço de upload
		r.Route("/videos", func(r chi.Router) {
			r.Post("/upload", forwardToService("upload-service", "/upload"))
			r.Get("/", forwardToService("storage-service", "/videos"))
			r.Get("/{id}", forwardToService("storage-service", "/videos/{id}"))
		})
	})

	// Iniciar o servidor
	port := getEnv("PORT", "8080")
	fmt.Printf("Starting API Gateway server on port %s...\n", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

// Função para encaminhar requisições para o serviço apropriado
func forwardToService(service, path string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Na versão real, isso faria proxy para o serviço correto
		// Por enquanto, apenas retornamos uma mensagem
		serviceURL := getServiceURL(service)
		w.Write([]byte(fmt.Sprintf("Forwarding to %s%s", serviceURL, path)))
	}
}

// Obter URL do serviço baseado no nome
func getServiceURL(service string) string {
	switch service {
	case "auth-service":
		return getEnv("AUTH_SERVICE_URL", "http://auth-service:8081")
	case "upload-service":
		return getEnv("UPLOAD_SERVICE_URL", "http://upload-service:8082")
	case "storage-service":
		return getEnv("STORAGE_SERVICE_URL", "http://storage-service:8084")
	default:
		return ""
	}
}

// Obter variável de ambiente com valor padrão
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
