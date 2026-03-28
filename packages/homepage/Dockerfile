# CSS build stage
FROM node:24-alpine AS css-builder

WORKDIR /build

# Copy CSS files
COPY styles.css package.json ./
COPY templates ./templates

# Install Tailwind and build CSS
RUN npm install && \
    npx @tailwindcss/cli -i ./styles.css -o ./static/styles.css --minify

# Go build stage
FROM golang:1.26-alpine AS go-builder

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
COPY --from=go-builder /build/homepage .

# Copy templates
COPY templates ./templates

# Copy built CSS
COPY --from=css-builder /build/static ./static

RUN adduser -D -u 1000 appuser
USER appuser

CMD ["./homepage"]
