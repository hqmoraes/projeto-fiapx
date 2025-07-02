package main

import (
	"archive/zip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/streadway/amqp"
	"github.com/rs/cors"
	"github.com/go-redis/redis/v8"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Notification message for email service
type NotificationMessage struct {
	UserID       int    `json:"user_id"`
	UserEmail    string `json:"user_email"`
	UserName     string `json:"user_name"`
	VideoID      string `json:"video_id"`
	VideoTitle   string `json:"video_title"`
	Status       string `json:"status"`
	ErrorMessage string `json:"error_message,omitempty"`
	ProcessedAt  string `json:"processed_at"`
	Type         string `json:"type"` // "success", "error", "warning"
}

type ProcessingService struct {
	MinioClient *minio.Client
	RabbitConn  *amqp.Connection
	RabbitCh    *amqp.Channel
	RedisClient *redis.Client
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
	FrameCount    int                    `json:"frame_count"`
	ZipSize       int64                  `json:"zip_size"`
	ZipObjectName string                 `json:"zip_object_name"`
	Metadata      map[string]interface{} `json:"metadata"`
	UserID        string                 `json:"user_id"`
	Error         string                 `json:"error,omitempty"`
}

// Estruturas para APIs de fila
type QueueStatus struct {
	QueueLength     int                  `json:"queue_length"`
	ProcessingCount int                  `json:"processing_count"`
	VideosInQueue   []QueueVideoInfo     `json:"videos_in_queue"`
}

type QueueVideoInfo struct {
	VideoID   string    `json:"video_id"`
	Filename  string    `json:"filename"`
	UserID    string    `json:"user_id"`
	QueuedAt  time.Time `json:"queued_at"`
	Position  int       `json:"position"`
}

type VideoQueuePosition struct {
	Position          int `json:"position"`
	EstimatedWaitTime int `json:"estimated_wait_time"` // em segundos
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

	// Configurar Redis
	var redisClient *redis.Client
	redisHost := getEnv("REDIS_HOST", "redis")
	redisPort := getEnv("REDIS_PORT", "6380")
	redisDB := getEnv("REDIS_DB", "0")
	
	db, err := strconv.Atoi(redisDB)
	if err != nil {
		log.Printf("Erro ao converter REDIS_DB, usando padrão 0: %v", err)
		db = 0
	}
	
	redisClient = redis.NewClient(&redis.Options{
		Addr:     redisHost + ":" + redisPort,
		Password: "", // sem senha
		DB:       db,
	})
	
	// Testar conexão Redis
	ctx := context.Background()
	_, err = redisClient.Ping(ctx).Result()
	if err != nil {
		log.Printf("Aviso: Erro ao conectar com Redis: %v", err)
		log.Printf("Continuando sem cache Redis...")
		redisClient = nil
	} else {
		log.Printf("Redis conectado com sucesso em %s:%s DB:%d", redisHost, redisPort, db)
	}

	return &ProcessingService{
		MinioClient: minioClient,
		RabbitConn:  rabbitConn,
		RabbitCh:    rabbitCh,
		RedisClient: redisClient,
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
		
		// Invalidar cache no início do processamento
		if ps.RedisClient != nil {
			err = ps.invalidateQueueCache()
			if err != nil {
				log.Printf("Erro ao invalidar cache no início: %v", err)
			}
		}
		
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
		
		// Send email notification
		ps.sendEmailNotification(processingMsg.VideoID, processingMsg.UserID, result.Status, result.Error)
		
		// Invalidar cache após processamento concluído
		if ps.RedisClient != nil {
			err = ps.invalidateQueueCache()
			if err != nil {
				log.Printf("Erro ao invalidar cache após processamento: %v", err)
			}
		}
	}
}

func (ps *ProcessingService) processVideo(msg ProcessingMessage) ProcessingResult {
	result := ProcessingResult{
		VideoID:     msg.VideoID,
		ProcessedAt: time.Now(),
		UserID:      msg.UserID,
		Metadata:    make(map[string]interface{}),
	}

	log.Printf("Iniciando processamento de frames para vídeo: %s", msg.VideoID)

	// Criar diretório temporário para o processamento
	tempDir := filepath.Join("/tmp", fmt.Sprintf("video_processing_%s", msg.VideoID))
	os.MkdirAll(tempDir, 0755)
	defer os.RemoveAll(tempDir)

	// Baixar vídeo do MinIO
	videoPath := filepath.Join(tempDir, msg.Filename)
	err := ps.downloadVideoFromMinio(msg.Bucket, msg.ObjectName, videoPath)
	if err != nil {
		log.Printf("Erro ao baixar vídeo do MinIO: %v", err)
		result.Status = "error"
		result.Error = fmt.Sprintf("Erro ao baixar vídeo: %v", err)
		return result
	}

	// Extrair frames
	framesDir := filepath.Join(tempDir, "frames")
	os.MkdirAll(framesDir, 0755)
	
	frameCount, err := ps.extractFrames(videoPath, framesDir)
	if err != nil {
		log.Printf("Erro ao extrair frames: %v", err)
		result.Status = "error"
		result.Error = fmt.Sprintf("Erro ao extrair frames: %v", err)
		return result
	}

	if frameCount == 0 {
		log.Printf("Nenhum frame foi extraído do vídeo")
		result.Status = "error"
		result.Error = "Nenhum frame foi extraído do vídeo"
		return result
	}

	log.Printf("Extraídos %d frames do vídeo %s", frameCount, msg.VideoID)

	// Criar ZIP com os frames
	zipPath := filepath.Join(tempDir, fmt.Sprintf("frames_%s.zip", msg.VideoID))
	err = ps.createZipFromFrames(framesDir, zipPath)
	if err != nil {
		log.Printf("Erro ao criar ZIP: %v", err)
		result.Status = "error"
		result.Error = fmt.Sprintf("Erro ao criar ZIP: %v", err)
		return result
	}

	// Upload do ZIP para MinIO
	zipObjectName := fmt.Sprintf("frames_%s.zip", msg.VideoID)
	zipSize, err := ps.uploadZipToMinio(zipPath, zipObjectName)
	if err != nil {
		log.Printf("Erro ao fazer upload do ZIP: %v", err)
		result.Status = "error"
		result.Error = fmt.Sprintf("Erro ao fazer upload do ZIP: %v", err)
		return result
	}

	log.Printf("ZIP criado e enviado com sucesso: %s (%d bytes)", zipObjectName, zipSize)

	// Atualizar resultado
	result.Status = "completed"
	result.FrameCount = frameCount
	result.ZipSize = zipSize
	result.ZipObjectName = zipObjectName
	result.Metadata["original_filename"] = msg.Filename
	result.Metadata["frame_count"] = frameCount
	result.Metadata["zip_size"] = zipSize

	// Enviar notificação por email
	ps.sendEmailNotification(msg.VideoID, msg.UserID, result.Status, result.Error)

	return result
}

func (ps *ProcessingService) downloadVideoFromMinio(bucket, objectName, localPath string) error {
	ctx := context.Background()
	
	// Baixar objeto do MinIO
	object, err := ps.MinioClient.GetObject(ctx, bucket, objectName, minio.GetObjectOptions{})
	if err != nil {
		return fmt.Errorf("erro ao obter objeto do MinIO: %v", err)
	}
	defer object.Close()

	// Criar arquivo local
	localFile, err := os.Create(localPath)
	if err != nil {
		return fmt.Errorf("erro ao criar arquivo local: %v", err)
	}
	defer localFile.Close()

	// Copiar conteúdo
	_, err = io.Copy(localFile, object)
	if err != nil {
		return fmt.Errorf("erro ao copiar conteúdo: %v", err)
	}

	return nil
}

func (ps *ProcessingService) extractFrames(videoPath, framesDir string) (int, error) {
	// Usar ffmpeg para extrair frames (1 frame por segundo)
	framePattern := filepath.Join(framesDir, "frame_%04d.png")
	
	cmd := exec.Command("ffmpeg",
		"-i", videoPath,
		"-vf", "fps=1", // 1 frame por segundo
		"-y",           // sobrescrever arquivos existentes
		framePattern,
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return 0, fmt.Errorf("erro no ffmpeg: %s\nOutput: %s", err.Error(), string(output))
	}

	// Contar frames extraídos
	frames, err := filepath.Glob(filepath.Join(framesDir, "*.png"))
	if err != nil {
		return 0, fmt.Errorf("erro ao listar frames: %v", err)
	}

	return len(frames), nil
}

func (ps *ProcessingService) createZipFromFrames(framesDir, zipPath string) error {
	// Listar todos os arquivos PNG
	frames, err := filepath.Glob(filepath.Join(framesDir, "*.png"))
	if err != nil {
		return fmt.Errorf("erro ao listar frames: %v", err)
	}

	// Criar arquivo ZIP
	zipFile, err := os.Create(zipPath)
	if err != nil {
		return fmt.Errorf("erro ao criar arquivo ZIP: %v", err)
	}
	defer zipFile.Close()

	zipWriter := zip.NewWriter(zipFile)
	defer zipWriter.Close()

	// Adicionar cada frame ao ZIP
	for _, framePath := range frames {
		err := ps.addFileToZip(zipWriter, framePath)
		if err != nil {
			return fmt.Errorf("erro ao adicionar frame ao ZIP: %v", err)
		}
	}

	return nil
}

func (ps *ProcessingService) addFileToZip(zipWriter *zip.Writer, filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	info, err := file.Stat()
	if err != nil {
		return err
	}

	header, err := zip.FileInfoHeader(info)
	if err != nil {
		return err
	}

	header.Name = filepath.Base(filePath)
	header.Method = zip.Deflate

	writer, err := zipWriter.CreateHeader(header)
	if err != nil {
		return err
	}

	_, err = io.Copy(writer, file)
	return err
}

func (ps *ProcessingService) uploadZipToMinio(zipPath, objectName string) (int64, error) {
	ctx := context.Background()
	
	// Obter informações do arquivo
	zipInfo, err := os.Stat(zipPath)
	if err != nil {
		return 0, fmt.Errorf("erro ao obter informações do ZIP: %v", err)
	}

	// Fazer upload do ZIP para o bucket video-processed
	_, err = ps.MinioClient.FPutObject(ctx, "video-processed", objectName, zipPath, minio.PutObjectOptions{
		ContentType: "application/zip",
	})
	if err != nil {
		return 0, fmt.Errorf("erro ao fazer upload para MinIO: %v", err)
	}

	return zipInfo.Size(), nil
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

// Handler para obter status da fila
func (ps *ProcessingService) QueueStatusHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	// Tentar obter status do cache Redis
	cachedStatus, err := ps.getCachedQueueStatus()
	if err == nil && cachedStatus != nil {
		// Retornar status do cache
		json.NewEncoder(w).Encode(cachedStatus)
		return
	}

	// Obter informações da fila RabbitMQ
	queueInfo, err := ps.RabbitCh.QueueInspect("video_processing")
	if err != nil {
		log.Printf("Erro ao inspecionar fila: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Erro ao obter status da fila"})
		return
	}

	// Contar pods/workers ativos (simulação baseada na fila)
	processingCount := 0
	if queueInfo.Messages > 0 {
		// Estimar workers ativos baseado na carga
		processingCount = min(queueInfo.Messages, 5) // Máximo 5 pods
	}

	status := QueueStatus{
		QueueLength:     queueInfo.Messages,
		ProcessingCount: processingCount,
		VideosInQueue:   []QueueVideoInfo{}, // Em produção, obteria de BD
	}

	// Cachear status no Redis
	err = ps.cacheQueueStatus(status)
	if err != nil {
		log.Printf("Erro ao cachear status da fila: %v", err)
	}

	json.NewEncoder(w).Encode(status)
}

