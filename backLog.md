# append any issues, features or TODOs here, include all the relevant information to do the task.

## Email Verification System - Implementation Needed

**Issue**: Email verification flow is displayed in mobile app but no emails are sent because email service is not configured.

**Current Status**: 
- ✅ Authentication endpoints work (`POST /auth/register`, `POST /auth/login`)
- ❌ No email service configured (SendGrid/AWS SES API keys missing in `.env`)
- ❌ Backend User model doesn't include `email_verified` field
- ❌ No actual email sending functionality implemented
- ❌ Mobile app gets stuck at email verification screen

**Technical Details**:
- **Backend files**: `core/services/email_service.py` exists but no API keys configured
- **Auth system**: `core/auth/auth.py` User model needs `email_verified: bool` field
- **API routes**: `platform/backend/services/api_gateway/auth_routes.py` needs to return `email_verified` in user response
- **Mobile app**: `lib/providers/auth_provider.dart` checks `needsEmailVerification` based on `emailVerified` field

**Required Implementation**:
1. **Configure email service**: Add SendGrid or AWS SES API keys to `.env`
   ```
   SENDGRID_API_KEY=your-key-here
   # OR
   AWS_SES_ACCESS_KEY_ID=your-key
   AWS_SES_SECRET_ACCESS_KEY=your-secret
   EMAIL_FROM_ADDRESS=noreply@echowright.com
   ```
2. **Update User model**: Add `email_verified: bool = False` to `core/auth/auth.py`
3. **Implement verification flow**: Create endpoints for sending/verifying email tokens
4. **Update auth routes**: Return `email_verified` field in registration/login responses

**Priority**: Medium - Currently bypassed for testing, but needed for production

**Workaround**: Modified mobile app to skip email verification (temporary fix)

---

## 🚨 Critical MVP Blockers (Fix Immediately)

### 1. Authentication System Completely Broken
**Issue**: Users cannot create accounts or sign in via mobile app
**Symptoms**:
- Sign up with email/password returns "user not found" error
- Sign in with Google crashes the mobile app
- Sign in with Apple returns generic error
- Backend auth endpoints return 500 errors

**Root Cause**: 
- Backend services not properly connected to database
- Missing dependencies (google-auth, psycopg2) on Python 3.13
- Auth routes disabled in API Gateway due to import failures

**Impact**: 🔥 Critical - App unusable by real users
**Priority**: Day 1 fix required

### 2. All Book Data is Hardcoded Mock Data
**Issue**: No real book catalog, user libraries, or purchase system
**Current State**:
- Book catalog returns hardcoded array of 3 sample books
- User library always shows same mock books
- Credit system always returns 5 credits (hardcoded)
- No database persistence for purchases

**Impact**: 🔥 Critical - Not a real product
**Priority**: Day 1-2 fix required

### 3. No Audio Files Available
**Issue**: Audio playback uses placeholder URLs that don't work
**Current State**:
- All audiobook URLs point to non-existent local files
- No Azure blob storage configured
- No audio upload/management system
- Players show loading state indefinitely

**Impact**: 🔥 Critical - Core audiobook functionality broken
**Priority**: Day 2 fix required

### 4. Services Not Connected to Real Database
**Issue**: All services use in-memory data storage
**Current State**:
- User data lost on service restart
- No persistence across sessions
- PostgreSQL running but not connected to services
- All data is mock/temporary

**Impact**: 🔴 High - No data persistence
**Priority**: Day 1 fix required

---

## 🔧 Backend Technical Issues

### 5. API Gateway Service Discovery Failures
**Issue**: API Gateway cannot connect to backend services
**Symptoms**:
- "Internal Server Error" on all transcription endpoints
- Circuit breaker state not JSON serializable
- "Name or service not known" connection errors
- Services trying to connect to non-running containers

**Files Affected**:
- `platform/backend/services/api_gateway/main.py`
- All service routing through API Gateway

