FROM golang:1.25-alpine AS builder

WORKDIR /build
COPY go.* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o nomad-gitops ./cmd/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /build/nomad-gitops .
RUN adduser -D -u 1000 appuser
USER appuser

ENTRYPOINT ["./nomad-gitops"]
