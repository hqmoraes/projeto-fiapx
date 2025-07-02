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
	"time"

	"github.com/gorilla/mux"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/streadway/amqp"
	"github.com/rs/cors"
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
	FrameCount    int                    `json:"frame_count"`
	ZipSize       int64                  `json:"zip_size"`
	ZipObjectName string                 `json:"zip_object_name"`
	Metadata      map[string]interface{} `json:"metadata"`
	UserID        string                 `json:"user_id"`
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
