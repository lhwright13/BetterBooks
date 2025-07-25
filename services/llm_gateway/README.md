# LLM Gateway

Provides a REST endpoint that proxies requests to the configured language model
(OpenAI by default).

### Running

```
export OPENAI_API_KEY=your-key
uvicorn main:app --reload
```

### Example

```bash
curl -X POST localhost:8000/complete \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Once upon a time"}'
```
