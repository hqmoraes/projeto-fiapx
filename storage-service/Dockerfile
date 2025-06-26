FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copiar arquivos de dependências
COPY go.mod ./
RUN go mod download

# Copiar código fonte
COPY . .

# Compilar a aplicação
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o storage-service ./cmd/storage-service

# Imagem final
FROM alpine:3.18

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copiar o binário compilado
COPY --from=builder /app/storage-service .

# Expor porta
EXPOSE 8080

# Comando para executar a aplicação
CMD ["./storage-service"]
