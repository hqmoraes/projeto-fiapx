package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gorilla/mux"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/streadway/amqp"
	"github.com/rs/cors"
	"github.com/golang-jwt/jwt/v5"
)

type UploadService struct {
	MinioClient *minio.Client
	RabbitConn  *amqp.Connection
	RabbitCh    *amqp.Channel
}

type UploadResponse struct {
	ID       string    `json:"id"`
	Filename string    `json:"filename"`
	Size     int64     `json:"size"`
	Status   string    `json:"status"`
	UploadedAt time.Time `json:"uploaded_at"`
}

type ProcessingMessage struct {
	VideoID    string `json:"video_id"`
	Filename   string `json:"filename"`
	Bucket     string `json:"bucket"`
	ObjectName string `json:"object_name"`
	UserID     string `json:"user_id"`
}

func NewUploadService() (*UploadService, error) {
	// Configurar MinIO
	minioEndpoint := getEnv("MINIO_ENDPOINT", "minio:9000")
	minioAccessKey := getEnv("MINIO_ACCESS_KEY", "minioadmin")
	minioSecretKey := getEnv("MINIO_SECRET_KEY", "minioadmin")
	minioUseSSL := getEnv("MINIO_USE_SSL", "false") == "true"

	minioClient, err := minio.New(minioEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(minioAccessKey, minioSecretKey, ""),
		Secure: minioUseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("erro ao conectar com MinIO: %v", err)
	}

	// Configurar RabbitMQ
	rabbitURL := getEnv("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
	rabbitConn, err := amqp.Dial(rabbitURL)
	if err != nil {
		return nil, fmt.Errorf("erro ao conectar com RabbitMQ: %v", err)
	}

	rabbitCh, err := rabbitConn.Channel()
	if err != nil {
		return nil, fmt.Errorf("erro ao criar canal RabbitMQ: %v", err)
	}

	// Declarar fila de processamento
	_, err = rabbitCh.QueueDeclare(
		"video_processing", // nome da fila
		true,               // durable
		false,              // delete when unused
		false,              // exclusive
		false,              // no-wait
		nil,                // arguments
	)
	if err != nil {
		return nil, fmt.Errorf("erro ao declarar fila: %v", err)
	}

	// Criar bucket se não existir
	bucketName := "video-uploads"
	exists, err := minioClient.BucketExists(ctx, bucketName)
	if err != nil {
		return nil, fmt.Errorf("erro ao verificar bucket: %v", err)
	}
	if !exists {
		err = minioClient.MakeBucket(ctx, bucketName, minio.MakeBucketOptions{})
		if err != nil {
			return nil, fmt.Errorf("erro ao criar bucket: %v", err)
		}
		log.Printf("Bucket %s criado com sucesso", bucketName)
	}

	return &UploadService{
		MinioClient: minioClient,
		RabbitConn:  rabbitConn,
		RabbitCh:    rabbitCh,
	}, nil
}

func (us *UploadService) UploadVideoHandler(w http.ResponseWriter, r *http.Request) {
	// Verificar método
	if r.Method != http.MethodPost {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	// Parse do multipart form
	err := r.ParseMultipartForm(100 << 20) // 100 MB max
	if err != nil {
		http.Error(w, "Erro ao processar formulário", http.StatusBadRequest)
		return
	}

	// Obter arquivo
	file, header, err := r.FormFile("video")
	if err != nil {
		http.Error(w, "Arquivo não encontrado", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Validar tipo de arquivo
	if !isValidVideoFile(header.Filename) {
		http.Error(w, "Tipo de arquivo não suportado", http.StatusBadRequest)
		return
	}

	// Gerar ID único para o vídeo
	videoID := generateVideoID()
	fileExt := filepath.Ext(header.Filename)
	objectName := fmt.Sprintf("%s%s", videoID, fileExt)

	// Upload para MinIO
	_, err = us.MinioClient.PutObject(ctx, "video-uploads", objectName, file, header.Size, minio.PutObjectOptions{
		ContentType: "video/*",
	})
	if err != nil {
		log.Printf("Erro ao fazer upload para MinIO: %v", err)
		http.Error(w, "Erro interno do servidor", http.StatusInternalServerError)
		return
	}

	// Extrair user_id do token JWT
	authHeader := r.Header.Get("Authorization")
	userID, err := getUserIDFromToken(authHeader)
	if err != nil {
		log.Printf("Erro ao extrair user_id do token: %v", err)
		http.Error(w, "Token de autenticação inválido", http.StatusUnauthorized)
		return
	}

	// Enviar mensagem para fila de processamento
	message := ProcessingMessage{
		VideoID:    videoID,
		Filename:   header.Filename,
		Bucket:     "video-uploads",
		ObjectName: objectName,
		UserID:     userID,
	}

	messageBytes, err := json.Marshal(message)
	if err != nil {
		log.Printf("Erro ao serializar mensagem: %v", err)
		http.Error(w, "Erro interno do servidor", http.StatusInternalServerError)
		return
	}

	err = us.RabbitCh.Publish(
		"",                 // exchange
		"video_processing", // routing key
		false,              // mandatory
		false,              // immediate
		amqp.Publishing{
			ContentType: "application/json",
			Body:        messageBytes,
		})
	if err != nil {
		log.Printf("Erro ao enviar mensagem: %v", err)
		http.Error(w, "Erro interno do servidor", http.StatusInternalServerError)
		return
	}

	// Resposta de sucesso
	response := UploadResponse{
		ID:         videoID,
		Filename:   header.Filename,
		Size:       header.Size,
		Status:     "uploaded",
		UploadedAt: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (us *UploadService) HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"service": "upload-service",
	})
}

func isValidVideoFile(filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	validExts := []string{".mp4", ".avi", ".mov", ".mkv", ".webm"}
	for _, validExt := range validExts {
		if ext == validExt {
			return true
		}
	}
	return false
}

func generateVideoID() string {
	return fmt.Sprintf("video_%d", time.Now().UnixNano())
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// Extrair user ID do JWT token
func getUserIDFromToken(tokenString string) (string, error) {
	if tokenString == "" {
		return "", fmt.Errorf("token vazio")
	}
	
	// Remover "Bearer " se presente
	if strings.HasPrefix(tokenString, "Bearer ") {
		tokenString = strings.TrimPrefix(tokenString, "Bearer ")
	}
	
	// Parse do token (sem validação da assinatura para simplicidade)
	token, _, err := new(jwt.Parser).ParseUnverified(tokenString, jwt.MapClaims{})
	if err != nil {
		return "", fmt.Errorf("erro ao fazer parse do token: %v", err)
	}
	
	// Extrair claims
	if claims, ok := token.Claims.(jwt.MapClaims); ok {
		if userID, ok := claims["user_id"].(float64); ok {
			return fmt.Sprintf("%.0f", userID), nil // Converter float64 para string
		}
		return "", fmt.Errorf("user_id não encontrado no token")
	}
	
	return "", fmt.Errorf("claims inválidas")
}

var ctx = context.Background()

func main() {
	// Inicializar serviço
	uploadService, err := NewUploadService()
	if err != nil {
		log.Fatalf("Erro ao inicializar upload service: %v", err)
	}
	defer uploadService.RabbitConn.Close()
	defer uploadService.RabbitCh.Close()

	// Configurar rotas
	r := mux.NewRouter()
	r.HandleFunc("/upload", uploadService.UploadVideoHandler).Methods("POST")
	r.HandleFunc("/health", uploadService.HealthHandler).Methods("GET")

	// Configurar CORS
	c := cors.New(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"*"},
		AllowCredentials: true,
	})

	// Aplicar CORS middleware
	handler := c.Handler(r)

	// Configurar servidor
	port := getEnv("PORT", "8080")
	log.Printf("Upload Service iniciado na porta %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}
