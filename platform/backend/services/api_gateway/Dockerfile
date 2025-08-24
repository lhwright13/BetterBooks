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
COPY platform/backend/services/api_gateway/requirements.txt ./
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim as production

WORKDIR /app

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Make sure scripts in .local are usable:
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY platform/backend/services/api_gateway/ ./
COPY core/ ./core/
# Create minimal test book files structure for testing
RUN mkdir -p ./book_files/The\ Great\ Gatsby && \
    echo "placeholder audio content" > "./book_files/The Great Gatsby/Chapter 1.mp3" && \
    echo "placeholder audio content" > "./book_files/The Great Gatsby/Chapter 2.mp3" && \
    echo "placeholder audio content" > "./book_files/single_book.mp3"

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app"

# Note: Running as root for now to avoid permission issues with dependencies
# TODO: Implement proper non-root user setup

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
