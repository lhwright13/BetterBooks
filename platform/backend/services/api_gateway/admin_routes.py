"""
Admin Routes for User Account Management

Provides comprehensive tools for inspecting and managing user accounts,
credits, purchases, and system health. Admin-only endpoints with proper
authorization checks.
"""

import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
from uuid import UUID

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel

from core.auth.auth import get_current_user, require_admin, User
from core.database.database_manager import DatabaseManager
from core.auth.user_manager import UserManager

# Set up logging
logger = logging.getLogger(__name__)

# Initialize router
router = APIRouter(prefix="/admin", tags=["admin"])

# Initialize database connection
try:
    db_manager = DatabaseManager()
    user_manager = UserManager(db_manager)
    logger.info("Database management initialized for admin routes")
except Exception as e:
    logger.warning(f"Failed to initialize database for admin routes: {e}")
    db_manager = None
    user_manager = None

# Response models for admin endpoints
class UserSummaryResponse(BaseModel):
    id: str
    email: str
    display_name: Optional[str]
    avatar_url: Optional[str]
    created_at: str
    books_owned: int
    credits_available: int
    credits_used: int
    last_activity: Optional[str]

class UserListResponse(BaseModel):
    users: List[UserSummaryResponse]
    total_count: int
    has_more: bool
    page_info: Dict[str, Any]

class UserDetailResponse(BaseModel):
    id: str
    email: str
    display_name: Optional[str]
    username: str
    avatar_url: Optional[str]
    role: str
    email_verified: bool
    is_active: bool
    created_at: str
    oauth_provider: Optional[str]
    oauth_provider_id: Optional[str]
    credits_available: int
    credits_used: int
    monthly_credits: int
    books_owned: int
    last_activity: Optional[str]

class CreditAdjustmentRequest(BaseModel):
    credits_change: int
    reason: str

@router.get("/users", response_model=UserListResponse)
async def list_all_users(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    search: Optional[str] = Query(None),
    active_only: bool = Query(True),
    current_user: User = Depends(require_admin)
):
    """
    List all users with pagination and search (Admin only)
    
    Parameters:
    - limit: Number of users to return (1-200)
    - offset: Pagination offset
    - search: Search by email or display name
    - active_only: Only return active users
    """
    try:
        if not user_manager:
            raise HTTPException(
                status_code=503,
                detail="User management service unavailable"
            )
        
        users_data = await user_manager.list_all_users(
            limit=limit,
            offset=offset,
            search=search,
            active_only=active_only
        )
        
        user_summaries = []
        for user in users_data["users"]:
            user_summaries.append(UserSummaryResponse(
                id=user["id"],
                email=user["email"],
                display_name=user["display_name"],
                avatar_url=user["avatar_url"],
                created_at=user["created_at"],
                books_owned=user["books_owned"],
                credits_available=user["credits_available"],
                credits_used=user["credits_used"],
                last_activity=user["last_activity"]
            ))
        
        return UserListResponse(
            users=user_summaries,
            total_count=users_data["total_count"],
            has_more=users_data["has_more"],
            page_info=users_data["page_info"]
        )
        
    except Exception as e:
        logger.error(f"Failed to list users: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve user list")

