FROM python:3.11-slim

# Install system dependencies for audio processing
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install dependencies
COPY services/transcription_service/requirements.txt .
RUN pip install -r requirements.txt

# Download Faster-Whisper model during build
RUN python -c "from faster_whisper import WhisperModel; WhisperModel('tiny', device='cpu', compute_type='int8')"

# Copy transcription service code
COPY services/transcription_service /app/transcription_service

# Core modules will be mounted as volume in development
# In production, they should be copied here

# Set working directory to transcription service
WORKDIR /app/transcription_service

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app"

EXPOSE 8000

CMD ["uvicorn", "simple_main:app", "--host", "0.0.0.0", "--port", "8000"]