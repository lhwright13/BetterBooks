FROM python:3.11-slim
WORKDIR /app

# Install build dependencies for psutil
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY platform/backend/services/context_service/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY platform/backend/services/context_service .
COPY core /app/core

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
