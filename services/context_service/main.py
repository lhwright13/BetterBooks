"""REST service that manages embeddings in a Postgres database."""

import os
from typing import List

import psycopg
from fastapi import FastAPI
from pydantic import BaseModel
from pgvector.psycopg import register_vector

# Connection string for the Postgres instance. The default is compatible with
# the docker-compose configuration.
DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://betterbooks:betterbooks@postgres:5432/betterbooks"
)

# Establish a database connection when the service starts
conn = psycopg.connect(DATABASE_URL)

# Ensure the pgvector extension is available before registering the vector type
with conn.cursor() as cur:
    cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
    conn.commit()

# Register the custom pgvector type with psycopg
register_vector(conn)

# Create the embeddings table if it doesn't already exist. This table stores
# 1536 dimensional embeddings keyed by an ID.
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

# FastAPI application instance
app = FastAPI()

@app.get("/health")
def health() -> dict:
    """Basic liveness endpoint."""

    return {"status": "ok"}


class EmbeddingItem(BaseModel):
    """Model for inserting or updating an embedding."""

    id: str
    embedding: List[float]


class SearchQuery(BaseModel):
    """Query for similarity search."""

    embedding: List[float]
    top_k: int = 5


@app.post("/embeddings")
def add_embedding(item: EmbeddingItem) -> dict:
    """Insert or update an embedding vector."""
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
def search_embeddings(query: SearchQuery) -> dict:
    """Find IDs of embeddings most similar to the query vector."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM embeddings ORDER BY embedding <-> %s::vector LIMIT %s",
            (query.embedding, query.top_k),
        )
        rows = cur.fetchall()
    return {"ids": [r[0] for r in rows]}

