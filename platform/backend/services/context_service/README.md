# Context Service

FastAPI service that stores and searches embeddings in Postgres using
[`pgvector`](https://github.com/pgvector/pgvector).

### Running

```
uvicorn main:app --reload
```

Set `DATABASE_URL` to point at your Postgres instance.

### Example

```bash
# Store an embedding
curl -X POST localhost:8000/embeddings \
  -H "Content-Type: application/json" \
  -d '{"id":"book1","embedding":[0.1,0.2,0.3]}'

# Search for similar embeddings
curl -X POST localhost:8000/search \
  -H "Content-Type: application/json" \
  -d '{"embedding":[0.1,0.2,0.3],"top_k":5}'
```
