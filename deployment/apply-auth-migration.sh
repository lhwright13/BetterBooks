#!/bin/bash

# Apply Authentication Database Migration for EchoWright
# This script applies the email verification system migration to PostgreSQL

set -e

echo "🗄️  Applying authentication database migration..."

MIGRATION_FILE="V006_20250123_email_verification_system.sql"
MIGRATION_PATH="/app/core/database/migrations/$MIGRATION_FILE"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: kubectl is not configured or cluster is not accessible"
    echo "Please configure kubectl to connect to your AKS cluster"
    exit 1
fi

# Check if postgres pod is running
if ! kubectl get pods -n betterbooks | grep postgres | grep Running > /dev/null; then
    echo "❌ Error: PostgreSQL pod is not running"
    echo "Please ensure PostgreSQL is deployed and running:"
    echo "  kubectl get pods -n betterbooks"
    exit 1
fi

POSTGRES_POD=$(kubectl get pods -n betterbooks -l app=postgres -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$POSTGRES_POD" ]]; then
    echo "❌ Error: Could not find PostgreSQL pod"
    echo "Available pods:"
    kubectl get pods -n betterbooks
    exit 1
fi

echo "✅ Found PostgreSQL pod: $POSTGRES_POD"

# Check if migration file exists locally
LOCAL_MIGRATION_PATH="core/database/migrations/$MIGRATION_FILE"

if [[ ! -f "$LOCAL_MIGRATION_PATH" ]]; then
    echo "❌ Error: Migration file not found at $LOCAL_MIGRATION_PATH"
    echo "Available migration files:"
    ls -la core/database/migrations/ || echo "No migration directory found"
    exit 1
fi

echo "✅ Found migration file: $LOCAL_MIGRATION_PATH"

# Copy migration file to PostgreSQL pod
echo "📄 Copying migration file to PostgreSQL pod..."

kubectl cp "$LOCAL_MIGRATION_PATH" "betterbooks/$POSTGRES_POD:/tmp/$MIGRATION_FILE"

echo "✅ Migration file copied to pod"

# Check if migration has already been applied
echo "🔍 Checking if migration has already been applied..."

MIGRATION_EXISTS=$(kubectl exec -n betterbooks "$POSTGRES_POD" -- psql -U betterbooks -d betterbooks -t -c "
SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'users' 
    AND column_name = 'email_verified'
);" 2>/dev/null | xargs || echo "false")

if [[ "$MIGRATION_EXISTS" == "true" || "$MIGRATION_EXISTS" == "t" ]]; then
    echo "⚠️  Migration appears to already be applied (email_verified column exists)"
    echo "Checking for other migration-specific columns..."
    
    # Check for other columns added by this migration
    OTHER_COLUMNS=$(kubectl exec -n betterbooks "$POSTGRES_POD" -- psql -U betterbooks -d betterbooks -t -c "
    SELECT string_agg(column_name, ', ') 
    FROM information_schema.columns 
    WHERE table_name = 'users' 
    AND column_name IN ('email_verification_token', 'password_reset_token', 'password_reset_expires_at');" 2>/dev/null | xargs || echo "")
    
    if [[ -n "$OTHER_COLUMNS" ]]; then
        echo "✅ Migration columns found: $OTHER_COLUMNS"
        echo "Migration has already been applied successfully"
        exit 0
    else
        echo "⚠️  Partial migration detected, continuing with full migration..."
    fi
else
    echo "✅ Migration has not been applied yet, proceeding..."
fi

# Apply the migration
echo "🚀 Applying authentication migration..."

kubectl exec -n betterbooks "$POSTGRES_POD" -- psql -U betterbooks -d betterbooks -f "/tmp/$MIGRATION_FILE"

if [[ $? -eq 0 ]]; then
    echo "✅ Migration applied successfully"
else
    echo "❌ Migration failed"
    exit 1
fi

# Verify migration was applied
echo "🔍 Verifying migration was applied..."

VERIFICATION=$(kubectl exec -n betterbooks "$POSTGRES_POD" -- psql -U betterbooks -d betterbooks -t -c "
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN (
    'email_verified', 
    'email_verification_token', 
    'email_verification_expires_at',
    'password_reset_token',
    'password_reset_expires_at'
)
ORDER BY column_name;" 2>/dev/null)

if [[ -n "$VERIFICATION" ]]; then
    echo "✅ Migration verification successful"
    echo "Added columns:"
    echo "$VERIFICATION"
else
    echo "❌ Migration verification failed"
    exit 1
fi

# Clean up migration file from pod
kubectl exec -n betterbooks "$POSTGRES_POD" -- rm -f "/tmp/$MIGRATION_FILE"

echo ""
echo "🎉 Authentication database migration completed successfully!"
echo ""
echo "The following features are now available:"
echo "- ✅ Email verification for new registrations"
echo "- ✅ Password reset with secure tokens"
echo "- ✅ Time-limited verification tokens"
echo "- ✅ Account activation workflow"
echo ""
echo "Next steps:"
echo "1. Deploy updated API Gateway with authentication features"
echo "2. Test email verification endpoints"
echo "3. Configure email service providers (SendGrid/AWS SES)"