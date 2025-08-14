# Known Bugs

This file tracks known bugs in the BetterBooks codebase that need to be fixed.

## Bug #1: Password Inconsistency in PgBouncer Primary Configuration

**File**: `config/local/pgbouncer_primary.ini:4`

**Issue**: Password mismatch between PgBouncer primary configuration and other database configurations.

**Details**:
- Current: `* = host = postgres_primary port=5432 user=betterbooks password=testpassword123 dbname=betterbooks`
- Expected: `* = host = postgres_primary port=5432 user=betterbooks password=betterbooks dbname=betterbooks`

**Impact**: 
- May cause authentication failures when PgBouncer tries to connect to PostgreSQL
- Inconsistent with other configurations that use `password=betterbooks`

**Evidence**:
- `pgbouncer_replica.ini` uses `password=betterbooks`
- `pgbouncer.ini` uses `password=betterbooks` 
- Docker Compose environment variables default to `betterbooks`

**Fix Required**:
Change line 4 in `config/local/pgbouncer_primary.ini`:
```ini
# FROM:
* = host = postgres_primary port=5432 user=betterbooks password=testpassword123 dbname=betterbooks

# TO:
* = host = postgres_primary port=5432 user=betterbooks password=betterbooks dbname=betterbooks
```

**Priority**: Medium - Could cause connection issues in local development

**Discovered**: 2025-08-14 while creating README for config/local directory

---

## Bug #2: Unused Replica Configuration Files

**Files**: 
- `config/local/postgresql_replica.conf`
- `config/local/pgbouncer_replica.ini`

**Issue**: Configuration files exist but are not used in main `docker-compose.yml`

**Details**:
- Files are present and configured for PostgreSQL read replica setup
- Main `docker-compose.yml` doesn't mount or use these configurations
- Only referenced in `config/docker/docker-compose.yml` for multi-node setup

**Impact**: 
- Confusing for developers - unclear which configs are active
- Maintenance overhead for unused files
- Potential source of configuration drift

**Options**:
1. Remove unused files if replica setup not planned
2. Add documentation explaining they're for future HA setup
3. Integrate into main docker-compose.yml if replica functionality needed

**Priority**: Low - Documentation/maintenance issue, not functional bug

**Discovered**: 2025-08-14 while analyzing config/local directory usage

---

## Bug #3: Inconsistent Port Configuration in Dockerfiles

**Files**: All service Dockerfiles

**Issue**: Updated Dockerfiles use port 8000 in CMD but services should use different ports

**Details**:
- All services now use `CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]`
- Docker-compose maps different external ports but containers all use internal port 8000
- This is actually correct behavior - containers can use the same internal port

**Status**: Not a bug - Docker handles port isolation correctly

**Priority**: None - False alarm

**Discovered**: 2025-08-14 during Docker build optimizations

---

## Bug #5: Test Docker Compose Configuration Issues (FIXED)

**File**: `config/testing/docker-compose.test.yml`

**Issues Found & Fixed**:
1. **Port Mismatches** - Services mapped to wrong internal ports (8001, 8002, etc.) instead of 8000
2. **Missing Build Cache** - No cache_from configuration for faster CI builds
3. **Outdated Environment Variables** - Used legacy individual DB vars instead of DATABASE_URL
4. **Wrong Dockerfile Reference** - Transcription service used full Dockerfile instead of minimal
5. **Missing Redis Configuration** - Services missing REDIS_URL environment variables

**Fixes Applied**:
- Updated all port mappings to use 8000 internally
- Added cache_from configuration for all services  
- Switched to DATABASE_URL format for consistency
- Updated transcription service to use Dockerfile_minimal
- Added Redis URL environment variables

**Priority**: High - Was blocking test environment

**Status**: ✅ FIXED - 2025-08-14

**Discovered**: 2025-08-14 during Docker optimization review

---

## Bug #6: API Gateway Transcription Service Connectivity Issues

**File**: `platform/backend/services/api_gateway/main.py`

**Issue**: API Gateway cannot connect to backend services, causing transcription endpoints to fail with internal server errors

**Symptoms**:
- ❌ GET `/transcription/health` returns "Internal Server Error" 
- ❌ GET `/transcription/config` returns "Internal Server Error"
- ❌ POST `/transcription/test` returns "Internal Server Error"
- ❌ JSON serialization errors: `Object of type ErrorCategory is not JSON serializable`
- ❌ Connection errors: `[Errno -2] Name or service not known`

**Root Causes**:
1. **Service Discovery Issues**: API Gateway trying to connect to services that may not be running
2. **Circuit Breaker Problems**: Circuit breaker state not being handled properly in JSON serialization
3. **Structured Logging Errors**: DateTime and ErrorCategory objects not JSON serializable in logging middleware
4. **Network Connectivity**: Some backend services (LLM Gateway, Context Service) not running causing cascading failures

**Technical Details**:
- API Gateway tries to connect to multiple services on startup
- Error occurs in logging middleware when trying to serialize complex objects
- Circuit breaker status includes non-serializable objects
- Services expected at URLs like `http://llm_gateway:8000` but containers may not be running

**Error Stack Trace**:
```
TypeError: Object of type ErrorCategory is not JSON serializable
httpx.ConnectError: [Errno -2] Name or service not known
```

**Current Workaround**:
- ✅ Direct transcription service connection works (port 8003)
- ✅ Mobile app configured to use direct service URL
- ✅ All transcription functionality working via direct connection

**Impact**: 
- **High** - Blocks API Gateway transcription routing
- **Medium** - Workaround available via direct service connection
- **Low** - Does not affect core transcription functionality

**Services Affected**:
- API Gateway (port 8000) - Cannot route transcription requests
- Transcription Service (port 8003) - Works directly, fails through gateway

**Services Working**:
- ✅ Transcription Service direct access
- ✅ Azure Speech Service integration
- ✅ Mobile app integration (via direct connection)
- ✅ All transcription endpoints when accessed directly

**Environment**:
- Docker Compose development setup
- Services: API Gateway, Transcription Service, PostgreSQL, PgBouncer
- Missing services: LLM Gateway, Context Service, TTS Service

**Investigation Needed**:
1. Fix JSON serialization in logging middleware for ErrorCategory and datetime objects
2. Debug service discovery and networking between containers
3. Implement proper circuit breaker state serialization
4. Add graceful degradation when dependent services are unavailable
5. Fix model_dump() vs dict() compatibility issues in Pydantic models

**Temporary Fix Applied**:
- Mobile app points to direct transcription service (`http://localhost:8003`)
- Updated speech service endpoints to use direct URLs
- Documentation reflects workaround approach

**Files Modified for Workaround**:
- `platform/mobile/mobile_app/lib/services/speech_service.dart` - Direct service URLs
- `docs/setup/VOICE_TO_TEXT_OPTION1.md` - Documents current limitation

**Priority**: Medium - Has working workaround, but should be fixed for production

**Status**: 🔧 WORKAROUND IMPLEMENTED - Direct service connection working

**Discovered**: 2025-08-14 during Azure Speech Service Option 1 implementation

**Next Steps**:
1. Start all required backend services (LLM Gateway, Context Service, TTS Service)
2. Fix JSON serialization issues in error handling middleware
3. Test API Gateway routing with all services running
4. Update mobile app to use API Gateway once fixed

