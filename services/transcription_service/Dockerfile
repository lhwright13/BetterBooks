FROM python:3.11-slim

# Install system dependencies for audio processing
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY transcription_service/requirements.txt .
RUN pip install -r requirements.txt

# Download Faster-Whisper model during build
RUN python -c "from faster_whisper import WhisperModel; WhisperModel('tiny', device='cpu', compute_type='int8')"

# Copy shared modules
COPY shared /app/shared

# Copy transcription service code  
COPY transcription_service /app/transcription_service

# Set working directory to transcription service
WORKDIR /app/transcription_service

EXPOSE 8003

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]