**Impact**: 🔴 High - Service mesh broken

### 6. Python Dependency Issues  
**Issue**: Critical packages failing to install on Python 3.13
**Missing**: google-auth, psycopg2, other authentication libs
**Impact**: 🔴 High - Authentication completely disabled
**Solution**: Use Python 3.11 or fix compatibility

### 7. JSON Serialization Errors in Logging
**Issue**: DateTime and ErrorCategory objects not JSON serializable
**Symptoms**: Logging middleware crashes when trying to log errors
**Impact**: 🟠 Medium - Poor debugging capability

---

## 🗑️ Overengineered Features to Remove/Simplify

### 8. Complex Infrastructure Monitoring Stack
**Unnecessary for MVP**:
- Prometheus metrics collection
- Grafana dashboards  
- Jaeger distributed tracing
- Complex health check endpoints with system metrics

**Recommendation**: Keep basic `/health` endpoint, remove the rest

### 9. Advanced Caching System
**Unnecessary for MVP**:
- Redis semantic caching with vector similarity
- Multi-layer response caching
- Cache hit rate monitoring
- Predictive preloading

**Recommendation**: Use simple in-memory caching initially

### 10. Rate Limiting & Usage Analytics
**Unnecessary for MVP**:
- Subscription-tier based rate limits
- Real-time usage analytics with dedicated tables
- Analytics flush intervals and batching
- User engagement metrics tracking

**Recommendation**: Remove completely for MVP

### 11. Audio Processing Pipeline
**Unnecessary for MVP**:
- WebRTC voice activity detection
- Real-time audio streaming via WebSocket
- Audio optimization and format conversion
- Chapter detection algorithms

**Recommendation**: Use simple HTTP audio file serving

### 12. Advanced AI Features
**Unnecessary for MVP**:
- Fine-tuning model infrastructure
- RAG (Retrieval Augmented Generation) system
- Document upload and processing
- Context service with vector embeddings
- Persona creation wizard

**Recommendation**: Use simple prompt-based personas

### 13. Complex Authentication
**Unnecessary for MVP**:
- Email verification system
- Password reset with tokens
- OAuth integration with Google/Apple
- Role-based access control (RBAC)

**Recommendation**: Simple email/password auth only

---

## 🎯 MVP Simplification Plan

### Core Services to Keep:
1. **API Gateway** - Simplified routes for auth, books, chat
2. **LLM Gateway** - Basic persona chat only
3. **PostgreSQL** - Simple user, book, purchase tables
4. **Mobile App** - Core UI for books + chat

### Services to Remove:
1. **Context Service** - Not needed for basic chat
2. **TTS Service** - Use simple audio file playback
3. **Transcription Service** - Not needed for MVP
4. **Monitoring Stack** - Prometheus, Grafana, Jaeger

### Features to Implement:
1. Working email/password authentication
2. Real book catalog from database
3. Audio file storage in Azure blob
4. Basic credit system with purchases
5. Simple AI chat with personas

### Features to Remove:
1. Email verification
2. OAuth authentication
3. Advanced AI features (RAG, fine-tuning)
4. Real-time audio streaming
5. Usage analytics and monitoring
6. Rate limiting and caching

---

## ✅ Action Items for MVP Launch

### Day 1 - Critical Fixes
- [ ] Fix authentication system - connect to real database
- [ ] Remove complex monitoring stack
- [ ] Simplify API Gateway to core routes only
- [ ] Fix Python dependency issues

### Day 2 - Core Data
- [ ] Connect all services to PostgreSQL database
- [ ] Create real book catalog with sample data
- [ ] Set up Azure blob storage for audio files
- [ ] Remove unnecessary services (context, tts, transcription)

### Day 3 - Testing & Polish
- [ ] Test complete user flow: signup → browse → purchase → listen → chat
- [ ] Deploy simplified stack to Azure
- [ ] Test mobile app against real backend
- [ ] Document working commands in CLAUDE.md