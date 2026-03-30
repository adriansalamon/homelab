# Use a slim Python base image
FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1

# Install system dependencies and Nomad CLI
RUN apt-get update && \
    apt-get install -y curl gnupg ca-certificates && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y nomad=1.11.1-1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /webhook

# Copy application script
COPY webhook_server.py .

# Install Python dependencies
RUN pip install --no-cache-dir requests

# Expose the webhook port
EXPOSE 8080

# Run the application
CMD ["python", "webhook_server.py"]