// Handler para obter posição de um vídeo na fila
func (ps *ProcessingService) VideoQueuePositionHandler(w http.ResponseWriter, r *http.Request) {
	videoID := mux.Vars(r)["id"]
	w.Header().Set("Content-Type", "application/json")
	
	// Tentar obter posição do cache Redis
	cachedPosition, err := ps.getCachedVideoPosition(videoID)
	if err == nil && cachedPosition != nil {
		// Retornar posição do cache
		json.NewEncoder(w).Encode(cachedPosition)
		return
	}

	// Log para debug
	log.Printf("Consultando posição na fila para vídeo: %s", videoID)
	
	// Em produção, consultaria banco de dados para posição real
	// Por agora, simulamos baseado na fila
	queueInfo, err := ps.RabbitCh.QueueInspect("video_processing")
	if err != nil {
		log.Printf("Erro ao inspecionar fila: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Erro ao obter posição na fila"})
		return
	}

	// Simular posição (em produção seria obtida do BD)
	position := 1
	if queueInfo.Messages > 1 {
		position = queueInfo.Messages / 2 // Estimativa
	}

	// Estimar tempo (assumindo 90 segundos por vídeo)
	estimatedWaitTime := position * 90

	result := VideoQueuePosition{
		Position:          position,
		EstimatedWaitTime: estimatedWaitTime,
	}

	// Cachear posição no Redis
	err = ps.cacheVideoPosition(videoID, result)
	if err != nil {
		log.Printf("Erro ao cachear posição do vídeo %s: %v", videoID, err)
	}

	json.NewEncoder(w).Encode(result)
}

