# iOS Backend Alignment Document

## Overview
This document provides a comprehensive analysis of all API endpoints used by the iOS application and their corresponding backend implementation status. Each endpoint is categorized by its current state and includes recommendations for fixes.

## Endpoint Status Legend
- ✅ **Working** - Endpoint exists and functions correctly
- ⚠️ **Partial** - Endpoint exists but has issues
- ❌ **Missing** - Endpoint doesn't exist in backend
- 🔄 **Wrong Version** - iOS uses wrong endpoint version

---

## 1. AUTHENTICATION ENDPOINTS

### ✅ Working
| iOS Endpoint | Backend Status | Notes |
|-------------|----------------|-------|
| POST /auth/signup | ✅ Exists | Working, creates users with JWT tokens |
| POST /auth/signin | ✅ Exists | Working, validates passwords with bcrypt |

### ❌ Missing or Broken
| iOS Endpoint | Backend Status | Issue | Priority |
|-------------|----------------|-------|----------|
| POST /auth/google | ❌ 404 | Router included but endpoint not working | HIGH |
| POST /auth/apple | ❌ 404 | Router included but endpoint not working | HIGH |
| GET /auth/me | ❌ 404 | Exists in router but not accessible | HIGH |
| POST /auth/logout | ❌ Missing | Not implemented | MEDIUM |
| POST /auth/refresh | ❌ Missing | Not implemented | MEDIUM |
| POST /email/send-verification | ❌ Missing | Not implemented | LOW |
| POST /password/reset | ❌ Missing | Not implemented | LOW |

---

## 2. BOOKSTORE ENDPOINTS

### ✅ Working
| iOS Endpoint | Backend Status | Notes |
|-------------|----------------|-------|
| GET /bookstore/browse | ✅ Exists | Returns book catalog |
| GET /bookstore/categories | ✅ Exists | Returns book categories |
| GET /bookstore/books/{book_id} | ✅ Exists | Fixed with book_chapters table |
| POST /bookstore/purchase | ✅ Exists | Fixed with correct parameters |
| GET /bookstore/user/credits | ✅ Exists | Returns user credit balance |
| GET /bookstore/user/library | ✅ Exists | Returns user's purchased books |
| GET /bookstore/books/{book_id}/download | ✅ Exists | Returns download links |

### ❌ Missing
| iOS Endpoint | Backend Status | Issue | Priority |
|-------------|----------------|-------|----------|
| GET /bookstore/search | ❌ Missing | Search functionality needed | HIGH |
| POST /bookstore/user/initialize-credits | ❌ Missing | Credit initialization needed | HIGH |
| GET /bookstore/featured | ❌ Missing | Featured books filter | MEDIUM |
| GET /bookstore/bestsellers | ❌ Missing | Bestseller books filter | MEDIUM |
| GET /bookstore/test | ❌ Missing | Test endpoint | LOW |

---

## 3. V2 ENDPOINTS (iOS uses but don't exist)

| iOS Endpoint | Backend Status | Issue | Priority |
|-------------|----------------|-------|----------|
| POST /v2/bookstore/wishlist/{user_id}/{book_id} | ❌ Missing | Wishlist add | LOW |
| DELETE /v2/bookstore/wishlist/{user_id}/{book_id} | ❌ Missing | Wishlist remove | LOW |
| GET /v2/bookstore/wishlist/{user_id} | ❌ Missing | Get wishlist | LOW |
| POST /v2/bookstore/download | ❌ Missing | Download endpoint | LOW |

---

## 4. AI/LLM ENDPOINTS

### ✅ Working
| iOS Endpoint | Backend Status | Notes |
|-------------|----------------|-------|
| POST /complete | ✅ Exists | LLM chat completion (proxy to LLM Gateway) |
| POST /tts | ✅ Exists | Text-to-speech (proxy to TTS Service) |
| GET /context | ✅ Exists | Get context |
| GET /configs | ✅ Exists | Get AI personas config |

### ❌ Missing
| iOS Endpoint | Backend Status | Issue | Priority |
|-------------|----------------|-------|----------|
| POST /context | ❌ Missing | Only GET exists, not POST | MEDIUM |
| POST /detect-chapters | ❌ Missing | Chapter detection | LOW |
| POST /summarize-chapter | ❌ Missing | Chapter summarization | LOW |
| POST /generate-questions | ❌ Missing | Question generation | LOW |
| POST /llm/chat | ❌ Missing | Direct LLM chat | LOW |
| POST /tts/synthesize | ❌ Missing | Direct TTS | LOW |
| POST /batch | ❌ Missing | Batch operations | LOW |

---

## 5. PERSONA ENDPOINTS

