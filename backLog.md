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