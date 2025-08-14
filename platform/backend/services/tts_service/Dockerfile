# Build stage
FROM python:3.11-slim as builder

WORKDIR /app

# Install build dependencies including Rust for TTS compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        python3-dev \
        curl \
        pkg-config \
        libssl-dev \
    && curl https://sh.rustup.rs -sSf | sh -s -- -y \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.cargo/bin:$PATH"

# Copy and install requirements
COPY services/tts_service/requirements.txt ./
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim as production

WORKDIR /app

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        libsndfile1 \
        espeak-ng \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Make sure scripts in .local are usable:
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY services/tts_service/ ./
COPY core/ ./core/

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app"

# Create non-root user for security
RUN groupadd -r betterbooks && useradd -r -g betterbooks betterbooks \
    && chown -R betterbooks:betterbooks /app
USER betterbooks

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
