FROM python:3.11-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        libsndfile1 \
        espeak-ng \
        g++ \
        curl \
    && curl https://sh.rustup.rs -sSf | sh -s -- -y \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.cargo/bin:$PATH"

COPY platform/backend/services/tts_service/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY platform/backend/services/tts_service .
COPY core /app/core

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]
