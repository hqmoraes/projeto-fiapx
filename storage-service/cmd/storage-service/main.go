package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
	"strings"
	"sync"
	"strconv"

	"github.com/gorilla/mux"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/streadway/amqp"
	"github.com/rs/cors"
	"github.com/golang-jwt/jwt/v5"
)

// Estrutura para armazenar vídeos em memória (simulando banco de dados)
type VideoData struct {
	VideoID       string    `json:"video_id"`
	Title         string    `json:"title"`
	Status        string    `json:"status"`
	UploadedAt    time.Time `json:"uploaded_at"`
	FrameCount    int       `json:"frame_count"`
	ZipSize       int64     `json:"zip_size"`
	ZipObjectName string    `json:"zip_object_name"`
	UserID        int       `json:"user_id"`
}

// Storage em memória para simular banco de dados
var (
	videosStore = make(map[string]*VideoData)
	storeMutex  = sync.RWMutex{}
)

// Inicializar dados de exemplo
func initSampleData() {
	storeMutex.Lock()
	defer storeMutex.Unlock()
	
	videosStore["video_1234567890"] = &VideoData{
		VideoID:       "video_1234567890",
		Title:         "Vídeo de exemplo 1",
		Status:        "completed",
		UploadedAt:    time.Date(2025, 6, 26, 14, 0, 0, 0, time.UTC),
		FrameCount:    120,
		ZipSize:       2048000,
		ZipObjectName: "frames_video_1234567890.zip",
		UserID:        7,
	}
	
	videosStore["video_0987654321"] = &VideoData{
		VideoID:       "video_0987654321",
		Title:         "Vídeo de exemplo 2",
		Status:        "processing",
		UploadedAt:    time.Date(2025, 6, 26, 15, 0, 0, 0, time.UTC),
		FrameCount:    0,
		ZipSize:       0,
		ZipObjectName: "",
		UserID:        7,
	}
}

type StorageService struct {
	MinioClient *minio.Client
	RabbitConn  *amqp.Connection
	RabbitCh    *amqp.Channel
}

