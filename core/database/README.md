# Core Database Module

The `core/database` module provides comprehensive database management capabilities for BetterBooks, including connection pooling, migrations, indexing, and data models. This module serves as the foundation for all database operations across the application.

## 📁 Module Structure

```mermaid
graph TD
    A[core/database/] --> B[__init__.py]
    A --> C[database_manager.py]
    A --> D[database_indexes.py]
    A --> E[database_migrations.py]
    A --> F[models/]
    A --> G[migrations/]
    F --> H[user.py]
    G --> I[V001_initial_schema.sql]
    G --> J[V002_book_tracking.sql]
    G --> K[V003_performance_indexes.sql]
    G --> L[V004_chapter_detection.sql]
    G --> M[V005_user_identity_system.sql]
```

## 🎯 Purpose & Functionality

### Core Components

| File | Purpose | Key Features |
|------|---------|--------------|
| `__init__.py` | Module entry point | Exports main classes and functions |
| `database_manager.py` | Connection & query management | Async connection pooling, health monitoring, retry logic |
| `database_indexes.py` | Index optimization | Vector similarity search, performance tuning |
| `database_migrations.py` | Schema versioning | Safe migrations, rollback support, checksum validation |
| `models/user.py` | User data models | Identity management, subscriptions, entitlements |

### Migration Files

| Migration | Purpose | Schema Changes |
|-----------|---------|----------------|
| V001 | Initial schema | Core tables: embeddings, users, sessions, audit_logs |
| V002 | Book tracking | Books, chapters, reading progress, bookmarks |
| V003 | Performance | Comprehensive indexing strategy |
| V004 | AI features | Chapter detection, Q&A, recommendations, analytics |
| V005 | Identity system | Apple/Stripe integration, modern user management |

## 🔌 Code Interactions

### Internal Dependencies
```python
# Within core/database module
from .database_manager import get_database_manager, database_connection
from .database_migrations import DatabaseMigrationManager
from .database_indexes import DatabaseIndexManager
```

### External Usage
The database module is used by several other components:

#### **Services Integration**
- `platform/backend/services/context_service/main.py` - Vector embeddings storage
- `platform/backend/services/transcription_service/simple_main.py` - Audio processing results

#### **Core Modules**
- `core/auth/entitlements_manager.py` - User permissions and subscriptions
- `core/payments/apple_store_manager.py` - Apple App Store integration
- `core/payments/stripe_manager.py` - Stripe payment processing

#### **Testing**
- `tests/unit/test_connection_pooling.py` - Connection management tests
- `tests/unit/test_database_migrations.py` - Migration system tests
- `tests/unit/test_indexing_strategy.py` - Index performance tests

## 🏗️ Architecture Overview

### Connection Management
```mermaid
graph LR
    A[Application] --> B[DatabaseManager]
    B --> C[Primary Pool]
    B --> D[Replica Pool]
    C --> E[PostgreSQL Primary]
    D --> F[PostgreSQL Replica]
    B --> G[Health Monitoring]
    B --> H[Metrics Collection]
```

### Migration System
```mermaid
graph TD
    A[Migration Files] --> B[DatabaseMigrationManager]
    B --> C[Checksum Validation]
    B --> D[Dependency Checking]
    B --> E[Schema Application]
    E --> F[Rollback Support]
    B --> G[Migration Tracking]
    G --> H[schema_migrations table]
```

## ⚙️ Configuration

### Database Connection
```python
# Environment variables
DATABASE_URL = "postgresql://user:pass@host:port/db"
READ_REPLICA_URL = "postgresql://user:pass@replica:port/db"  # Optional

# Configuration options
DatabaseConfig(
    min_connections=5,
    max_connections=20,
    connection_timeout=30.0,
    enable_read_replica=True
)
```

### Vector Search Setup
```sql
-- Required extension
CREATE EXTENSION IF NOT EXISTS vector;

-- HNSW index for production
CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops) 
WITH (m = 16, ef_construction = 64);
```

## 🔥 Critical Security Issues

> ⚠️ **SECURITY ALERT**: Several critical vulnerabilities have been identified that must be fixed before production deployment.

### 1. SQL Injection Vulnerabilities
**Locations**: `database_manager.py:477,481`, `database_indexes.py:267-280`
```python
# VULNERABLE CODE:
await self.execute_query(f"ANALYZE {table}", fetch_all=False)

# SECURE REPLACEMENT:
from psycopg.sql import SQL, Identifier
await self.execute_query(SQL("ANALYZE {}").format(Identifier(table)), fetch_all=False)
```

### 2. Connection Pool Race Condition
**Location**: `database_manager.py:394-400`
```python
# BROKEN CODE:
if self.pool:  # self.pool doesn't exist!

# FIX:
if self.primary_pool:
    health_info["pool_info"] = {
        "size": self.primary_pool.size,
        "available": self.primary_pool.available
    }
```

