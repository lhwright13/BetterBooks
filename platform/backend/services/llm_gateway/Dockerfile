# Build stage
FROM python:3.11-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
COPY platform/backend/services/llm_gateway/requirements.txt ./
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim as production

WORKDIR /app

# Create non-root user for security first
RUN groupadd -r betterbooks && useradd -r -g betterbooks betterbooks

# Copy Python packages from builder and set ownership
COPY --from=builder /root/.local /home/betterbooks/.local
RUN chown -R betterbooks:betterbooks /home/betterbooks/.local

# Make sure scripts in .local are usable:
ENV PATH=/home/betterbooks/.local/bin:$PATH

# Copy application code
COPY platform/backend/services/llm_gateway/ ./
COPY core/ ./core/

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app"

# Set ownership and switch to non-root user
RUN chown -R betterbooks:betterbooks /app
USER betterbooks

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
