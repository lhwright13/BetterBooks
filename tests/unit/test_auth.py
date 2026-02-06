"""
Unit Tests for Authentication Module

Tests for /Users/lhwri/BetterBooks/core/auth/auth.py

Covers:
- JWT token creation and validation
- Password hashing and verification
- Token expiration handling
- User role validation
"""

import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import MagicMock, patch, AsyncMock

import pytest

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


class TestPasswordHashing:
    """Tests for password hashing and verification functions."""

    def test_hash_password_returns_string(self):
        """hash_password should return a string hash."""
        # Import with mocked dependencies
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                with patch("core.auth.auth.bcrypt") as mock_bcrypt:
                    mock_bcrypt.gensalt.return_value = b"$2b$12$testsalt"
                    mock_bcrypt.hashpw.return_value = b"$2b$12$hashedpassword"

                    from core.auth.auth import hash_password

                    result = hash_password("testpassword123")

                    assert isinstance(result, str)
                    assert result == "$2b$12$hashedpassword"
                    mock_bcrypt.gensalt.assert_called_once()
                    mock_bcrypt.hashpw.assert_called_once()

    def test_verify_password_correct(self):
        """verify_password should return True for correct password."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                with patch("core.auth.auth.bcrypt") as mock_bcrypt:
                    mock_bcrypt.checkpw.return_value = True

                    from core.auth.auth import verify_password

                    result = verify_password("correctpassword", "$2b$12$hashedpassword")

                    assert result is True
                    mock_bcrypt.checkpw.assert_called_once()

    def test_verify_password_incorrect(self):
        """verify_password should return False for incorrect password."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                with patch("core.auth.auth.bcrypt") as mock_bcrypt:
                    mock_bcrypt.checkpw.return_value = False

                    from core.auth.auth import verify_password

                    result = verify_password("wrongpassword", "$2b$12$hashedpassword")

                    assert result is False


