package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/streadway/amqp"
)

type StorageService struct {
	MinioClient *minio.Client
	RabbitConn  *amqp.Connection
	RabbitCh    *amqp.Channel
}

type ProcessingResult struct {
	VideoID       string                 `json:"video_id"`
	Status        string                 `json:"status"`
	ProcessedAt   time.Time              `json:"processed_at"`
	Resolutions   map[string]string      `json:"resolutions"`
	Metadata      map[string]interface{} `json:"metadata"`
	Error         string                 `json:"error,omitempty"`
}

type VideoMetadata struct {
	VideoID     string                 `json:"video_id"`
	OriginalURL string                 `json:"original_url"`
	Resolutions map[string]string      `json:"resolutions"`
	Metadata    map[string]interface{} `json:"metadata"`
	Status      string                 `json:"status"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
}

func NewStorageService() (*StorageService, error) {
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

	// Declarar fila de resultados processados
	_, err = rabbitCh.QueueDeclare("video_processed", true, false, false, false, nil)
	if err != nil {
		return nil, fmt.Errorf("erro ao declarar fila: %v", err)
	}

	return &StorageService{
		MinioClient: minioClient,
		RabbitConn:  rabbitConn,
		RabbitCh:    rabbitCh,
	}, nil
}

func (ss *StorageService) StartStorageWorker() {
	msgs, err := ss.RabbitCh.Consume(
		"video_processed", // queue
		"",                // consumer
		false,             // auto-ack
		false,             // exclusive
		false,             // no-local
		false,             // no-wait
		nil,               // args
	)
	if err != nil {
		log.Fatalf("Erro ao configurar consumer: %v", err)
	}

	log.Println("Worker de storage iniciado. Aguardando resultados processados...")

	for msg := range msgs {
		var result ProcessingResult
		err := json.Unmarshal(msg.Body, &result)
		if err != nil {
			log.Printf("Erro ao deserializar resultado: %v", err)
			msg.Nack(false, false)
			continue
		}

		log.Printf("Armazenando metadata do vídeo: %s", result.VideoID)
		err = ss.storeVideoMetadata(result)
		if err != nil {
			log.Printf("Erro ao armazenar metadata: %v", err)
			msg.Nack(false, true)
			continue
		}

		msg.Ack(false)
		log.Printf("Metadata armazenada com sucesso: %s", result.VideoID)
	}
}

func (ss *StorageService) storeVideoMetadata(result ProcessingResult) error {
	// Em produção, seria armazenado em banco de dados
	metadata := VideoMetadata{
		VideoID:     result.VideoID,
		Resolutions: result.Resolutions,
		Metadata:    result.Metadata,
		Status:      result.Status,
		CreatedAt:   result.ProcessedAt,
		UpdatedAt:   time.Now(),
	}

	// Simular armazenamento
	log.Printf("Metadata armazenada: %+v", metadata)
	return nil
}

func (ss *StorageService) GetVideoHandler(w http.ResponseWriter, r *http.Request) {
	videoID := mux.Vars(r)["id"]
	resolution := r.URL.Query().Get("resolution")

	if resolution == "" {
		resolution = "720p"
	}

	// Em produção, consultaria banco de dados para obter URL do vídeo
	objectName := fmt.Sprintf("%s_%s.mp4", videoID, resolution)
	
	// Gerar URL pré-assinada para download
	presignedURL, err := ss.MinioClient.PresignedGetObject(
		ctx,
		"video-processed",
		objectName,
		time.Hour*24, // URL válida por 24 horas
		nil,
	)
	if err != nil {
		log.Printf("Erro ao gerar URL pré-assinada: %v", err)
		http.Error(w, "Vídeo não encontrado", http.StatusNotFound)
		return
	}

	response := map[string]interface{}{
		"video_id":    videoID,
		"resolution":  resolution,
		"url":         presignedURL.String(),
		"expires_in":  86400, // 24 horas em segundos
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (ss *StorageService) ListVideosHandler(w http.ResponseWriter, r *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "User ID obrigatório", http.StatusBadRequest)
		return
	}

	// Em produção, consultaria banco de dados
	videos := []map[string]interface{}{
		{
			"video_id":    "video_1234567890",
			"title":       "Vídeo de exemplo 1",
			"status":      "completed",
			"uploaded_at": "2025-06-26T14:00:00Z",
			"resolutions": []string{"480p", "720p", "1080p"},
		},
		{
			"video_id":    "video_0987654321",
			"title":       "Vídeo de exemplo 2", 
			"status":      "processing",
			"uploaded_at": "2025-06-26T15:00:00Z",
			"resolutions": []string{"480p"},
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"videos": videos,
		"total":  len(videos),
	})
}

func (ss *StorageService) HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "storage-service",
	})
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

var ctx = context.Background()

func main() {
	// Inicializar serviço
	storageService, err := NewStorageService()
	if err != nil {
		log.Fatalf("Erro ao inicializar storage service: %v", err)
	}
	defer storageService.RabbitConn.Close()
	defer storageService.RabbitCh.Close()

	// Iniciar worker em goroutine
	go storageService.StartStorageWorker()

	// Configurar rotas HTTP
	r := mux.NewRouter()
	r.HandleFunc("/health", storageService.HealthHandler).Methods("GET")
	r.HandleFunc("/videos/{id}", storageService.GetVideoHandler).Methods("GET")
	r.HandleFunc("/videos", storageService.ListVideosHandler).Methods("GET")

	// Configurar servidor
	port := getEnv("PORT", "8080")
	log.Printf("Storage Service iniciado na porta %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
