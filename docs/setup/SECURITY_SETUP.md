# EchoWright Security Setup Guide

## 🔐 Environment Configuration

### Step 1: Create Your Environment File

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your actual values:**
   ```bash
   nano .env
   ```

### Step 2: Required API Keys

#### Google Gemini API Key (Required)
```bash
GEMINI_API_KEY=your-actual-gemini-api-key-here
```

**How to get it:**
1. Go to [Google AI Studio](https://makersuite.google.com/)
2. Create a new API key
3. Copy and paste into your `.env` file

#### JWT Secret Key (Required)
```bash
JWT_SECRET_KEY=your-super-secret-jwt-key-change-this-in-production-min-32-chars
```

**Generate a secure key:**
```bash
# Option 1: Use openssl
openssl rand -hex 32

# Option 2: Use Python
python3 -c "import secrets; print(secrets.token_hex(32))"
```

#### Database Password (Required)
```bash
POSTGRES_PASSWORD=your-secure-database-password-here
```

**Generate a secure password:**
```bash
# Use openssl to generate a strong password
openssl rand -base64 32
```

### Step 3: Optional Enhanced Features

#### OpenAI API Key (Optional - for advanced features)
```bash
OPENAI_API_KEY=your-openai-api-key-here-optional
```

#### ElevenLabs API Key (Optional - for advanced voice synthesis)
```bash
ELEVENLABS_API_KEY=your-elevenlabs-api-key-here-optional
```

#### AssemblyAI API Key (Optional - for advanced speech recognition)
```bash
ASSEMBLYAI_API_KEY=your-assemblyai-api-key-here-optional
```

## 🚨 Security Best Practices

### Environment Files
- **Never commit `.env` files to version control**
- Keep `.env.example` updated but without real values
- Use different `.env` files for different environments

### API Keys
- **Rotate API keys regularly** (monthly for production)
- **Use least-privilege access** where possible
- **Monitor API usage** for unusual activity
- **Store production keys in secure key management**

### Database Security
- **Use strong, unique passwords**
- **Enable SSL/TLS connections in production**
- **Regular backups with encryption**
- **Network isolation in production**

### JWT Tokens
- **Use cryptographically secure random keys**
- **Minimum 32 characters length**
- **Different keys for different environments**
- **Regular key rotation in production**

## 🔧 Service-Specific Configuration

### For API Gateway
```bash
# Rate limiting
RATE_LIMIT_REQUESTS_PER_MINUTE=60
RATE_LIMIT_BURST=10

# CORS (restrict in production)
CORS_ORIGINS=http://localhost:8080,http://localhost:3000
```

### For LLM Gateway
```bash
# Model configuration
DEFAULT_LLM_MODEL=gemini-pro
MAX_CONTEXT_TOKENS=4000
LLM_TEMPERATURE=0.7

# Safety settings
ENABLE_CONTENT_FILTERING=true
SAFETY_THRESHOLD=BLOCK_MEDIUM_AND_ABOVE
```

### For Context Service
```bash
# Database optimization
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=10

# Vector search optimization
VECTOR_DIMENSION=768
VECTOR_INDEX_TYPE=hnsw
```

## 🚀 Quick Start

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Add your Gemini API key to `.env`:**
   ```bash
   GEMINI_API_KEY=your-actual-api-key-here
   ```

3. **Generate JWT secret:**
   ```bash
   echo "JWT_SECRET_KEY=$(openssl rand -hex 32)" >> .env
   ```

4. **Set secure database password:**
   ```bash
   echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)" >> .env
   ```

5. **Start the platform:**
   ```bash
   docker-compose up --build
   ```

## ⚠️ Production Deployment

For production deployment, additional security measures are required:

- Use external secret management (AWS Secrets Manager, HashiCorp Vault)
- Enable SSL/TLS everywhere
- Implement proper network segmentation
- Set up monitoring and alerting
- Regular security audits and penetration testing
- WAF (Web Application Firewall) protection
- Rate limiting and DDoS protection

## 🛠 Troubleshooting

### Common Issues

1. **"Missing required environment variable"**
   - Check that your `.env` file has all required variables
   - Ensure no spaces around the `=` sign in `.env`

2. **"Invalid API key"**
   - Verify your API keys are correct
   - Check API key permissions and quotas

3. **Database connection errors**
   - Ensure PostgreSQL is running
   - Check database URL format
   - Verify database credentials

### Debug Mode

Enable debug logging by setting:
```bash
DEBUG=true
LOG_LEVEL=DEBUG
```

## 📞 Need Help?

- Check the [main README](README.md) for general setup
- Review [CUSTOMIZATION_GUIDE.md](docs/CUSTOMIZATION_GUIDE.md) for advanced configuration
- Create an issue in the repository for specific problems