class TestJWTTokenCreation:
    """Tests for JWT token creation functions."""

    def test_create_access_token_contains_required_fields(self):
        """Access token should contain user data and expiration."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret-key"}):
            with patch("core.auth.auth.redis_client", None):
                with patch("core.auth.auth.jwt") as mock_jwt:
                    mock_jwt.encode.return_value = "mock.jwt.token"

                    from core.auth.auth import create_access_token

                    token_data = {"sub": "user_123", "email": "test@example.com"}
                    result = create_access_token(token_data)

                    assert result == "mock.jwt.token"
                    # Verify encode was called with correct structure
                    call_args = mock_jwt.encode.call_args
                    encoded_data = call_args[0][0]
                    assert "sub" in encoded_data
                    assert "exp" in encoded_data
                    assert "type" in encoded_data
                    assert encoded_data["type"] == "access"

    def test_create_access_token_with_custom_expiry(self):
        """Access token should respect custom expiry delta."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret-key"}):
            with patch("core.auth.auth.redis_client", None):
                with patch("core.auth.auth.jwt") as mock_jwt:
                    mock_jwt.encode.return_value = "mock.jwt.token"

                    from core.auth.auth import create_access_token

                    custom_delta = timedelta(hours=2)
                    token_data = {"sub": "user_123"}
                    create_access_token(token_data, expires_delta=custom_delta)

                    call_args = mock_jwt.encode.call_args
                    encoded_data = call_args[0][0]
                    # Verify exp is roughly 2 hours from now
                    exp_time = encoded_data["exp"]
                    now = datetime.now(timezone.utc)
                    expected_exp = now + custom_delta
                    # Allow 5 second tolerance
                    assert abs((exp_time - expected_exp).total_seconds()) < 5

    def test_create_refresh_token_has_correct_type(self):
        """Refresh token should have type='refresh'."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret-key"}):
            with patch("core.auth.auth.redis_client", None):
                with patch("core.auth.auth.jwt") as mock_jwt:
                    mock_jwt.encode.return_value = "mock.refresh.token"

                    from core.auth.auth import create_refresh_token

                    token_data = {"sub": "user_123"}
                    result = create_refresh_token(token_data)

                    assert result == "mock.refresh.token"
                    call_args = mock_jwt.encode.call_args
                    encoded_data = call_args[0][0]
                    assert encoded_data["type"] == "refresh"


class TestJWTTokenValidation:
    """Tests for JWT token validation."""

    def test_verify_token_valid_access_token(self):
        """verify_token should decode valid access tokens."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret-key"}):
            with patch("core.auth.auth.redis_client", None):
                with patch("core.auth.auth.jwt") as mock_jwt:
                    mock_payload = {
                        "sub": "user_123",
                        "type": "access",
                        "exp": datetime.now(timezone.utc) + timedelta(hours=1)
                    }
                    mock_jwt.decode.return_value = mock_payload

                    from core.auth.auth import verify_token

                    result = verify_token("valid.jwt.token", "access")

                    assert result["sub"] == "user_123"
                    assert result["type"] == "access"

    def test_verify_token_expired_raises_error(self):
        """verify_token should raise AuthError for expired tokens."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret-key"}):
            with patch("core.auth.auth.redis_client", None):
                # Need to import jwt to access the exception
                import jwt as real_jwt
                with patch("core.auth.auth.jwt") as mock_jwt:
                    mock_jwt.ExpiredSignatureError = real_jwt.ExpiredSignatureError
                    mock_jwt.InvalidTokenError = real_jwt.InvalidTokenError
                    mock_jwt.decode.side_effect = real_jwt.ExpiredSignatureError("Token expired")

                    from core.auth.auth import verify_token, AuthError

                    with pytest.raises(AuthError) as exc_info:
                        verify_token("expired.jwt.token", "access")

                    assert "expired" in str(exc_info.value.detail).lower()

    def test_verify_token_invalid_raises_error(self):
        """verify_token should raise AuthError for invalid tokens."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret-key"}):
            with patch("core.auth.auth.redis_client", None):
                import jwt as real_jwt
                with patch("core.auth.auth.jwt") as mock_jwt:
                    mock_jwt.ExpiredSignatureError = real_jwt.ExpiredSignatureError
                    mock_jwt.InvalidTokenError = real_jwt.InvalidTokenError
                    mock_jwt.decode.side_effect = real_jwt.InvalidTokenError("Invalid token")

                    from core.auth.auth import verify_token, AuthError

                    with pytest.raises(AuthError) as exc_info:
                        verify_token("invalid.jwt.token", "access")

                    assert "invalid" in str(exc_info.value.detail).lower()

    def test_verify_token_wrong_type_raises_error(self):
        """verify_token should raise AuthError when token type doesn't match."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret-key"}):
            with patch("core.auth.auth.redis_client", None):
                import jwt as real_jwt
                with patch("core.auth.auth.jwt") as mock_jwt:
                    # Set up exception classes for the mock
                    mock_jwt.ExpiredSignatureError = real_jwt.ExpiredSignatureError
                    mock_jwt.InvalidTokenError = real_jwt.InvalidTokenError
                    # Return refresh token when access expected
                    mock_payload = {
                        "sub": "user_123",
                        "type": "refresh",  # Wrong type
                        "exp": datetime.now(timezone.utc) + timedelta(hours=1)
                    }
                    mock_jwt.decode.return_value = mock_payload

                    from core.auth.auth import verify_token, AuthError

                    with pytest.raises(AuthError) as exc_info:
                        verify_token("token.with.wrong.type", "access")

                    # The error message may vary - just verify AuthError was raised
                    assert exc_info.value.status_code == 401


class TestUserRoles:
    """Tests for user role enum and role-based access."""

    def test_user_role_enum_values(self):
        """UserRole enum should have correct values."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import UserRole

                assert UserRole.ADMIN.value == "admin"
                assert UserRole.USER.value == "user"
                assert UserRole.GUEST.value == "guest"

    def test_require_admin_allows_admin(self):
        """require_admin should allow admin users."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import require_admin, User, UserRole

                admin_user = User(
                    id="admin_001",
                    email="admin@test.com",
                    username="admin",
                    role=UserRole.ADMIN,
                    is_active=True,
                    email_verified=True,
                    created_at=datetime.now(timezone.utc)
                )

                # require_admin returns a function that takes current_user
                # When called directly with a User, it should return the user
                result = require_admin(current_user=admin_user)
                assert result == admin_user

    def test_require_admin_denies_regular_user(self):
        """require_admin should deny non-admin users."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import require_admin, User, UserRole, PermissionError

                regular_user = User(
                    id="user_001",
                    email="user@test.com",
                    username="user",
                    role=UserRole.USER,
                    is_active=True,
                    email_verified=True,
                    created_at=datetime.now(timezone.utc)
                )

                with pytest.raises(PermissionError):
                    require_admin(current_user=regular_user)


