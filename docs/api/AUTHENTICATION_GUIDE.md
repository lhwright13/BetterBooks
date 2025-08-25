# EchoWright API Authentication Guide

## Overview
EchoWright API uses JWT-based authentication with role-based access control (RBAC) for secure access to platform resources.

**✅ Current Implementation Status:**
- **JWT Authentication**: Fully implemented with access and refresh tokens
- **Email/Password Auth**: Registration, login, and user management working
- **Mobile Integration**: Complete Flutter app integration with secure storage  
- **OAuth Stubs**: Google/Apple Sign In endpoints prepared for future implementation
- **Rate Limiting**: Per-user and per-endpoint limits implemented
- **Admin Controls**: User management and role-based access control

## Authentication Flow

### 1. User Registration
```bash
POST /auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "username": "bookworm", 
  "password": "securePassword123"
}
```

**Response:**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "user_123",
    "email": "user@example.com",
    "username": "bookworm",
    "role": "user"
  },
  "tokens": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "bearer",
    "expires_in": 1800
  }
}
```

### 2. User Login
```bash
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1800
}
```

### 3. Using Access Tokens
Include the JWT token in the Authorization header:
```bash
GET /complete
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "prompt": "Tell me about The Great Gatsby",
  "config": "default"
}
```

## Token Management

### Access Tokens
- **Lifetime**: 30 minutes
- **Purpose**: Authenticate API requests
- **Storage**: Client-side (memory preferred, not localStorage)
- **Format**: JWT with user claims

### Refresh Tokens
- **Lifetime**: 7 days
- **Purpose**: Obtain new access tokens
- **Storage**: Secure HTTP-only cookies (web) or secure storage (mobile)
- **Single Use**: Each refresh generates new access + refresh tokens

### Token Refresh
```bash
POST /auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

## JWT Token Structure

### Header
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

### Payload
```json
{
  "sub": "123e4567-e89b-12d3-a456-426614174000",
  "email": "user@example.com",
  "username": "bookworm",
  "role": "user",
  "iat": 1642089600,
  "exp": 1642093200,
  "iss": "betterbooks-api",
  "aud": "betterbooks-client"
}
```

## Role-Based Access Control

### User Roles
- **`user`**: Standard user access
- **`premium`**: Premium features access
- **`moderator`**: Content moderation capabilities
- **`admin`**: Full system access

### Role Permissions

| Endpoint | User | Premium | Moderator | Admin |
|----------|------|---------|-----------|-------|
| `POST /complete` | ✅ (limited) | ✅ (unlimited) | ✅ | ✅ |
| `POST /tts/synthesize` | ❌ | ✅ | ✅ | ✅ |
| `GET /context/search` | ✅ | ✅ | ✅ | ✅ |
| `POST /books/upload` | ❌ | ✅ | ✅ | ✅ |
| `DELETE /books/{id}` | ❌ | ❌ | ✅ | ✅ |
| `GET /admin/*` | ❌ | ❌ | ❌ | ✅ |

### Checking Permissions
Services automatically enforce permissions based on JWT claims:

```python
from core.auth.auth import require_role, UserRole

@app.post("/admin/users")
async def admin_endpoint(user: User = Depends(require_role(UserRole.ADMIN))):
    # Only admin users can access this endpoint
    return {"users": get_all_users()}
```

## Rate Limiting

### Rate Limit Tiers

| User Type | Requests/Hour | LLM Requests/Hour | TTS Requests/Hour |
|-----------|---------------|-------------------|-------------------|
| **Anonymous** | 100 | 0 | 0 |
| **User** | 1,000 | 50 | 0 |
| **Premium** | 10,000 | 500 | 100 |
| **Moderator** | 20,000 | 1,000 | 200 |
| **Admin** | Unlimited | Unlimited | Unlimited |

### Rate Limit Headers
API responses include rate limit information:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642093200
Retry-After: 3600
```

### Rate Limit Exceeded
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Try again in 3600 seconds.",
    "retry_after": 3600
  }
}
```

## Security Best Practices

### Client-Side Security
1. **Store tokens securely**:
   - Web: Use memory or sessionStorage, avoid localStorage
   - Mobile: Use keychain/keystore
   - Never log tokens

2. **Handle token expiration**:
   ```javascript
   // Auto-refresh expired tokens
   axios.interceptors.response.use(
     response => response,
     async error => {
       if (error.response?.status === 401) {
         const newToken = await refreshToken();
         error.config.headers.Authorization = `Bearer ${newToken}`;
         return axios.request(error.config);
       }
       return Promise.reject(error);
     }
   );
   ```

3. **Logout properly**:
   ```bash
   POST /auth/logout
   Authorization: Bearer <access_token>
   ```

### Server-Side Security
- Tokens are signed with HMAC-SHA256
- Refresh tokens are stored hashed in database
- Failed login attempts are rate limited
- Passwords are hashed with bcrypt

## Error Responses

### Authentication Errors
```json
{
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Invalid email or password"
  }
}
```

### Authorization Errors  
```json
{
  "error": {
    "code": "INSUFFICIENT_PERMISSIONS",
    "message": "User role 'user' does not have permission to access this resource",
    "required_role": "premium"
  }
}
```

### Token Errors
```json
{
  "error": {
    "code": "TOKEN_EXPIRED", 
    "message": "Access token has expired",
    "expires_at": "2025-01-13T11:00:00Z"
  }
}
```

## Client Examples

