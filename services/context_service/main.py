import os
from typing import List

import psycopg
from fastapi import FastAPI
from pydantic import BaseModel
from pgvector.psycopg import register_vector

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost/postgres")

conn = psycopg.connect(DATABASE_URL)

# Ensure the pgvector extension is available before registering the vector type
with conn.cursor() as cur:
    cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
    conn.commit()

# Register the vector type with psycopg
register_vector(conn)

# Create the embeddings table if it doesn't already exist
with conn.cursor() as cur:
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS embeddings (
            id TEXT PRIMARY KEY,
            embedding vector(1536)
        )
        """
    )
    conn.commit()

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}


class EmbeddingItem(BaseModel):
    id: str
    embedding: List[float]


class SearchQuery(BaseModel):
    embedding: List[float]
    top_k: int = 5


@app.post("/embeddings")
def add_embedding(item: EmbeddingItem):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO embeddings (id, embedding)
            VALUES (%s, %s)
            ON CONFLICT (id) DO UPDATE SET embedding = EXCLUDED.embedding
            """,
            (item.id, item.embedding),
        )
        conn.commit()
    return {"status": "stored"}


@app.post("/search")
def search_embeddings(query: SearchQuery):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM embeddings ORDER BY embedding <-> %s LIMIT %s",
            (query.embedding, query.top_k),
        )
        rows = cur.fetchall()
    return {"ids": [r[0] for r in rows]}

