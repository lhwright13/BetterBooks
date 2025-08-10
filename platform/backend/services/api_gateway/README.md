# API Gateway

FastAPI application serving as the public REST API and coordinating requests
between the internal services.

Run locally with:
```
uvicorn main:app --reload
```

### Example

```bash
# Complete a prompt using the LLM
curl -X POST localhost:8000/complete \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Tell me a joke"}'

# Convert text to speech
curl -X POST localhost:8000/tts \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello"}'
```
