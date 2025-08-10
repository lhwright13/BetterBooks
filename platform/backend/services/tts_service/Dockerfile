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

COPY tts_service/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY tts_service .

# Set Python path to include core modules
ENV PYTHONPATH="/app/core:/app:$PYTHONPATH"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
