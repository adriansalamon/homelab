FROM golang:1.25-alpine AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copy source
COPY *.go ./

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o consul-kv-proxy .

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/consul-kv-proxy .

# Run as non-root user
RUN adduser -D -u 1000 appuser
USER appuser

EXPOSE 8080

CMD ["./consul-kv-proxy"]
