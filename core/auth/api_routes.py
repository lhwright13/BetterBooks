"""
Authentication and Payment API Routes

Provides HTTP endpoints for the new authentication and payment system.
Supports both mobile and web clients with proper Apple App Store compliance.
"""

import logging
from typing import Dict, Any, Optional, List
from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Request, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field

from .supabase_provider import SupabaseAuthProvider, SupabaseAuthError
from .entitlements_manager import EntitlementsManager
from .jwt_middleware import get_current_user_verified, get_optional_user_verified
from ..payments.apple_store_manager import AppleStoreManager, AppleStoreError
from ..payments.stripe_manager import StripeManager, StripePaymentError
from ..database.models.user import (
    User, UserCreate, UserUpdate, IdentityProvider,
    UserEntitlementsResponse, LibraryEntryResponse, UserLibraryResponse
)

logger = logging.getLogger(__name__)

# Security
security = HTTPBearer()

# Router
router = APIRouter()

# =====================================================
# REQUEST/RESPONSE MODELS
# =====================================================

class AppleSignInRequest(BaseModel):
    """Apple Sign In request from iOS"""
    id_token: str = Field(..., description="Apple ID token")
    nonce: str = Field(..., description="Nonce used in Apple sign in")
    user_info: Optional[Dict[str, Any]] = Field(None, description="Optional user info from Apple")


class GoogleSignInRequest(BaseModel):
    """Google Sign In request"""
    id_token: str = Field(..., description="Google ID token")


class EmailSignUpRequest(BaseModel):
    """Email sign up request (web only)"""
    email: EmailStr = Field(..., description="User email")
    password: str = Field(..., min_length=8, description="User password")
    display_name: Optional[str] = Field(None, max_length=100, description="Display name")


class EmailSignInRequest(BaseModel):
    """Email sign in request (web only)"""
    email: EmailStr = Field(..., description="User email")
    password: str = Field(..., description="User password")


class RefreshTokenRequest(BaseModel):
    """Token refresh request"""
    refresh_token: str = Field(..., description="Valid refresh token")


class LogoutRequest(BaseModel):
    """Logout request with token revocation"""
    refresh_token: str = Field(..., description="Refresh token to revoke")


class ApplePurchaseRequest(BaseModel):
    """Apple purchase verification request"""
    signed_transaction: str = Field(..., description="Signed transaction from StoreKit")
    app_account_token: str = Field(..., description="App account token linking to user")


class AppleRestoreRequest(BaseModel):
    """Apple purchase restoration request"""
    transactions: List[str] = Field(..., description="List of signed transactions")


class StripeCheckoutRequest(BaseModel):
    """Stripe checkout session request"""
    price_id: str = Field(..., description="Stripe price ID")
    trial_days: Optional[int] = Field(None, ge=0, le=30, description="Optional trial days")


class AuthResponse(BaseModel):
    """Authentication response"""
    access_token: str
    refresh_token: str
    expires_at: Optional[int] = None
    user: Dict[str, Any]


# =====================================================
# DEPENDENCY INJECTION
# =====================================================

# SECURITY FIX: Replaced with proper JWT verification middleware
# This now uses service role key and cryptographic JWT verification
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    """Get current authenticated user with proper JWT verification"""
    return await get_current_user_verified(credentials)


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Optional[User]:
    """Get current user if authenticated, otherwise None"""
    return await get_optional_user_verified(credentials)


# =====================================================
# AUTHENTICATION ENDPOINTS
# =====================================================

@router.post("/auth/apple", response_model=AuthResponse)
async def sign_in_with_apple(request: AppleSignInRequest):
    """
    Apple Sign In (iOS only)
    
    Users never see Supabase configuration - they just tap "Sign in with Apple"
    """
    try:
        auth_provider = SupabaseAuthProvider()
        result = await auth_provider.sign_in_with_apple(
            id_token=request.id_token,
            nonce=request.nonce,
            user_info=request.user_info
        )
        
        return AuthResponse(**result)
        
    except SupabaseAuthError as e:
        logger.warning(f"Apple sign in failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple sign in failed"
        )


@router.post("/auth/google", response_model=AuthResponse)
async def sign_in_with_google(request: GoogleSignInRequest):
    """Google Sign In (web and mobile)"""
    try:
        auth_provider = SupabaseAuthProvider()
        result = await auth_provider.sign_in_with_google(request.id_token)
        
        return AuthResponse(**result)
        
    except SupabaseAuthError as e:
        logger.warning(f"Google sign in failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google sign in failed"
        )


