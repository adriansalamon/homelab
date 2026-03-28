# Build stage
FROM golang:1.26-alpine AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY main.go ./

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o homepage .

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy binary
COPY --from=builder /build/homepage .

RUN adduser -D -u 1000 appuser
USER appuser

# Copy templates
COPY templates ./templates

CMD ["./homepage"]
