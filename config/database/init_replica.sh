#!/bin/bash
# Initialize PostgreSQL Read Replica
# This script sets up streaming replication from the primary database

set -e

echo "Initializing PostgreSQL Read Replica..."

# Wait for primary to be ready
echo "Waiting for primary database to be ready..."
until pg_isready -h postgres_primary -p 5432 -U betterbooks; do
    echo "Waiting for primary database..."
    sleep 2
done

echo "Primary database is ready. Setting up replica..."

# Remove any existing data directory contents
rm -rf /var/lib/postgresql/data/*

# Create base backup from primary
echo "Creating base backup from primary..."
PGPASSWORD=$POSTGRES_REPLICATION_PASSWORD pg_basebackup \
    -h postgres_primary \
    -D /var/lib/postgresql/data \
    -U replicator \
    -v \
    -P \
    -W \
    -R

# Create standby.signal file to indicate this is a standby server
touch /var/lib/postgresql/data/standby.signal

# Set proper permissions
chown -R postgres:postgres /var/lib/postgresql/data
chmod 700 /var/lib/postgresql/data

echo "Read replica initialization complete"

# Start PostgreSQL normally (the CMD will handle this)
exec "$@"