package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/smtp"
	"os"
	"time"

	"github.com/streadway/amqp"
)

// Email notification service for FIAP-X
// Sends notifications to users when video processing fails or completes

type EmailConfig struct {
	SMTPHost     string
	SMTPPort     string
	SMTPUsername string
	SMTPPassword string
	FromEmail    string
	FromName     string
}

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

type EmailService struct {
	Config EmailConfig
	Client smtp.Auth
}

func NewEmailService() *EmailService {
	config := EmailConfig{
		SMTPHost:     getEnv("SMTP_HOST", "email-smtp.us-east-1.amazonaws.com"), // Amazon SES SMTP endpoint
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUsername: getEnv("SMTP_USERNAME", ""), // SES SMTP username
		SMTPPassword: getEnv("SMTP_PASSWORD", ""), // SES SMTP password  
		FromEmail:    getEnv("FROM_EMAIL", "noreply@fiapx.wecando.click"),
		FromName:     getEnv("FROM_NAME", "FIAP-X Video Processing Platform"),
	}

	if config.SMTPUsername == "" || config.SMTPPassword == "" {
		log.Fatal("SMTP credentials not configured. Set SMTP_USERNAME and SMTP_PASSWORD environment variables.")
	}

	auth := smtp.PlainAuth("", config.SMTPUsername, config.SMTPPassword, config.SMTPHost)

	return &EmailService{
		Config: config,
		Client: auth,
	}
}

func (es *EmailService) SendNotification(msg NotificationMessage) error {
	var subject, templateName string

	switch msg.Status {
	case "completed":
		subject = "✅ Vídeo processado com sucesso - FIAP-X"
		templateName = "success"
	case "failed", "error":
		subject = "❌ Erro no processamento do vídeo - FIAP-X"
		templateName = "error"
	case "processing":
		subject = "⏳ Processamento iniciado - FIAP-X"
		templateName = "processing"
	default:
		subject = "📹 Atualização do seu vídeo - FIAP-X"
		templateName = "generic"
	}

	// Generate email body from template
	body, err := es.generateEmailBody(templateName, msg)
	if err != nil {
		return fmt.Errorf("failed to generate email body: %v", err)
	}

	// Compose email
	email := fmt.Sprintf("From: %s <%s>\r\n", es.Config.FromName, es.Config.FromEmail)
	email += fmt.Sprintf("To: %s\r\n", msg.UserEmail)
	email += fmt.Sprintf("Subject: %s\r\n", subject)
	email += "MIME-version: 1.0\r\n"
	email += "Content-Type: text/html; charset=\"UTF-8\"\r\n\r\n"
	email += body

	// Send email
	addr := fmt.Sprintf("%s:%s", es.Config.SMTPHost, es.Config.SMTPPort)
	return smtp.SendMail(addr, es.Client, es.Config.FromEmail, []string{msg.UserEmail}, []byte(email))
}

func (es *EmailService) generateEmailBody(templateName string, msg NotificationMessage) (string, error) {
	templates := map[string]string{
		"success": `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Processamento Concluído</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #28a745; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f8f9fa; }
        .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        .btn { display: inline-block; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎉 Vídeo Processado com Sucesso!</h1>
        </div>
        <div class="content">
            <p>Olá <strong>{{.UserName}}</strong>,</p>
            <p>Seu vídeo foi processado com sucesso!</p>
            
            <h3>Detalhes:</h3>
            <ul>
                <li><strong>Vídeo:</strong> {{.VideoTitle}}</li>
                <li><strong>ID:</strong> {{.VideoID}}</li>
                <li><strong>Status:</strong> ✅ Concluído</li>
                <li><strong>Processado em:</strong> {{.ProcessedAt}}</li>
            </ul>
            
            <p>Você já pode fazer o download dos frames extraídos através da plataforma.</p>
            
            <p style="text-align: center;">
                <a href="https://fiapx.wecando.click" class="btn">Acessar Plataforma</a>
            </p>
        </div>
        <div class="footer">
            <p>FIAP-X Video Processing Platform<br>
            Este é um email automático, não responda.</p>
        </div>
    </div>
</body>
</html>`,

		"error": `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Erro no Processamento</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f8f9fa; }
        .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        .btn { display: inline-block; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; }
        .error-box { background: #f8d7da; border: 1px solid #f5c6cb; padding: 15px; border-radius: 5px; margin: 15px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚠️ Erro no Processamento</h1>
        </div>
        <div class="content">
            <p>Olá <strong>{{.UserName}}</strong>,</p>
            <p>Infelizmente ocorreu um erro durante o processamento do seu vídeo.</p>
            
            <h3>Detalhes:</h3>
            <ul>
                <li><strong>Vídeo:</strong> {{.VideoTitle}}</li>
                <li><strong>ID:</strong> {{.VideoID}}</li>
                <li><strong>Status:</strong> ❌ Erro</li>
                <li><strong>Data:</strong> {{.ProcessedAt}}</li>
            </ul>
            
            {{if .ErrorMessage}}
            <div class="error-box">
                <h4>Detalhes do Erro:</h4>
                <p>{{.ErrorMessage}}</p>
            </div>
            {{end}}
            
            <p><strong>O que fazer agora?</strong></p>
            <ul>
                <li>Verifique se o arquivo de vídeo não está corrompido</li>
                <li>Tente fazer o upload novamente</li>
                <li>Entre em contato conosco se o problema persistir</li>
            </ul>
            
            <p style="text-align: center;">
                <a href="https://fiapx.wecando.click" class="btn">Tentar Novamente</a>
            </p>
        </div>
        <div class="footer">
            <p>FIAP-X Video Processing Platform<br>
            Este é um email automático, não responda.</p>
        </div>
    </div>
</body>
</html>`,

		"processing": `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Processamento Iniciado</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #17a2b8; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f8f9fa; }
        .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        .btn { display: inline-block; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 Processamento Iniciado</h1>
        </div>
        <div class="content">
            <p>Olá <strong>{{.UserName}}</strong>,</p>
            <p>Seu vídeo entrou na fila de processamento!</p>
            
            <h3>Detalhes:</h3>
            <ul>
                <li><strong>Vídeo:</strong> {{.VideoTitle}}</li>
                <li><strong>ID:</strong> {{.VideoID}}</li>
                <li><strong>Status:</strong> ⏳ Processando</li>
                <li><strong>Iniciado em:</strong> {{.ProcessedAt}}</li>
            </ul>
            
            <p>Você receberá um novo email quando o processamento for concluído.</p>
            <p>Você também pode acompanhar o progresso na plataforma.</p>
            
            <p style="text-align: center;">
                <a href="https://fiapx.wecando.click" class="btn">Acompanhar Progresso</a>
            </p>
        </div>
        <div class="footer">
            <p>FIAP-X Video Processing Platform<br>
            Este é um email automático, não responda.</p>
        </div>
    </div>
</body>
</html>`}

	tmplContent, exists := templates[templateName]
	if !exists {
		return "", fmt.Errorf("template %s not found", templateName)
	}

	tmpl, err := template.New("email").Parse(tmplContent)
	if err != nil {
		return "", err
	}

	var buf bytes.Buffer
	err = tmpl.Execute(&buf, msg)
	if err != nil {
		return "", err
	}

	return buf.String(), nil
}