### Python Client
```python
import requests
import json
from datetime import datetime, timedelta

class BetterBooksClient:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        self.access_token = None
        self.refresh_token = None
        self.token_expires = None
        
    def login(self, email, password):
        response = requests.post(f"{self.base_url}/auth/login", json={
            "email": email,
            "password": password
        })
        response.raise_for_status()
        
        data = response.json()
        self.access_token = data["access_token"]
        self.refresh_token = data["refresh_token"]
        self.token_expires = datetime.now() + timedelta(seconds=data["expires_in"])
        
        return data["user"]
    
    def _ensure_valid_token(self):
        if not self.access_token or datetime.now() >= self.token_expires:
            self._refresh_access_token()
    
    def _refresh_access_token(self):
        response = requests.post(f"{self.base_url}/auth/refresh", json={
            "refresh_token": self.refresh_token
        })
        response.raise_for_status()
        
        data = response.json()
        self.access_token = data["access_token"]
        self.refresh_token = data["refresh_token"]
        self.token_expires = datetime.now() + timedelta(seconds=data["expires_in"])
    
    def complete(self, prompt, config="default"):
        self._ensure_valid_token()
        
        response = requests.post(f"{self.base_url}/complete", 
            headers={"Authorization": f"Bearer {self.access_token}"},
            json={"prompt": prompt, "config": config}
        )
        response.raise_for_status()
        return response.json()

# Usage
client = BetterBooksClient()
user = client.login("user@example.com", "password")
result = client.complete("Tell me about The Great Gatsby")
```

### JavaScript Client
```javascript
class BetterBooksClient {
    constructor(baseUrl = 'http://localhost:8000') {
        this.baseUrl = baseUrl;
        this.accessToken = null;
        this.refreshToken = null;
        this.tokenExpires = null;
    }
    
    async login(email, password) {
        const response = await fetch(`${this.baseUrl}/auth/login`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({email, password})
        });
        
        if (!response.ok) {
            throw new Error(`Login failed: ${response.status}`);
        }
        
        const data = await response.json();
        this.accessToken = data.access_token;
        this.refreshToken = data.refresh_token;
        this.tokenExpires = new Date(Date.now() + data.expires_in * 1000);
        
        return data.user;
    }
    
    async ensureValidToken() {
        if (!this.accessToken || new Date() >= this.tokenExpires) {
            await this.refreshAccessToken();
        }
    }
    
    async refreshAccessToken() {
        const response = await fetch(`${this.baseUrl}/auth/refresh`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({refresh_token: this.refreshToken})
        });
        
        if (!response.ok) {
            throw new Error('Token refresh failed');
        }
        
        const data = await response.json();
        this.accessToken = data.access_token;
        this.refreshToken = data.refresh_token;
        this.tokenExpires = new Date(Date.now() + data.expires_in * 1000);
    }
    
    async complete(prompt, config = 'default') {
        await this.ensureValidToken();
        
        const response = await fetch(`${this.baseUrl}/complete`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.accessToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({prompt, config})
        });
        
        if (!response.ok) {
            throw new Error(`API call failed: ${response.status}`);
        }
        
        return response.json();
    }
}

// Usage
const client = new BetterBooksClient();
await client.login('user@example.com', 'password');
const result = await client.complete('Tell me about The Great Gatsby');
```

### Flutter/Dart Client
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class BetterBooksClient {
  final String baseUrl;
  String? accessToken;
  String? refreshToken;
  DateTime? tokenExpires;
  
  BetterBooksClient({this.baseUrl = 'http://localhost:8000'});
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Login failed: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    accessToken = data['access_token'];
    refreshToken = data['refresh_token'];
    tokenExpires = DateTime.now().add(Duration(seconds: data['expires_in']));
    
    return data['user'];
  }
  
  Future<void> _ensureValidToken() async {
    if (accessToken == null || DateTime.now().isAfter(tokenExpires!)) {
      await _refreshAccessToken();
    }
  }
  
  Future<void> _refreshAccessToken() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Token refresh failed');
    }
    
    final data = jsonDecode(response.body);
    accessToken = data['access_token'];
    refreshToken = data['refresh_token'];
    tokenExpires = DateTime.now().add(Duration(seconds: data['expires_in']));
  }
  
  Future<Map<String, dynamic>> complete(String prompt, {String config = 'default'}) async {
    await _ensureValidToken();
    
    final response = await http.post(
      Uri.parse('$baseUrl/complete'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'prompt': prompt, 'config': config}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('API call failed: ${response.statusCode}');
    }
    
    return jsonDecode(response.body);
  }
}

// Usage
final client = BetterBooksClient();
await client.login('user@example.com', 'password');
final result = await client.complete('Tell me about The Great Gatsby');
```

## Testing Authentication

### Unit Tests
Test authentication components in isolation:
```python
def test_jwt_token_creation():
    user = User(id="123", email="test@example.com", role="user")
    token = create_access_token(user)
    decoded = decode_access_token(token)
    assert decoded["sub"] == "123"
    assert decoded["role"] == "user"

def test_role_based_access():
    admin_user = User(role="admin")
    user = User(role="user")
    
    assert check_permission(admin_user, "admin_endpoint") == True
    assert check_permission(user, "admin_endpoint") == False
```

### Integration Tests
Test complete authentication flows:
```python
def test_login_flow(client):
    # Register user
    response = client.post("/auth/register", json={
        "email": "test@example.com",
        "password": "password123"
    })
    assert response.status_code == 201
    
    # Login
    response = client.post("/auth/login", json={
        "email": "test@example.com", 
        "password": "password123"
    })
    assert response.status_code == 200
    token = response.json()["access_token"]
    
    # Use token
    response = client.get("/profile", headers={
        "Authorization": f"Bearer {token}"
    })
    assert response.status_code == 200
```

## Related Documents
- [API Versioning Strategy](API_VERSIONING_STRATEGY.md)
- [Rate Limiting Implementation](../../core/auth/auth.py)
- [Security Setup Guide](../setup/SECURITY_SETUP.md)
- [Client SDK Documentation](../clients/)