# Stage 1: Build stage
FROM python:3.12.9-slim-bookworm AS builder
WORKDIR /app
COPY app.py .

# Stage 2: Final minimal runtime stage
FROM python:3.12.9-slim-bookworm AS runner
WORKDIR /app

# Create non-root system user and group
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /sbin/nologin -M appuser

# Copy application binary/script from builder
COPY --from=builder /app/app.py /app/app.py

# Ensure correct file permissions
RUN chown -R appuser:appgroup /app

# Enforce non-root execution
USER 10001:10001

EXPOSE 8080

ENV APP_NAME="demo-app" \
    VERSION="1.0.0" \
    PORT="8080"

ENTRYPOINT ["python", "-u", "/app/app.py"]