// RabbitMQ consumer for notification messages
func (es *EmailService) StartConsumer() error {
	rabbitmqURL := getEnv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
	
	conn, err := amqp.Dial(rabbitmqURL)
	if err != nil {
		return fmt.Errorf("failed to connect to RabbitMQ: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		return fmt.Errorf("failed to open channel: %v", err)
	}
	defer ch.Close()

	// Declare notification queue
	queue, err := ch.QueueDeclare(
		"notifications", // name
		true,           // durable
		false,          // delete when unused
		false,          // exclusive
		false,          // no-wait
		nil,            // arguments
	)
	if err != nil {
		return fmt.Errorf("failed to declare queue: %v", err)
	}

	// Set QoS
	err = ch.Qos(1, 0, false)
	if err != nil {
		return fmt.Errorf("failed to set QoS: %v", err)
	}

	msgs, err := ch.Consume(
		queue.Name, // queue
		"",         // consumer
		false,      // auto-ack
		false,      // exclusive
		false,      // no-local
		false,      // no-wait
		nil,        // args
	)
	if err != nil {
		return fmt.Errorf("failed to register consumer: %v", err)
	}

	log.Printf("📧 Email notification service started. Waiting for messages...")

	forever := make(chan bool)

	go func() {
		for d := range msgs {
			var msg NotificationMessage
			err := json.Unmarshal(d.Body, &msg)
			if err != nil {
				log.Printf("Error parsing message: %v", err)
				d.Nack(false, false)
				continue
			}

			log.Printf("Sending notification to %s for video %s (status: %s)", msg.UserEmail, msg.VideoID, msg.Status)

			err = es.SendNotification(msg)
			if err != nil {
				log.Printf("Error sending email: %v", err)
				d.Nack(false, true) // Requeue for retry
				continue
			}

			log.Printf("✅ Email sent successfully to %s", msg.UserEmail)
			d.Ack(false)
		}
	}()

	<-forever
	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func main() {
	log.Println("🚀 Starting FIAP-X Email Notification Service")

	emailService := NewEmailService()
	
	// Test email configuration
	testMsg := NotificationMessage{
		UserID:      1,
		UserEmail:   getEnv("TEST_EMAIL", "test@example.com"),
		UserName:    "Usuário Teste",
		VideoID:     "test_123",
		VideoTitle:  "Vídeo de Teste",
		Status:      "completed",
		ProcessedAt: time.Now().Format("2006-01-02 15:04:05"),
		Type:        "success",
	}

	if os.Getenv("SEND_TEST_EMAIL") == "true" {
		log.Println("Sending test email...")
		err := emailService.SendNotification(testMsg)
		if err != nil {
			log.Fatalf("Failed to send test email: %v", err)
		}
		log.Println("✅ Test email sent successfully!")
		return
	}

	// Start consuming messages
	err := emailService.StartConsumer()
	if err != nil {
		log.Fatalf("Failed to start consumer: %v", err)
	}
}
