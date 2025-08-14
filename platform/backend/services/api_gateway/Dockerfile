FROM python:3.11-slim
WORKDIR /app

# Install build dependencies for psutil
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY platform/backend/services/api_gateway/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy API gateway code
COPY platform/backend/services/api_gateway /app/api_gateway

# Copy core modules for production
COPY core /app/core

# Set working directory to API gateway
WORKDIR /app/api_gateway

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
