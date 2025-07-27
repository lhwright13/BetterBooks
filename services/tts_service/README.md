# TTS Service (text to speech)

Generates speech audio using [Coqui TTS](https://github.com/coqui-ai/TTS).

### Running

```
uvicorn main:app --reload
```

### Example

```bash
curl -X POST localhost:8000/synthesize \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello world"}'
```
