import os
import logging
import threading
from typing import Optional, Dict, Any, Tuple
from datetime import datetime, timedelta
from collections import defaultdict

from fastapi import APIRouter, HTTPException, status, Depends, Header, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr

from core.auth.auth import (
    create_access_token, create_refresh_token, verify_token,
    create_user, authenticate_user, create_or_update_oauth_user,
    get_current_user, UserRole, User, UserRegistration, USERS_DB
)

from core.services.email_service import get_email_service

logger = logging.getLogger(__name__)

router = APIRouter()
security = HTTPBearer()


class RateLimiter:

    def __init__(self):
        self._requests: Dict[str, list] = defaultdict(list)
        self._lock = threading.Lock()
        self._last_cleanup = datetime.utcnow()
        self._cleanup_interval = timedelta(minutes=5)

    def _cleanup_old_entries(self, window_seconds: int = 60):
        now = datetime.utcnow()
        if now - self._last_cleanup < self._cleanup_interval:
            return

        self._last_cleanup = now
        cutoff = now - timedelta(seconds=window_seconds * 2)

        ips_to_remove = []
        for ip, timestamps in self._requests.items():
            self._requests[ip] = [ts for ts in timestamps if ts > cutoff]
            if not self._requests[ip]:
                ips_to_remove.append(ip)

        for ip in ips_to_remove:
            del self._requests[ip]

    def check_rate_limit(self, ip: str, max_requests: int, window_seconds: int = 60) -> Tuple[bool, int]:
        now = datetime.utcnow()
        window_start = now - timedelta(seconds=window_seconds)

        with self._lock:
            self._cleanup_old_entries(window_seconds)

            timestamps = self._requests[ip]
            recent_requests = [ts for ts in timestamps if ts > window_start]

            if len(recent_requests) >= max_requests:
                oldest_in_window = min(recent_requests)
                retry_after = int((oldest_in_window + timedelta(seconds=window_seconds) - now).total_seconds()) + 1
                return False, max(retry_after, 1)

            self._requests[ip].append(now)
            self._requests[ip] = [ts for ts in self._requests[ip] if ts > window_start]

            return True, 0


_rate_limiter = RateLimiter()

SIGNIN_RATE_LIMIT = 5
SIGNUP_RATE_LIMIT = 3
RATE_LIMIT_WINDOW = 60


def get_client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()

    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip.strip()

    if request.client:
        return request.client.host

    return "unknown"


def check_signin_rate_limit(request: Request):
    ip = get_client_ip(request)
    allowed, retry_after = _rate_limiter.check_rate_limit(ip, SIGNIN_RATE_LIMIT, RATE_LIMIT_WINDOW)

    if not allowed:
        logger.warning(f"Rate limit exceeded for signin from IP: {ip}")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many login attempts. Please try again in {retry_after} seconds.",
            headers={"Retry-After": str(retry_after)}
        )


def check_signup_rate_limit(request: Request):
    ip = get_client_ip(request)
    allowed, retry_after = _rate_limiter.check_rate_limit(ip, SIGNUP_RATE_LIMIT, RATE_LIMIT_WINDOW)

    if not allowed:
        logger.warning(f"Rate limit exceeded for signup from IP: {ip}")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many signup attempts. Please try again in {retry_after} seconds.",
            headers={"Retry-After": str(retry_after)}
        )


def get_user_by_email(email: str) -> Optional[User]:
    for user_id, user_record in USERS_DB.items():
        if user_record["email"] == email:
            return User(
                id=user_id,
                email=user_record["email"],
                username=user_record["username"],
                display_name=user_record.get("display_name", user_record["email"].split('@')[0]),
                role=UserRole(user_record["role"]),
                is_active=user_record.get("is_active", True),
                email_verified=user_record.get("email_verified", True),
                created_at=user_record["created_at"]
            )
    return None


class GoogleSignInRequest(BaseModel):
    id_token: str

class AppleSignInRequest(BaseModel):
    id_token: str
    nonce: str
    user_info: Optional[Dict[str, Any]] = None

class EmailSignUpRequest(BaseModel):
    email: EmailStr
    password: str
    display_name: Optional[str] = None

class EmailSignInRequest(BaseModel):
    email: EmailStr
    password: str

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class LogoutRequest(BaseModel):
    refresh_token: str

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_at: Optional[int] = None
    user: Dict[str, Any]

class EmailVerificationRequest(BaseModel):
    email: EmailStr

class PasswordResetRequest(BaseModel):
    email: EmailStr


@router.post("/auth/google")
async def google_sign_in(request: GoogleSignInRequest):
    logger.info("Google sign in attempted - feature not yet available")
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Google Sign In coming soon! Please use email registration for now."
    )

@router.post("/auth/apple")
async def apple_sign_in(request: AppleSignInRequest):
    logger.info("Apple sign in attempted - feature not yet available")
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Apple Sign In coming soon! Please use email registration for now."
    )