// Redis Cache Functions
const (
	CACHE_KEY_QUEUE_STATUS = "queue:status"
	CACHE_KEY_VIDEO_POSITION = "queue:position:"
	CACHE_TTL_QUEUE_STATUS = 10 * time.Second  // Cache por 10 segundos
	CACHE_TTL_VIDEO_POSITION = 30 * time.Second // Cache por 30 segundos
)

// Cachear status da fila no Redis
func (ps *ProcessingService) cacheQueueStatus(status QueueStatus) error {
	if ps.RedisClient == nil {
		return nil // Sem Redis configurado
	}
	
	ctx := context.Background()
	data, err := json.Marshal(status)
	if err != nil {
		return err
	}
	
	return ps.RedisClient.Set(ctx, CACHE_KEY_QUEUE_STATUS, data, CACHE_TTL_QUEUE_STATUS).Err()
}

// Obter status da fila do cache Redis
func (ps *ProcessingService) getCachedQueueStatus() (*QueueStatus, error) {
	if ps.RedisClient == nil {
		return nil, nil // Sem Redis configurado
	}
	
	ctx := context.Background()
	data, err := ps.RedisClient.Get(ctx, CACHE_KEY_QUEUE_STATUS).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil // Cache miss
		}
		return nil, err
	}
	
	var status QueueStatus
	err = json.Unmarshal([]byte(data), &status)
	if err != nil {
		return nil, err
	}
	
	return &status, nil
}