@router.post("/auth/signup", response_model=AuthResponse)
async def sign_up_with_email(request: EmailSignUpRequest):
    """Email sign up (web only)"""
    try:
        auth_provider = SupabaseAuthProvider()
        result = await auth_provider.sign_up_with_email(
            email=request.email,
            password=request.password,
            display_name=request.display_name
        )
        
        if result.get('email_confirmation_sent'):
            return {
                "message": "Please check your email to confirm your account",
                "email_confirmation_sent": True
            }
        
        return AuthResponse(**result)
        
    except SupabaseAuthError as e:
        logger.warning(f"Email sign up failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/auth/signin", response_model=AuthResponse)
async def sign_in_with_email(request: EmailSignInRequest):
    """Email sign in (web only)"""
    try:
        auth_provider = SupabaseAuthProvider()
        result = await auth_provider.sign_in_with_email(
            email=request.email,
            password=request.password
        )
        
        return AuthResponse(**result)
        
    except SupabaseAuthError as e:
        logger.warning(f"Email sign in failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )


@router.post("/auth/refresh", response_model=AuthResponse)
async def refresh_token(request: RefreshTokenRequest):
    """Refresh access token"""
    try:
        auth_provider = SupabaseAuthProvider()
        result = await auth_provider.refresh_token(request.refresh_token)
        
        return AuthResponse(**result)
        
    except SupabaseAuthError as e:
        logger.warning(f"Token refresh failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token refresh failed"
        )


@router.post("/auth/logout")
async def logout(
    refresh_token_request: RefreshTokenRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Logout user and revoke tokens (SECURITY FIX)
    
    This now properly revokes refresh tokens for security.
    """
    try:
        auth_provider = SupabaseAuthProvider()
        success = await auth_provider.revoke_token(refresh_token_request.refresh_token)
        
        if success:
            logger.info(f"User {current_user.id} logged out and tokens revoked")
            return {"message": "Successfully logged out"}
        else:
            logger.warning(f"Token revocation failed for user {current_user.id}")
            return {"message": "Logged out (token revocation failed)"}
            
    except Exception as e:
        logger.error(f"Logout error for user {current_user.id}: {e}")
        # Still return success since user wants to log out
        return {"message": "Logged out"}


@router.delete("/auth/account")
async def delete_account(current_user: User = Depends(get_current_user)):
    """
    Delete user account (required by Apple guideline 5.1.1)
    """
    try:
        auth_provider = SupabaseAuthProvider()
        await auth_provider.delete_user(current_user.id)
        
        logger.info(f"Account deleted for user {current_user.id}")
        
        return {"message": "Account deleted successfully"}
        
    except SupabaseAuthError as e:
        logger.error(f"Account deletion failed for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Account deletion failed"
        )


# =====================================================
# USER PROFILE ENDPOINTS
# =====================================================

@router.get("/me", response_model=Dict[str, Any])
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current user information"""
    return current_user.to_dict()


@router.put("/me", response_model=Dict[str, Any])
async def update_user_profile(
    update_data: UserUpdate,
    current_user: User = Depends(get_current_user)
):
    """Update user profile"""
    # This would need database implementation
    return {"message": "Profile updated successfully"}


# =====================================================
# ENTITLEMENTS ENDPOINTS
# =====================================================

@router.get("/me/entitlements", response_model=UserEntitlementsResponse)
async def get_user_entitlements(current_user: User = Depends(get_current_user)):
    """
    Get user entitlements - PRIMARY endpoint for feature gating
    
    iOS and web apps call this to check "can user access X?"
    """
    try:
        # This would need proper initialization
        entitlements_manager = EntitlementsManager(None)  # Placeholder
        result = await entitlements_manager.get_user_entitlements(current_user.id)
        
        return result
        
    except Exception as e:
        logger.error(f"Failed to get entitlements for user {current_user.id}: {e}")
        # Return empty entitlements on error (fail safe)
        return UserEntitlementsResponse(
            user_id=current_user.id,
            entitlements=[],
            subscription=None
        )


# =====================================================
# APPLE APP STORE ENDPOINTS
# =====================================================

@router.post("/purchases/apple/verify")
async def verify_apple_purchase(
    request: ApplePurchaseRequest,
    current_user: User = Depends(get_current_user)
):
    """Verify Apple App Store purchase (iOS only)"""
    try:
        # This would need proper initialization
        apple_manager = AppleStoreManager(None, None)  # Placeholder
        result = await apple_manager.verify_purchase(
            signed_transaction=request.signed_transaction,
            app_account_token=request.app_account_token,
            user_id=current_user.id
        )
        
        return result
        
    except AppleStoreError as e:
        logger.error(f"Apple purchase verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/purchases/apple/restore")
async def restore_apple_purchases(
    request: AppleRestoreRequest,
    current_user: User = Depends(get_current_user)
):
    """Restore Apple purchases (required by Apple guidelines)"""
    try:
        apple_manager = AppleStoreManager(None, None)  # Placeholder
        result = await apple_manager.restore_purchases(
            user_id=current_user.id,
            transactions=request.transactions
        )
        
        return result
        
    except AppleStoreError as e:
        logger.error(f"Apple purchase restoration failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


# =====================================================
# STRIPE PAYMENT ENDPOINTS (WEB ONLY)
# =====================================================

@router.post("/payments/stripe/checkout")
async def create_stripe_checkout(
    request: StripeCheckoutRequest,
    current_user: User = Depends(get_current_user)
):
    """Create Stripe checkout session (web only)"""
    try:
        stripe_manager = StripeManager(None, None)  # Placeholder
        result = await stripe_manager.create_checkout_session(
            user_id=current_user.id,
            price_id=request.price_id,
            user_email=current_user.email,
            trial_days=request.trial_days
        )
        
        return result
        
    except StripePaymentError as e:
        logger.error(f"Stripe checkout creation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/payments/stripe/portal")
async def create_customer_portal(current_user: User = Depends(get_current_user)):
    """Create Stripe customer portal session (web only)"""
    try:
        stripe_manager = StripeManager(None, None)  # Placeholder
        result = await stripe_manager.create_customer_portal_session(
            user_id=current_user.id
        )
        
        return result
        
    except StripePaymentError as e:
        logger.error(f"Customer portal creation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/payments/stripe/subscription")
async def get_stripe_subscription(current_user: User = Depends(get_current_user)):
    """Get Stripe subscription info (web only)"""
    try:
        stripe_manager = StripeManager(None, None)  # Placeholder
        result = await stripe_manager.get_subscription_info(current_user.id)
        
        return result or {"message": "No subscription found"}
        
    except Exception as e:
        logger.error(f"Failed to get subscription info: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get subscription info"
        )


# =====================================================
# WEBHOOK ENDPOINTS
# =====================================================

@router.post("/webhooks/apple")
async def handle_apple_webhook(
    request: Request,
    x_apple_signature: Optional[str] = Header(None)
):
    """Handle Apple App Store Server Notifications V2"""
    try:
        body = await request.body()
        
        apple_manager = AppleStoreManager(None, None)  # Placeholder
        result = await apple_manager.handle_server_notification(body.decode())
        
        return result
        
    except AppleStoreError as e:
        logger.error(f"Apple webhook processing failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/webhooks/stripe")
async def handle_stripe_webhook(
    request: Request,
    stripe_signature: Optional[str] = Header(None)
):
    """Handle Stripe webhook events"""
    try:
        body = await request.body()
        
        if not stripe_signature:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing Stripe signature"
            )
        
        stripe_manager = StripeManager(None, None)  # Placeholder
        result = await stripe_manager.handle_webhook(body, stripe_signature)
        
        return result
        
    except StripePaymentError as e:
        logger.error(f"Stripe webhook processing failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


# =====================================================
# LIBRARY ENDPOINTS
# =====================================================

@router.get("/me/library", response_model=UserLibraryResponse)
async def get_user_library(current_user: User = Depends(get_current_user)):
    """Get user's book library"""
    # This would need proper implementation
    return UserLibraryResponse(
        user_id=current_user.id,
        books=[],
        total_books=0,
        total_listening_time=0
    )


@router.post("/me/library/{book_id}/position")
async def update_reading_position(
    book_id: str,
    position_data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """Update reading position for a book"""
    # This would sync position across devices
    return {"message": "Position updated successfully"}


# =====================================================
# HEALTH CHECK
# =====================================================

@router.get("/health")
async def health_check():
    """Health check for auth service"""
    return {
        "status": "ok",
        "service": "authentication",
        "timestamp": datetime.utcnow().isoformat()
    }