@router.post("/auth/signup", response_model=AuthResponse)
async def email_sign_up(
    request: EmailSignUpRequest,
    _: None = Depends(check_signup_rate_limit)
):
    try:
        if get_user_by_email(request.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User with this email already exists"
            )

        user_registration = UserRegistration(
            email=request.email,
            username=request.email,
            password=request.password,
            role=UserRole.USER
        )
        user = await create_user(user_registration)

        try:
            email_service = get_email_service()
            await email_service.send_verification_email(
                email=request.email,
                verification_token="dummy-token-for-now",
                user_name=user.display_name
            )
        except Exception as e:
            logger.warning(f"Failed to send verification email: {e}")

        logger.info(f"Created new email user: {user.email}")

        access_token = create_access_token(data={"sub": user.email, "user_id": user.id})
        refresh_token = create_refresh_token(data={"sub": user.email, "user_id": user.id})

        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=int((datetime.utcnow() + timedelta(minutes=30)).timestamp()),
            user=user.to_dict()
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Email sign up failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Sign up failed"
        )

@router.post("/auth/signin", response_model=AuthResponse)
async def email_sign_in(
    request: EmailSignInRequest,
    _: None = Depends(check_signin_rate_limit)
):
    try:
        user = await authenticate_user(request.email, request.password)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )

        logger.info(f"Email sign in successful: {user.email}")

        access_token = create_access_token(data={"sub": user.email, "user_id": user.id})
        refresh_token = create_refresh_token(data={"sub": user.email, "user_id": user.id})

        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=int((datetime.utcnow() + timedelta(minutes=30)).timestamp()),
            user=user.to_dict()
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Email sign in failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

@router.post("/auth/refresh", response_model=AuthResponse)
async def refresh_token_endpoint(request: RefreshTokenRequest):
    try:
        payload = verify_token(request.refresh_token, "refresh")
        email = payload.get("sub")
        user_id = payload.get("user_id")

        if not email or not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token payload"
            )

        from db_utils import get_user_by_id
        user_data = get_user_by_id(user_id)
        if not user_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )

        access_token = create_access_token(data={"sub": email, "user_id": user_id})
        refresh_token = create_refresh_token(data={"sub": email, "user_id": user_id})

        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=int((datetime.utcnow() + timedelta(minutes=30)).timestamp()),
            user={
                "id": user_data.get("id"),
                "email": user_data.get("email"),
                "username": user_data.get("username") or user_data.get("email"),
                "display_name": user_data.get("display_name") or user_data.get("email", "").split('@')[0],
                "role": user_data.get("role", "user"),
                "is_active": user_data.get("is_active", True),
                "email_verified": user_data.get("email_verified", True),
                "created_at": user_data.get("created_at").isoformat() if user_data.get("created_at") else None
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token refresh failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token refresh failed: {str(e)}"
        )

@router.post("/auth/logout")
async def logout(
    request: Optional[LogoutRequest] = None,
    authorization: str = Header(None)
):
    try:
        user_email = "unknown"
        if authorization and authorization.startswith("Bearer "):
            try:
                token = authorization.split(" ")[1]
                payload = verify_token(token)
                user_email = payload.get("sub", "unknown")
            except Exception:
                pass

        logger.info(f"User logged out: {user_email}")
        return {"message": "Successfully logged out"}

    except Exception as e:
        logger.error(f"Logout error: {e}")
        return {"message": "Successfully logged out"}

@router.post("/password/reset")
async def request_password_reset(request: PasswordResetRequest):
    try:
        user = get_user_by_email(request.email)
        if user:
            email_service = get_email_service()
            await email_service.send_password_reset_email(
                email=request.email,
                reset_token="dummy-token",
                user_name=user.display_name
            )
    except Exception as e:
        logger.error(f"Password reset request failed: {e}")

    return {"message": "If an account with this email exists, a password reset link has been sent"}

@router.get("/auth/me", response_model=dict)
async def get_current_user_info(authorization: str = Header(None)):
    try:
        from db_utils import get_user_by_id

        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing or invalid authorization header")

        token = authorization.split(" ")[1]

        user_data = verify_token(token, "access")
        if not user_data:
            raise HTTPException(status_code=401, detail="Invalid or expired token")

        user_id = user_data.get("user_id")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token payload")

        user_db_data = get_user_by_id(user_id)
        if not user_db_data:
            raise HTTPException(status_code=404, detail="User not found")

        return {
            "id": user_db_data.get("id"),
            "email": user_db_data.get("email"),
            "display_name": user_db_data.get("display_name") or user_db_data.get("email", "").split('@')[0],
            "username": user_db_data.get("username") or user_db_data.get("email"),
            "is_verified": user_db_data.get("email_verified", True),
            "created_at": user_db_data.get("created_at").isoformat() if user_db_data.get("created_at") else None,
            "role": user_db_data.get("role", "user"),
            "subscription_status": "free",
            "avatar_url": None
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user info: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@router.get("/auth/health")
async def health_check():
    return {
        "status": "ok",
        "service": "authentication",
        "timestamp": datetime.utcnow().isoformat()
    }
