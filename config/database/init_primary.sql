-- Initialize PostgreSQL Primary Database for Replication
-- This script sets up the replication user and necessary permissions

-- Create replication user
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicator_pass';

-- Grant necessary permissions
GRANT CONNECT ON DATABASE betterbooks TO replicator;
GRANT USAGE ON SCHEMA public TO replicator;

-- Create replication slot for streaming replication
SELECT pg_create_physical_replication_slot('replica_slot');

-- Create archive directory if it doesn't exist
\! mkdir -p /var/lib/postgresql/archive

-- Log replication setup
\echo 'Primary database initialized for replication'
\echo 'Replication user: replicator'
\echo 'Replication slot: replica_slot'