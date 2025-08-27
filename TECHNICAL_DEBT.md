# Technical Debt Tracker

## Critical Issues (Fix Immediately)

### 1. Test Environment Broken
- **Issue**: Tests failing due to missing imports (`chapter_detection` module)
- **Impact**: Cannot verify code quality or run CI/CD
- **Location**: `tests/unit/test_summaries_simple.py:16`
- **Fix**: Remove or mock missing imports
- **Priority**: 🔥 Critical

### 2. Demo Code in Production Paths  
- **Issue**: `simple_*` files mixed with production code
- **Impact**: Confusing deployment, harder maintenance
- **Files**: 
  - `platform/backend/services/api_gateway/simple_main.py`
  - `platform/backend/services/api_gateway/simple_bookstore_routes.py`
  - `platform/backend/services/transcription_service/simple_main.py`
  - `platform/mobile/mobile_app/lib/services/simple_bookstore_service.dart`
- **Priority**: 🔴 High

### 3. Hardcoded Mock Data in APIs
- **Issue**: Production endpoints returning hardcoded data instead of database
- **Impact**: Not production-ready, misleading functionality
- **Locations**: 
  - User credits always return `5`
  - Book catalog is hardcoded array
  - User library is static mock data
- **Priority**: 🔴 High

### 4. Authentication Mock Mode
- **Issue**: Mobile app using mock authentication in production
- **Impact**: No real user management, security risk
- **Location**: `platform/mobile/mobile_app/lib/services/auth_service.dart`
- **Priority**: 🔴 High

## High Priority Issues

### 5. Missing Database Connections
- **Issue**: Services not connecting to real database
- **Impact**: No persistence, data loss on restart
- **Files**: All service `main.py` files
- **Priority**: 🟠 High

### 6. 26 TODO/FIXME Items
- **Issue**: Unresolved technical debt scattered across codebase
- **Locations**: 
  - `core/infrastructure/` (multiple)
  - `platform/backend/services/api_gateway/user_bookstore_routes.py`
  - `core/bookstore/` modules
- **Priority**: 🟡 Medium

### 7. No Storage for Audio Files
- **Issue**: Audio files not properly stored/served
- **Impact**: Core feature (audiobook playback) broken
- **Solution**: Set up Azure Blob Storage
- **Priority**: 🟠 High

### 8. Inconsistent Error Handling
- **Issue**: Mix of error handling patterns across services
- **Impact**: Poor user experience, debugging difficulty
- **Priority**: 🟡 Medium

## Medium Priority Issues

### 9. Dockerfile Security Issues
- **Issue**: Running containers as root user
- **Location**: `platform/backend/services/api_gateway/Dockerfile:41`
- **Impact**: Security vulnerability
- **Priority**: 🟡 Medium

### 10. Missing Type Hints
- **Issue**: Inconsistent typing across Python codebase
- **Impact**: Reduced code quality, IDE support
- **Priority**: 🟡 Medium

### 11. No Proper Logging Strategy
- **Issue**: Inconsistent logging levels and formats
- **Impact**: Difficult debugging and monitoring
- **Priority**: 🟡 Medium

## Low Priority Issues

### 12. Unused Dependencies
- **Issue**: Multiple virtual environments, unused packages
- **Impact**: Larger build times, confusion
- **Priority**: 🟢 Low

### 13. Documentation Gaps
- **Issue**: Many README files but inconsistent content
- **Impact**: Developer onboarding difficulty
- **Priority**: 🟢 Low

## Action Plan Priority Matrix

### Week 1 (Critical)
1. ✅ Fix test environment
2. Remove `simple_*` files and merge into proper structure
3. Replace hardcoded data with real database calls
4. Enable real authentication

### Week 2 (High Priority)
1. Set up database connections for all services
2. Configure Azure Blob Storage for audio files
3. Address top 10 TODO/FIXME items
4. Implement proper error boundaries

### Week 3 (Medium Priority)
1. Fix Dockerfile security issues  
2. Add comprehensive type hints
3. Standardize logging across services
4. Implement proper health checks

## Progress Tracking

- [ ] Tests passing: **0/164 tests**
- [ ] Demo code removed: **0/4 files**
- [ ] Real data connected: **0/3 endpoints**
- [ ] Authentication enabled: **No**
- [ ] Audio storage configured: **No**
- [ ] TODOs addressed: **0/26 items**

## Success Metrics
- ✅ All tests passing (164 tests)
- ✅ No files with "simple_", "mock", "demo" in production paths
- ✅ All API endpoints return real data from database
- ✅ Mobile app uses real OAuth authentication
- ✅ Audio files served from Azure Blob Storage
- ✅ Zero TODO/FIXME items in critical paths

---
*Last updated: 2025-01-27*
*Priority levels: 🔥 Critical | 🔴 High | 🟠 High | 🟡 Medium | 🟢 Low*