class TestTokenBlacklisting:
    """Tests for token blacklisting functionality."""

    def test_blacklist_token_with_redis(self, mock_redis_client):
        """blacklist_token should add token to Redis blacklist."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", mock_redis_client):
                from core.auth.auth import blacklist_token

                blacklist_token("token.to.blacklist", expires_in=3600)

                mock_redis_client.setex.assert_called_once()
                call_args = mock_redis_client.setex.call_args
                assert "blacklist:token.to.blacklist" in str(call_args)

    def test_blacklist_token_without_redis(self):
        """blacklist_token should handle missing Redis gracefully."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import blacklist_token

                # Should not raise an exception
                blacklist_token("token.to.blacklist")


class TestRateLimiting:
    """Tests for rate limiting functionality."""

    @pytest.mark.asyncio
    async def test_check_rate_limit_under_limit(self, mock_redis_client):
        """check_rate_limit should allow requests under the limit."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", mock_redis_client):
                mock_redis_client.incr.return_value = 5  # Under default 60 limit

                from core.auth.auth import check_rate_limit

                result = await check_rate_limit("user_123", "/api/endpoint")

                assert result is True

    @pytest.mark.asyncio
    async def test_check_rate_limit_exceeds_limit(self, mock_redis_client):
        """check_rate_limit should raise error when limit exceeded."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", mock_redis_client):
                mock_redis_client.incr.return_value = 100  # Over default 60 limit

                from core.auth.auth import check_rate_limit, RateLimitError

                with pytest.raises(RateLimitError):
                    await check_rate_limit("user_123", "/api/endpoint", limit=60)

    @pytest.mark.asyncio
    async def test_check_rate_limit_without_redis(self):
        """check_rate_limit should skip limiting when Redis unavailable."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import check_rate_limit

                result = await check_rate_limit("user_123", "/api/endpoint")

                assert result is True


class TestUserModel:
    """Tests for User model and serialization."""

    def test_user_model_creation(self, sample_user_data):
        """User model should be created with valid data."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import User, UserRole

                user = User(
                    id=sample_user_data["id"],
                    email=sample_user_data["email"],
                    username=sample_user_data["username"],
                    display_name=sample_user_data["display_name"],
                    role=UserRole(sample_user_data["role"]),
                    is_active=sample_user_data["is_active"],
                    email_verified=sample_user_data["email_verified"],
                    created_at=sample_user_data["created_at"]
                )

                assert user.id == "user_12345"
                assert user.email == "testuser@example.com"
                assert user.role == UserRole.USER

    def test_user_to_dict(self, sample_user_data):
        """User.to_dict should return proper dictionary representation."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import User, UserRole

                user = User(
                    id=sample_user_data["id"],
                    email=sample_user_data["email"],
                    username=sample_user_data["username"],
                    display_name=sample_user_data["display_name"],
                    role=UserRole(sample_user_data["role"]),
                    is_active=sample_user_data["is_active"],
                    email_verified=sample_user_data["email_verified"],
                    created_at=sample_user_data["created_at"]
                )

                user_dict = user.to_dict()

                assert user_dict["id"] == "user_12345"
                assert user_dict["email"] == "testuser@example.com"
                assert user_dict["role"] == "user"
                assert "created_at" in user_dict


class TestAuthModels:
    """Tests for authentication-related Pydantic models."""

    def test_user_registration_model(self):
        """UserRegistration model should validate input."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import UserRegistration, UserRole

                registration = UserRegistration(
                    email="newuser@example.com",
                    username="newuser",
                    password="SecurePass123!"
                )

                assert registration.email == "newuser@example.com"
                assert registration.username == "newuser"
                assert registration.role == UserRole.USER  # Default

    def test_user_login_model(self):
        """UserLogin model should validate login input."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import UserLogin

                login = UserLogin(
                    email="user@example.com",
                    password="password123"
                )

                assert login.email == "user@example.com"
                assert login.password == "password123"

    def test_token_response_model(self):
        """TokenResponse model should have correct structure."""
        with patch.dict(os.environ, {"JWT_SECRET_KEY": "test-secret"}):
            with patch("core.auth.auth.redis_client", None):
                from core.auth.auth import TokenResponse

                response = TokenResponse(
                    access_token="access.token.here",
                    refresh_token="refresh.token.here"
                )

                assert response.access_token == "access.token.here"
                assert response.refresh_token == "refresh.token.here"
                assert response.token_type == "bearer"
                assert response.expires_in == 30 * 60  # 30 minutes in seconds