// Cachear posição do vídeo no Redis
func (ps *ProcessingService) cacheVideoPosition(videoID string, position VideoQueuePosition) error {
	ctx := context.Background()
	data, err := json.Marshal(position)
	if err != nil {
		return err
	}
	
	key := CACHE_KEY_VIDEO_POSITION + videoID
	return ps.RedisClient.Set(ctx, key, data, CACHE_TTL_VIDEO_POSITION).Err()
}

// Obter posição do vídeo do cache Redis
func (ps *ProcessingService) getCachedVideoPosition(videoID string) (*VideoQueuePosition, error) {
	ctx := context.Background()
	key := CACHE_KEY_VIDEO_POSITION + videoID
	data, err := ps.RedisClient.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil // Cache miss
		}
		return nil, err
	}
	
	var position VideoQueuePosition
	err = json.Unmarshal([]byte(data), &position)
	if err != nil {
		return nil, err
	}
	
	return &position, nil
}

// Invalidar cache quando houver mudanças na fila
func (ps *ProcessingService) invalidateQueueCache() error {
	if ps.RedisClient == nil {
		return nil // Sem Redis configurado
	}
	
	ctx := context.Background()
	// Remover cache de status
	ps.RedisClient.Del(ctx, CACHE_KEY_QUEUE_STATUS)
	
	// Remover todos os caches de posição (usando pattern)
	keys, err := ps.RedisClient.Keys(ctx, CACHE_KEY_VIDEO_POSITION+"*").Result()
	if err != nil {
		return err
	}
	
	if len(keys) > 0 {
		ps.RedisClient.Del(ctx, keys...)
	}
	
	return nil
}

