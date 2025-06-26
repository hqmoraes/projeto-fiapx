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

type ProcessingService struct {
	MinioClient *minio.Client
	RabbitConn  *amqp.Connection
	RabbitCh    *amqp.Channel
}

type ProcessingMessage struct {
	VideoID    string `json:"video_id"`
	Filename   string `json:"filename"`
	Bucket     string `json:"bucket"`
	ObjectName string `json:"object_name"`
	UserID     string `json:"user_id"`
}

type ProcessingResult struct {
	VideoID       string                 `json:"video_id"`
	Status        string                 `json:"status"`
	ProcessedAt   time.Time              `json:"processed_at"`
	Resolutions   map[string]string      `json:"resolutions"`
	Metadata      map[string]interface{} `json:"metadata"`
	Error         string                 `json:"error,omitempty"`
}

func NewProcessingService() (*ProcessingService, error) {
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

	// Declarar filas
	_, err = rabbitCh.QueueDeclare("video_processing", true, false, false, false, nil)
	if err != nil {
		return nil, fmt.Errorf("erro ao declarar fila de processamento: %v", err)
	}

	_, err = rabbitCh.QueueDeclare("video_processed", true, false, false, false, nil)
	if err != nil {
		return nil, fmt.Errorf("erro ao declarar fila de resultados: %v", err)
	}

	// Criar bucket de vídeos processados se não existir
	bucketName := "video-processed"
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

	return &ProcessingService{
		MinioClient: minioClient,
		RabbitConn:  rabbitConn,
		RabbitCh:    rabbitCh,
	}, nil
}

func (ps *ProcessingService) StartProcessingWorker() {
	msgs, err := ps.RabbitCh.Consume(
		"video_processing", // queue
		"",                 // consumer
		false,              // auto-ack
		false,              // exclusive
		false,              // no-local
		false,              // no-wait
		nil,                // args
	)
	if err != nil {
		log.Fatalf("Erro ao configurar consumer: %v", err)
	}

	log.Println("Worker de processamento iniciado. Aguardando mensagens...")

	for msg := range msgs {
		var processingMsg ProcessingMessage
		err := json.Unmarshal(msg.Body, &processingMsg)
		if err != nil {
			log.Printf("Erro ao deserializar mensagem: %v", err)
			msg.Nack(false, false)
			continue
		}

		log.Printf("Processando vídeo: %s", processingMsg.VideoID)
		result := ps.processVideo(processingMsg)

		// Publicar resultado
		resultBytes, err := json.Marshal(result)
		if err != nil {
			log.Printf("Erro ao serializar resultado: %v", err)
			msg.Nack(false, true)
			continue
		}

		err = ps.RabbitCh.Publish(
			"",              // exchange
			"video_processed", // routing key
			false,           // mandatory
			false,           // immediate
			amqp.Publishing{
				ContentType: "application/json",
				Body:        resultBytes,
			})
		if err != nil {
			log.Printf("Erro ao publicar resultado: %v", err)
			msg.Nack(false, true)
			continue
		}

		msg.Ack(false)
		log.Printf("Vídeo processado com sucesso: %s", processingMsg.VideoID)
	}
}

func (ps *ProcessingService) processVideo(msg ProcessingMessage) ProcessingResult {
	result := ProcessingResult{
		VideoID:     msg.VideoID,
		ProcessedAt: time.Now(),
		Resolutions: make(map[string]string),
		Metadata:    make(map[string]interface{}),
	}

	// Simular processamento (em produção, aqui seria FFmpeg)
	time.Sleep(2 * time.Second)

	// Simular múltiplas resoluções
	resolutions := []string{"480p", "720p", "1080p"}
	for _, res := range resolutions {
		// Em produção, aqui processaríamos com FFmpeg
		outputKey := fmt.Sprintf("%s_%s.mp4", msg.VideoID, res)
		result.Resolutions[res] = outputKey
	}

	// Simular metadata
	result.Metadata["duration"] = "120.5"
	result.Metadata["format"] = "mp4"
	result.Metadata["size"] = "1048576"
	result.Status = "completed"

	return result
}

func (ps *ProcessingService) HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "processing-service",
	})
}

func (ps *ProcessingService) StatusHandler(w http.ResponseWriter, r *http.Request) {
	videoID := mux.Vars(r)["id"]
	
	// Em produção, consultaria banco de dados
	status := map[string]interface{}{
		"video_id": videoID,
		"status":   "processing",
		"progress": 75,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
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
	processingService, err := NewProcessingService()
	if err != nil {
		log.Fatalf("Erro ao inicializar processing service: %v", err)
	}
	defer processingService.RabbitConn.Close()
	defer processingService.RabbitCh.Close()

	// Iniciar worker em goroutine
	go processingService.StartProcessingWorker()

	// Configurar rotas HTTP
	r := mux.NewRouter()
	r.HandleFunc("/health", processingService.HealthHandler).Methods("GET")
	r.HandleFunc("/status/{id}", processingService.StatusHandler).Methods("GET")

	// Configurar servidor
	port := getEnv("PORT", "8080")
	log.Printf("Processing Service iniciado na porta %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
