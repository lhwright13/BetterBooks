"""
Database Management Module

Contains database utilities and management for EchoWright:
- Connection pooling and async management
- Migration system
- Index optimization strategies
- Storage utilities for AI features
"""

from .database_manager import get_database_manager, database_connection
from .database_migrations import DatabaseMigrationManager
from .database_indexes import DatabaseIndexManager

__all__ = [
    'get_database_manager',
    'database_connection', 
    'DatabaseMigrationManager',
    'DatabaseIndexManager'
]