### 3. Migration Rollback Injection
**Location**: `database_migrations.py:454-460`
```python
# DANGEROUS - Add validation:
def validate_rollback_sql(self, sql: str) -> bool:
    dangerous_keywords = ['DROP DATABASE', 'TRUNCATE', 'DELETE FROM users']
    return not any(keyword in sql.upper() for keyword in dangerous_keywords)
```

## 🚀 Usage Examples

### Basic Database Operations
```python
from core.database import get_database_manager, database_connection

# Get manager instance
db_manager = await get_database_manager()

# Execute queries
result = await db_manager.execute_query(
    "SELECT * FROM users WHERE email = %s", 
    ("user@example.com",)
)

# Use connection context manager
async with database_connection() as conn:
    cursor = await conn.execute("SELECT version()")
    version = await cursor.fetchone()
```

### Migration Management
```python
from core.database import DatabaseMigrationManager

# Initialize migration system
migration_manager = DatabaseMigrationManager(db_manager)
await migration_manager.initialize()

# Check status
status = await migration_manager.get_migration_status()
print(f"Applied: {status['applied']}, Pending: {status['pending']}")

# Apply migrations
results = await migration_manager.apply_migrations(dry_run=False)
```

### Index Management
```python
from core.database import DatabaseIndexManager

# Create all indexes
index_manager = DatabaseIndexManager()
results = await index_manager.create_all_indexes(db_manager)

# Analyze performance
analysis = await index_manager.analyze_index_usage(db_manager)
print(analysis['recommendations'])
```

## 📊 Monitoring & Health Checks

### Health Check Endpoints
```python
# Get detailed health status
health = await db_manager.get_health_status()
print(f"Status: {health['status']}")
print(f"Pool size: {health['pool_info']['size']}")
print(f"Active connections: {health['active_connections']}")
```

### Performance Metrics
```python
# Get performance metrics
metrics = db_manager.get_metrics_summary()
print(f"Queries executed: {metrics['queries_executed']}")
print(f"Average query time: {metrics['average_query_time']:.3f}s")
print(f"Slow queries: {metrics['slow_queries']}")
```

## 🔮 Future Changes Needed

### Immediate (Critical)
1. **Fix SQL injection vulnerabilities** - Replace f-strings with parameterized queries
2. **Fix connection pool health check** - Update to use `self.primary_pool`
3. **Add migration rollback validation** - Prevent malicious rollback SQL
4. **Fix missing imports** - Add `timedelta` import in `models/user.py:380`

### Short-term (High Priority)
1. **Implement database-level migration locks** - Prevent concurrent migrations
2. **Add comprehensive input validation** - Validate table names, IDs, etc.
3. **Improve error handling** - Better connection timeout and retry logic
4. **Add transaction isolation** - For index creation and complex operations

### Medium-term (Performance)
1. **Optimize vector index parameters** - Tune HNSW configuration for production
2. **Implement connection pooling optimization** - Dynamic pool sizing
3. **Add query performance monitoring** - Slow query detection and alerting
4. **Database partitioning strategy** - For large tables (embeddings, audit_logs)

### Long-term (Architecture)
1. **Read/write splitting optimization** - Improve replica usage patterns
2. **Multi-region support** - Cross-region replication and failover
3. **Advanced analytics queries** - Materialized views for reporting
4. **Schema evolution automation** - Automated migration generation

## 📋 Testing Strategy

### Unit Tests
- `test_connection_pooling.py` - Connection management and pooling
- `test_database_migrations.py` - Migration system functionality
- `test_indexing_strategy.py` - Index creation and optimization

### Integration Tests Needed
- Multi-service database interactions
- Vector similarity search performance
- Migration rollback scenarios
- Connection pool stress testing

## 🔒 Security Best Practices

1. **Use parameterized queries** - Prevent SQL injection
2. **Validate all inputs** - Table names, column names, user data
3. **Implement proper access controls** - Role-based database permissions
4. **Monitor database activity** - Log all schema changes and access patterns
5. **Regular security audits** - Check for new vulnerabilities
6. **Encrypt sensitive data** - At rest and in transit
7. **Implement backup encryption** - Secure backup storage
8. **Network security** - VPC, firewalls, connection encryption

## 📚 Dependencies

### Required Python Packages
```
psycopg[binary]>=3.1.0    # PostgreSQL adapter
psycopg-pool>=3.1.0       # Connection pooling
```

### Database Extensions
```sql
CREATE EXTENSION IF NOT EXISTS vector;      -- pgvector for embeddings
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- Query monitoring
```

### External Services
- **PostgreSQL 15+** with pgvector extension
- **pgbouncer** (recommended for connection pooling)
- **Monitoring tools** (Prometheus, Grafana for metrics)

---

> ⚠️ **Important**: This module contains critical security vulnerabilities that must be addressed before production deployment. See the "Critical Security Issues" section above for immediate actions required.