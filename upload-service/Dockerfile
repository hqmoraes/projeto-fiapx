FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copiar arquivos de dependências
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fonte
COPY . .

# Compilar a aplicação
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o upload-service ./cmd/upload-service

# Imagem final
FROM alpine:3.18

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copiar o binário compilado
COPY --from=builder /app/upload-service .

# Criar diretório para uploads temporários
RUN mkdir -p /tmp/uploads

# Expor porta
EXPOSE 8080

# Comando para executar a aplicação
CMD ["./upload-service"]