### ✅ Working
| iOS Endpoint | Backend Status | Notes |
|-------------|----------------|-------|
| GET /bookstore/books/{book_id}/personas | ✅ Exists | Get book-specific personas |
| GET /personas | ✅ Exists | Get all personas |
| GET /personas/{persona_id} | ✅ Exists | Get specific persona details |

---

## 6. UTILITY ENDPOINTS

### ✅ Working
| iOS Endpoint | Backend Status | Notes |
|-------------|----------------|-------|
| GET /health | ✅ Exists | Health check |
| GET /books/{folder}/{file} | ✅ Exists | Serve book audio files |
| GET /books/cover/{folder}/{file} | ✅ Exists | Serve book covers |

### ❌ Missing
| iOS Endpoint | Backend Status | Issue | Priority |
|-------------|----------------|-------|----------|
| GET /books | ❌ Missing | Book list endpoint | LOW |

---

## 7. iOS SERVICE FILES USING ENDPOINTS

### Primary Services
1. **api_service.dart** - Main service, uses most endpoints
2. **bookstore_service.dart** - Uses v2 endpoints (needs update)
3. **bookstore_adapter.dart** - Bookstore functionality
4. **auth_service.dart** - Authentication endpoints
5. **optimized_api_service.dart** - Uses some non-existent endpoints
6. **simple_bookstore_service.dart** - Simplified bookstore

### Screens Using Services
- **bookstore_screen.dart** → bookstore_adapter.dart
- **book_details_screen.dart** → bookstore_adapter.dart, api_service.dart
- **home_tab_screen.dart** → bookstore_adapter.dart
- **mvp_player_screen.dart** → api_service.dart
- **enhanced_player_screen.dart** → api_service.dart

---

## RECOMMENDED FIX PRIORITY

### 🔴 CRITICAL (Block core functionality)
1. **Search functionality** - GET /bookstore/search
2. **Auth flow** - Fix /auth/me endpoint
3. **Credit initialization** - POST /bookstore/user/initialize-credits

### 🟡 HIGH (Important for UX)
1. **OAuth login** - Fix /auth/google and /auth/apple
2. **Featured/Bestsellers** - Add filtering endpoints
3. **POST /context** - Add POST method support

### 🟢 MEDIUM (Nice to have)
1. **Auth tokens** - /auth/refresh, /auth/logout
2. **Wishlist** - All wishlist endpoints
3. **Password reset** - Email verification flow

### ⚪ LOW (Future features)
1. **AI features** - Chapter detection, summarization, questions
2. **Direct service calls** - /llm/chat, /tts/synthesize
3. **Batch operations** - /batch endpoint

---

## iOS APP CHANGES NEEDED

### 1. Remove V2 Endpoints
- Update bookstore_service.dart to remove all /v2/ references
- Use standard /bookstore/ endpoints

### 2. Service Consolidation
- Consider using api_service.dart as primary service
- Remove duplicate implementations
- Standardize error handling

### 3. Fallback Handling
- Add proper fallbacks for missing endpoints
- Improve error messages for users
- Cache responses where appropriate

---

## BACKEND IMPLEMENTATION NOTES

### Quick Wins (Can implement immediately)
1. **Search endpoint** - Use existing browse logic with query filter
2. **Featured/Bestsellers** - Filter existing browse results
3. **Initialize credits** - Simple database operation
4. **Fix /auth/me** - Ensure route is properly registered

### Requires More Work
1. **OAuth integration** - Need provider configuration
2. **Wishlist system** - Need new database table
3. **AI features** - Need integration with AI services
4. **Email system** - Need email service configuration

---

## TESTING CHECKLIST

### After Implementation
- [ ] Test each endpoint with curl
- [ ] Verify iOS app connectivity
- [ ] Check error handling
- [ ] Test authentication flow
- [ ] Test purchase flow
- [ ] Test audio playback
- [ ] Test persona loading
- [ ] Test search functionality
- [ ] Test offline fallbacks

---

## QUESTIONS FOR DECISION

1. **V2 Endpoints**: Should we implement v2 endpoints or update iOS to use v1?
2. **AI Features**: Are chapter detection/summarization priority features?
3. **OAuth**: Which providers should we support (Google, Apple, both)?
4. **Wishlist**: Is wishlist functionality needed for MVP?
5. **Email**: Do we need email verification for MVP?
6. **Service Consolidation**: Should we refactor iOS to use fewer service classes?

---

## NEXT STEPS

Please review each section and provide feedback on:
1. Which endpoints to implement
2. Which to skip for MVP
3. Which iOS changes to make
4. Priority order for implementation

Add your comments below each section or at the end of this document.