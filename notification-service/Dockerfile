# Notification Service - FIAP-X
# Handles email notifications for video processing events

# Build stage
FROM golang:1.21-alpine AS builder

# Security: Install ca-certificates and git
RUN apk add --no-cache ca-certificates git

# Create non-root user for build
RUN adduser -D -g '' appuser

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the application with security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -a -installsuffix cgo \
    -ldflags='-w -s -extldflags "-static"' \
    -o notification-service ./cmd/notification-service

# Runtime stage - Use distroless for security
FROM gcr.io/distroless/static:nonroot

# Copy ca-certificates from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the binary from builder stage
COPY --from=builder /app/notification-service /notification-service

# Use non-root user
USER nonroot:nonroot

# Health check using basic process check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/notification-service", "--health-check"] || exit 1

# Expose port for metrics/health (if implemented)
EXPOSE 8080

# Labels for metadata
LABEL maintainer="FIAP-X Team"
LABEL version="1.0"
LABEL description="Notification Service for video processing events"

# Command to run the executable
ENTRYPOINT ["/notification-service"]
