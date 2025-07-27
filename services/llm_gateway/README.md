# LLM Gateway

Provides a REST endpoint that proxies requests to the configured Gemini
language model. By default it uses the `gemini-2.0-flash` model.

### Running

```
export GEMINI_API_KEY=your-key
uvicorn main:app --reload
```

Configuration options such as the model name and generation settings can be
adjusted in `config.json`.

### Example

```bash
curl -X POST localhost:8000/complete \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Once upon a time"}'
```