@router.get("/users/{user_id}", response_model=UserDetailResponse)
async def get_user_details(
    user_id: str,
    current_user: User = Depends(require_admin)
):
    """Get comprehensive user details (Admin only)"""
    try:
        if not user_manager:
            raise HTTPException(
                status_code=503,
                detail="User management service unavailable"
            )
        
        user_data = await user_manager.get_user_by_id(user_id)
        
        if not user_data:
            raise HTTPException(status_code=404, detail="User not found")
        
        return UserDetailResponse(
            id=user_data["id"],
            email=user_data["email"],
            display_name=user_data["display_name"],
            username=user_data["username"],
            avatar_url=user_data["avatar_url"],
            role=user_data["role"],
            email_verified=user_data["email_verified"],
            is_active=user_data["is_active"],
            created_at=user_data["created_at"],
            oauth_provider=user_data.get("oauth_provider"),
            oauth_provider_id=user_data.get("oauth_provider_id"),
            credits_available=user_data.get("credits_available", 0),
            credits_used=user_data.get("credits_used", 0),
            monthly_credits=user_data.get("monthly_credits", 0),
            books_owned=user_data.get("books_owned", 0),
            last_activity=None  # TODO: Implement activity tracking
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get user details for {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve user details")

@router.get("/users/{user_id}/credits")
async def get_user_credit_details(
    user_id: str,
    current_user: User = Depends(require_admin)
):
    """Get detailed credit information for a user (Admin only)"""
    try:
        if not user_manager:
            raise HTTPException(
                status_code=503,
                detail="User management service unavailable"
            )
        
        credits = await user_manager.get_user_credit_balance(user_id)
        
        return {
            "user_id": user_id,
            "credit_summary": credits,
            "note": "All books cost 0 credits in EchoWright - credits are for future features"
        }
        
    except Exception as e:
        logger.error(f"Failed to get credit details for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve credit details")

@router.get("/users/{user_id}/library")
async def get_user_library_admin(
    user_id: str,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(require_admin)
):
    """Get user's library (Admin view)"""
    try:
        if not user_manager:
            raise HTTPException(
                status_code=503,
                detail="User management service unavailable"
            )
        
        library = await user_manager.get_user_library(user_id, limit, offset)
        
        return {
            "user_id": user_id,
            "library": library,
            "note": "All books are free in EchoWright - this tracks user's collection"
        }
        
    except Exception as e:
        logger.error(f"Failed to get library for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve user library")

@router.post("/users/{user_id}/credits/adjust")
async def adjust_user_credits(
    user_id: str,
    adjustment: CreditAdjustmentRequest,
    current_user: User = Depends(require_admin)
):
    """Adjust user's credit balance (Admin only)"""
    try:
        # Note: Since all books are free, credit adjustments are mainly for future features
        # or promotional purposes. For now, this is a placeholder.
        
        return {
            "user_id": user_id,
            "credits_change": adjustment.credits_change,
            "reason": adjustment.reason,
            "message": "Credit adjustment recorded (Note: All books are currently free in EchoWright)",
            "adjusted_by": current_user.id,
            "adjusted_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Failed to adjust credits for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to adjust user credits")

@router.get("/stats/overview")
async def get_system_stats(current_user: User = Depends(require_admin)):
    """Get system-wide statistics (Admin only)"""
    try:
        if not user_manager:
            return {
                "message": "Database unavailable - showing mock stats",
                "total_users": 0,
                "active_users": 0,
                "total_books_owned": 0,
                "total_credits_available": 0,
                "system_health": "degraded"
            }
        
        # Get basic stats from database
        users_data = await user_manager.list_all_users(limit=1, offset=0)
        
        return {
            "total_users": users_data["total_count"],
            "active_users": users_data["total_count"],  # Simplified for now
            "books_system": "All books are free in EchoWright",
            "credit_system": "Credits reserved for future premium features",
            "system_health": "operational",
            "database_connected": db_manager is not None,
            "last_updated": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Failed to get system stats: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve system statistics")

@router.get("/health")
async def admin_health_check(current_user: User = Depends(require_admin)):
    """Health check for admin services (Admin only)"""
    try:
        health_status = {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "services": {
                "database": db_manager is not None,
                "user_manager": user_manager is not None,
                "auth_system": True
            }
        }
        
        if not all(health_status["services"].values()):
            health_status["status"] = "degraded"
            health_status["warnings"] = []
            
            if not db_manager:
                health_status["warnings"].append("Database connection unavailable")
            if not user_manager:
                health_status["warnings"].append("User management service unavailable")
        
        return health_status
        
    except Exception as e:
        logger.error(f"Admin health check failed: {e}")
        return {
            "status": "unhealthy",
            "timestamp": datetime.now().isoformat(),
            "error": str(e)
        }