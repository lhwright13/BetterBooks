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

# Create non-root user for security
RUN adduser --disabled-password --gecos '' --uid 1000 appuser

# Copy Python packages from builder and make them accessible to appuser
COPY --from=builder /root/.local /home/appuser/.local
RUN chown -R appuser:appuser /home/appuser/.local

# Copy application code and set ownership
COPY --chown=appuser:appuser platform/backend/services/api_gateway/ ./
COPY --chown=appuser:appuser core/ ./core/

# Copy book files (covers only due to .dockerignore)
COPY --chown=appuser:appuser book_files/ ./book_files/

# Create placeholder audio files for testing
RUN echo "placeholder audio content" > "./book_files/The Great Gatsby/Chapter 1.mp3" && \
    echo "placeholder audio content" > "./book_files/The Great Gatsby/Chapter 2.mp3" && \
    echo "placeholder audio content" > "./book_files/single_book.mp3"

# Make sure scripts in .local are usable:
ENV PATH=/home/appuser/.local/bin:$PATH

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app"

# Switch to non-root user with proper PATH
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Use Python module execution as fallback if uvicorn isn't in PATH
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