type ProcessingResult struct {
	VideoID       string                 `json:"video_id"`
	Status        string                 `json:"status"`
	ProcessedAt   time.Time              `json:"processed_at"`
	FrameCount    int                    `json:"frame_count"`
	ZipSize       int64                  `json:"zip_size"`
	ZipObjectName string                 `json:"zip_object_name"`
	Metadata      map[string]interface{} `json:"metadata"`
	UserID        string                 `json:"user_id"`
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
	// Converter UserID de string para int
	userIDInt := 0
	if result.UserID != "" {
		if id, err := strconv.Atoi(result.UserID); err == nil {
			userIDInt = id
		}
	}
	
	// Extrair nome do arquivo original dos metadados
	originalFilename := "Video sem nome"
	if filename, ok := result.Metadata["original_filename"].(string); ok && filename != "" {
		originalFilename = filename
	}
	
	// Criar entrada no videosStore
	storeMutex.Lock()
	videosStore[result.VideoID] = &VideoData{
		VideoID:       result.VideoID,
		Title:         originalFilename,
		Status:        result.Status,
		UploadedAt:    result.ProcessedAt,
		FrameCount:    result.FrameCount,
		ZipSize:       result.ZipSize,
		ZipObjectName: result.ZipObjectName,
		UserID:        userIDInt,
	}
	storeMutex.Unlock()
	
	log.Printf("=== VIDEO DATA SALVA ===")
	log.Printf("VideoID: %s", result.VideoID)
	log.Printf("UserID: %d", userIDInt)
	log.Printf("FrameCount: %d", result.FrameCount)
	log.Printf("ZipSize: %d", result.ZipSize)
	log.Printf("ZipObjectName: %s", result.ZipObjectName)
	log.Printf("Status: %s", result.Status)
	
	// Em produção, seria armazenado em banco de dados
	metadata := VideoMetadata{
		VideoID:     result.VideoID,
		Resolutions: make(map[string]string), // Manter compatibilidade
		Metadata:    result.Metadata,
		Status:      result.Status,
		CreatedAt:   result.ProcessedAt,
		UpdatedAt:   time.Now(),
	}

	// Log da metadata armazenada
	log.Printf("Metadata armazenada: %+v", metadata)
	log.Printf("VideoData salva no storage para UserID %d: %s", userIDInt, result.VideoID)
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
	// Extrair user ID do JWT token
	authHeader := r.Header.Get("Authorization")
	userID, err := getUserIDFromToken(authHeader)
	if err != nil {
		http.Error(w, "Token de autenticação inválido", http.StatusUnauthorized)
		return
	}

	// Buscar vídeos do usuário no storage em memória
	storeMutex.RLock()
	var userVideos []map[string]interface{}
	for _, video := range videosStore {
		if video.UserID == userID {
			userVideos = append(userVideos, map[string]interface{}{
				"video_id":    video.VideoID,
				"title":       video.Title,
				"filename":    video.Title, // Adicionar filename para compatibilidade com frontend
				"status":      video.Status,
				"uploaded_at": video.UploadedAt.Format(time.RFC3339),
				"frame_count": video.FrameCount,
				"zip_size":    video.ZipSize,
				"user_id":     video.UserID,
			})
		}
	}
	storeMutex.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"videos": userVideos,
		"total":  len(userVideos),
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

// Handler para estatísticas
func (s *StorageService) StatsHandler(w http.ResponseWriter, r *http.Request) {
	// Extrair user ID do JWT token
	authHeader := r.Header.Get("Authorization")
	userID, err := getUserIDFromToken(authHeader)
	if err != nil {
		http.Error(w, "Token de autenticação inválido", http.StatusUnauthorized)
		return
	}
	
	// Calcular estatísticas reais do videosStore
	storeMutex.RLock()
	var totalVideos, completed, processing, failed int
	var totalSize int64
	var totalFrames int
	
	for _, video := range videosStore {
		if video.UserID == userID {
			totalVideos++
			switch video.Status {
			case "completed":
				completed++
				totalSize += video.ZipSize
				totalFrames += video.FrameCount
			case "processing":
				processing++
			case "failed":
				failed++
			}
		}
	}
	storeMutex.RUnlock()
	
	stats := map[string]interface{}{
		"total_videos": totalVideos,
		"total_size":   totalSize,
		"total_frames": totalFrames,
		"processing":   processing,
		"completed":    completed,
		"failed":       failed,
		"user_id":      userID,
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

// Extrair user ID do JWT token
func getUserIDFromToken(tokenString string) (int, error) {
	if tokenString == "" {
		return 0, fmt.Errorf("token vazio")
	}
	
	// Remover "Bearer " se presente
	if strings.HasPrefix(tokenString, "Bearer ") {
		tokenString = strings.TrimPrefix(tokenString, "Bearer ")
	}
	
	// Parse do token (sem validação da assinatura para simplicidade)
	token, _, err := new(jwt.Parser).ParseUnverified(tokenString, jwt.MapClaims{})
	if err != nil {
		return 0, fmt.Errorf("erro ao fazer parse do token: %v", err)
	}
	
	// Extrair claims
	if claims, ok := token.Claims.(jwt.MapClaims); ok {
		if userID, ok := claims["user_id"].(float64); ok {
			return int(userID), nil
		}
		return 0, fmt.Errorf("user_id não encontrado no token")
	}
	
	return 0, fmt.Errorf("claims inválidas")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func (ss *StorageService) DeleteVideoHandler(w http.ResponseWriter, r *http.Request) {
	// Extrair user ID do JWT token
	authHeader := r.Header.Get("Authorization")
	userID, err := getUserIDFromToken(authHeader)
	if err != nil {
		http.Error(w, "Token de autenticação inválido", http.StatusUnauthorized)
		return
	}

	// Extrair ID do vídeo da URL
	vars := mux.Vars(r)
	videoID := vars["id"]
	
	if videoID == "" {
		http.Error(w, "ID do vídeo é obrigatório", http.StatusBadRequest)
		return
	}

	// Verificar se o vídeo existe e pertence ao usuário
	storeMutex.Lock()
	video, exists := videosStore[videoID]
	if !exists {
		storeMutex.Unlock()
		http.Error(w, "Vídeo não encontrado", http.StatusNotFound)
		return
	}
	
	if video.UserID != userID {
		storeMutex.Unlock()
		http.Error(w, "Acesso negado", http.StatusForbidden)
		return
	}
	
	// Deletar o vídeo do storage em memória
	delete(videosStore, videoID)
	storeMutex.Unlock()
	
	log.Printf("Vídeo %s deletado com sucesso para usuário %d", videoID, userID)
	
	// Aqui faria:
	// 1. Verificar se o vídeo existe no banco
	// 2. Verificar se pertence ao usuário
	// 3. Deletar arquivos do MinIO
	// 4. Deletar registro do banco
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Vídeo deletado com sucesso",
		"video_id": videoID,
	})
}

func (ss *StorageService) DownloadVideoHandler(w http.ResponseWriter, r *http.Request) {
	videoID := mux.Vars(r)["id"]
	
	// Extrair user ID do JWT token
	authHeader := r.Header.Get("Authorization")
	userID, err := getUserIDFromToken(authHeader)
	if err != nil {
		http.Error(w, "Token de autenticação inválido", http.StatusUnauthorized)
		return
	}

	// Verificar se o vídeo pertence ao usuário
	storeMutex.RLock()
	video, exists := videosStore[videoID]
	if !exists || video.UserID != userID {
		storeMutex.RUnlock()
		http.Error(w, "Vídeo não encontrado", http.StatusNotFound)
		return
	}
	
	// Verificar se o vídeo foi processado
	if video.Status != "completed" || video.ZipObjectName == "" {
		storeMutex.RUnlock()
		http.Error(w, "Vídeo ainda não foi processado", http.StatusNotFound)
		return
	}
	
	zipObjectName := video.ZipObjectName
	storeMutex.RUnlock()

	// Baixar ZIP do MinIO
	ctx := context.Background()
	object, err := ss.MinioClient.GetObject(ctx, "video-processed", zipObjectName, minio.GetObjectOptions{})
	if err != nil {
		log.Printf("Erro ao baixar ZIP do MinIO: %v", err)
		http.Error(w, "Erro ao baixar arquivo", http.StatusInternalServerError)
		return
	}
	defer object.Close()

	// Obter informações do objeto
	objInfo, err := object.Stat()
	if err != nil {
		log.Printf("Erro ao obter informações do objeto: %v", err)
		http.Error(w, "Erro ao baixar arquivo", http.StatusInternalServerError)
		return
	}

	// Configurar headers para download
	w.Header().Set("Content-Type", "application/zip")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", zipObjectName))
	w.Header().Set("Content-Length", strconv.FormatInt(objInfo.Size, 10))

	// Copiar dados do MinIO para o response
	_, err = io.Copy(w, object)
	if err != nil {
		log.Printf("Erro ao copiar dados do ZIP: %v", err)
		return
	}

	log.Printf("ZIP baixado com sucesso: %s (%d bytes)", zipObjectName, objInfo.Size)
}

var ctx = context.Background()

func main() {
	// Inicializar dados de exemplo
	initSampleData()
	
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
	r.HandleFunc("/videos/{id}", storageService.DeleteVideoHandler).Methods("DELETE")
	r.HandleFunc("/videos", storageService.ListVideosHandler).Methods("GET")
	r.HandleFunc("/stats", storageService.StatsHandler).Methods("GET")
	r.HandleFunc("/download/{id}", storageService.DownloadVideoHandler).Methods("GET")

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
	log.Printf("Storage Service iniciado na porta %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}
