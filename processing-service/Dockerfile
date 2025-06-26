FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copiar arquivos de dependências
COPY go.mod ./
RUN go mod download

# Copiar código fonte
COPY . .

# Compilar a aplicação
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o processing-service ./cmd/processing-service

# Imagem final
FROM alpine:3.18

# Instalar FFmpeg e dependências
RUN apk --no-cache add ca-certificates ffmpeg

WORKDIR /root/

# Copiar o binário compilado
COPY --from=builder /app/processing-service .

# Criar diretório para processamento temporário
RUN mkdir -p /tmp/processing

# Expor porta (para métricas/health check)
EXPOSE 8080

# Comando para executar a aplicação
CMD ["./processing-service"]