// Função auxiliar para min
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
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
	if processingService.RedisClient != nil {
		defer processingService.RedisClient.Close()
	}

	// Iniciar worker em goroutine
	go processingService.StartProcessingWorker()

	// Configurar rotas HTTP
	r := mux.NewRouter()
	r.HandleFunc("/health", processingService.HealthHandler).Methods("GET")
	r.HandleFunc("/status/{id}", processingService.StatusHandler).Methods("GET")
	r.HandleFunc("/queue/status", processingService.QueueStatusHandler).Methods("GET")
	r.HandleFunc("/queue/position/{id}", processingService.VideoQueuePositionHandler).Methods("GET")
	// Expor métricas Prometheus
	r.Handle("/metrics", promhttp.Handler()).Methods("GET")

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
	log.Printf("Processing Service iniciado na porta %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}

// Send email notification for video processing status
func (ps *ProcessingService) sendEmailNotification(videoID, userID, status, errorMsg string) {
	// Get user information (mock for now - should integrate with auth-service)
	userEmail := getUserEmail(userID)
	userName := getUserName(userID)
	
	if userEmail == "" {
		log.Printf("No email found for user %s, skipping notification", userID)
		return
	}

	notification := NotificationMessage{
		UserID:       parseInt(userID),
		UserEmail:    userEmail,
		UserName:     userName,
		VideoID:      videoID,
		VideoTitle:   fmt.Sprintf("Video %s", videoID), // Should get real title
		Status:       status,
		ErrorMessage: errorMsg,
		ProcessedAt:  time.Now().Format("2006-01-02 15:04:05"),
		Type:         getNotificationType(status),
	}

	notificationBytes, err := json.Marshal(notification)
	if err != nil {
		log.Printf("Error marshaling notification: %v", err)
		return
	}

	// Send to notifications queue
	err = ps.RabbitCh.Publish(
		"",             // exchange
		"notifications", // routing key
		false,          // mandatory
		false,          // immediate
		amqp.Publishing{
			ContentType: "application/json",
			Body:        notificationBytes,
		})
	if err != nil {
		log.Printf("Error publishing notification: %v", err)
		return
	}

	log.Printf("Email notification sent for video %s (status: %s) to %s", videoID, status, userEmail)
}

// Helper functions for user data (should integrate with auth-service)
func getUserEmail(userID string) string {
	// Mock implementation - in production, call auth-service API
	// Example: GET /auth/users/{userID}
	return getEnv("DEFAULT_USER_EMAIL", "user@fiapx.wecando.click")
}

func getUserName(userID string) string {
	// Mock implementation - in production, call auth-service API
	return getEnv("DEFAULT_USER_NAME", "FIAP-X User")
}

func getNotificationType(status string) string {
	switch status {
	case "completed":
		return "success"
	case "failed", "error":
		return "error"
	case "processing":
		return "info"
	default:
		return "info"
	}
}

func parseInt(s string) int {
	i, _ := strconv.Atoi(s)
	return i
}
