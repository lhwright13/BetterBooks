# ADR-003: PostgreSQL with pgvector for Embeddings

## Status
Accepted

## Date
2025-01-03

## Context
BetterBooks needs to store and search through vector embeddings for:
- Book content embeddings for semantic search
- Chapter summaries and metadata
- User interaction history
- AI-generated content

We need a solution that can efficiently handle:
- High-dimensional vector similarity search (1536+ dimensions)
- Hybrid search (combining vector similarity with metadata filtering)
- ACID compliance for transactional consistency
- Scaling to millions of embeddings

## Decision Drivers
- **Vector Search Performance**: Need sub-second similarity search on large datasets
- **Hybrid Queries**: Combine vector search with traditional SQL filtering
- **Operational Simplicity**: Minimize the number of databases to manage
- **Data Consistency**: ACID compliance for critical user data
- **Cost Efficiency**: Avoid expensive specialized vector database services
- **Ecosystem**: Strong Python support and mature tooling

## Considered Options
1. **PostgreSQL with pgvector** - Open-source Postgres extension for vector operations
2. **Pinecone** - Managed vector database service
3. **Weaviate** - Open-source vector search engine
4. **Qdrant** - Open-source vector similarity search engine
5. **PostgreSQL + Elasticsearch** - Hybrid approach with separate vector store
6. **ChromaDB** - Embedded vector database

## Decision Outcome
Chosen option: **PostgreSQL with pgvector**, because it provides excellent vector search capabilities while keeping our data in a single, familiar database system.

### Positive Consequences
- Single database for all data (vectors, metadata, user data)
- ACID compliance and transactional consistency
- Familiar PostgreSQL tooling and operations
- Cost-effective (no additional database service)
- Excellent hybrid search capabilities
- Multiple index types (HNSW, IVFFlat) for different use cases
- Native SQL integration for complex queries
- Proven scalability with proper indexing

### Negative Consequences
- Not as specialized as dedicated vector databases
- Requires careful index tuning for optimal performance
- Limited to PostgreSQL scaling patterns
- Self-managed (vs managed services like Pinecone)

## Pros and Cons of the Options

### Option 1: PostgreSQL with pgvector
- **Pros:**
  - Single database for all data types
  - ACID compliance
  - Mature PostgreSQL ecosystem
  - Hybrid queries with SQL
  - Open-source and free
  - HNSW and IVFFlat indexes
  - PgBouncer for connection pooling
- **Cons:**
  - Not specialized for vectors
  - Requires index tuning
  - Self-managed operations

### Option 2: Pinecone
- **Pros:**
  - Purpose-built for vectors
  - Fully managed service
  - Excellent performance
  - Auto-scaling
- **Cons:**
  - Expensive at scale ($70+ per month)
  - Vendor lock-in
  - Separate from main database
  - Network latency for hybrid queries

### Option 3: Weaviate
- **Pros:**
  - Purpose-built vector database
  - Good performance
  - GraphQL API
  - Open-source option
- **Cons:**
  - Additional database to manage
  - Learning curve
  - Less mature than PostgreSQL
  - Complex hybrid queries

### Option 4: Qdrant
- **Pros:**
  - High performance
  - Rich filtering capabilities
  - Open-source
  - Good Python SDK
- **Cons:**
  - Another database to operate
  - Smaller community
  - Less tooling support
  - Data synchronization complexity

### Option 5: PostgreSQL + Elasticsearch
- **Pros:**
  - Best of both worlds
  - Elasticsearch for text search
  - PostgreSQL for structured data
- **Cons:**
  - Two databases to manage
  - Synchronization complexity
  - Higher operational overhead
  - Increased costs

### Option 6: ChromaDB
- **Pros:**
  - Simple embedded database
  - Easy to get started
  - Good for prototyping
- **Cons:**
  - Not suitable for production scale
  - Limited query capabilities
  - No ACID compliance
  - Embedded only (not distributed)

## Implementation Details

### Database Configuration
```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create embeddings table with vector column
CREATE TABLE embeddings (
    id SERIAL PRIMARY KEY,
    book_id INTEGER,
    chapter_id INTEGER,
    content TEXT,
    embedding vector(1536),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create HNSW index for fast similarity search
CREATE INDEX idx_embeddings_vector_hnsw 
ON embeddings USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

### Index Strategy
- **HNSW Index**: For production similarity search (better recall, slightly slower build)
- **IVFFlat Index**: For smaller datasets or when index build time matters
- **BTREE Indexes**: On book_id, chapter_id for filtering
- **GIN Index**: On JSONB metadata for flexible queries

### Performance Optimizations
- Connection pooling with PgBouncer
- Read replicas for search queries
- Proper index maintenance and VACUUM schedules
- Embedding dimension optimization (1536 for OpenAI, 768 for smaller models)

## Links
- [ADR-004: Redis for Caching](ADR-004-redis-caching.md)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Database Schema](/core/database/migrations/V001_20250101_initial_schema.sql)

## Notes
pgvector has proven to handle millions of vectors efficiently with proper indexing. The ability to combine vector search with traditional SQL queries in a single database significantly simplifies our architecture and reduces operational complexity.