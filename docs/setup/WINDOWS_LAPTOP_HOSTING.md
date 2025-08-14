# Windows Laptop Hosting Guide for EchoWright

This guide helps you host your EchoWright backend on a Windows laptop for initial testing and small-scale beta deployment to avoid cloud costs.

## 🖥️ Prerequisites

### Hardware Requirements
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 20GB free space minimum
- **Internet**: Stable broadband connection
- **Power**: Keep laptop plugged in and prevent sleep mode

### Software Requirements
1. **Windows 10/11** (Home or Pro)
2. **Docker Desktop for Windows**
3. **Git for Windows**
4. **PowerShell** (comes with Windows)

## 🚀 Setup Instructions

### Step 1: Install Docker Desktop
1. Download from [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/)
2. Install with WSL 2 backend (recommended)
3. Start Docker Desktop and ensure it's running

### Step 2: Clone Repository
```powershell
# Open PowerShell as Administrator
git clone https://github.com/yourusername/EchoWright.git
cd EchoWright
```

### Step 3: Configure Environment
```powershell
# Copy example environment file
cp .env.example .env

# Edit .env file with your settings
notepad .env
```

Required environment variables:
```bash
GEMINI_API_KEY=your-actual-gemini-api-key
POSTGRES_PASSWORD=your-secure-password
REDIS_PASSWORD=your-redis-password
JWT_SECRET_KEY=your-jwt-secret
ENVIRONMENT=development
```

### Step 4: Start Services
```powershell
# Start all services
docker-compose up --build -d

# Check if services are running
docker-compose ps

# View logs
docker-compose logs -f
```

### Step 5: Configure Network Access

#### Option A: Local Network Only (Safest)
Your app will only be accessible on your local network (192.168.x.x)

```powershell
# Find your local IP
ipconfig | findstr "IPv4"
# Example output: IPv4 Address. . . . . . . . . . . : 192.168.1.100
```

Your app will be accessible at:
- **API**: `http://192.168.1.100:8000`
- **Web Demo**: `http://192.168.1.100:8080`

#### Option B: Internet Access (Port Forwarding)
⚠️ **Security Warning**: Only do this for trusted testers

1. **Router Configuration**:
   - Login to your router admin panel (usually 192.168.1.1)
   - Enable port forwarding for ports 8000 and 8080
   - Forward to your laptop's local IP

2. **Windows Firewall**:
   ```powershell
   # Allow Docker through firewall
   New-NetFirewallRule -DisplayName "EchoWright API" -Direction Inbound -Port 8000 -Protocol TCP -Action Allow
   New-NetFirewallRule -DisplayName "EchoWright Web" -Direction Inbound -Port 8080 -Protocol TCP -Action Allow
   ```

3. **Find Your Public IP**:
   ```powershell
   # Get public IP
   Invoke-RestMethod -Uri "http://ipinfo.io/ip"
   ```

## 📱 Mobile App Configuration

Update your mobile app's API configuration to point to your laptop:

### For Local Network Testing
```dart
// In mobile_app/lib/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.1.100:8000'; // Your laptop's IP
  static const String wsUrl = 'ws://192.168.1.100:8000/ws';
}
```

### For Internet Access
```dart
// In mobile_app/lib/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://YOUR_PUBLIC_IP:8000';
  static const String wsUrl = 'ws://YOUR_PUBLIC_IP:8000/ws';
}
```

## 🔧 Performance Optimization

### Windows Configuration
```powershell
# Prevent sleep mode
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# Set high performance mode
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
```

### Docker Resource Limits
Edit docker-compose.yml to limit resource usage:
```yaml
version: '3.8'
services:
  api_gateway:
    # ... other config
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

## 🔒 Security Considerations

### Basic Security Setup
1. **Change Default Passwords**:
   ```bash
   POSTGRES_PASSWORD=very-secure-password-123
   REDIS_PASSWORD=another-secure-password-456
   JWT_SECRET_KEY=super-secret-jwt-key-789
   ```

2. **Limit Access**:
   - Use local network only for initial testing
   - Add IP restrictions in your router
   - Use VPN for remote access instead of port forwarding

3. **Firewall Rules**:
   ```powershell
   # Block unnecessary ports
   New-NetFirewallRule -DisplayName "Block All Inbound" -Direction Inbound -Action Block
   # Then allow only specific ports as shown above
   ```

## 📊 Monitoring and Maintenance

### Health Checking
```powershell
# Check service health
curl http://localhost:8000/health

# View resource usage
docker stats

# Check disk space
docker system df
```

### Log Management
```powershell
# View real-time logs
docker-compose logs -f

# Clean up old logs
docker system prune -f
```

### Backup Strategy
```powershell
# Backup database
docker-compose exec postgres pg_dump -U postgres echowright > backup.sql

# Backup entire data
docker-compose down
robocopy data backup_data /E
docker-compose up -d
```

## 🌐 Dynamic DNS (Optional)

If your public IP changes frequently:

1. **Sign up for Dynamic DNS**:
   - No-IP.com (free)
   - DuckDNS.org (free)
   - DynDNS.com (paid)

2. **Configure Router**:
   - Enable Dynamic DNS in router settings
   - Use your chosen provider's settings

3. **Update Mobile App**:
   ```dart
   static const String baseUrl = 'http://yourdomain.ddns.net:8000';
   ```

## 🧪 Testing Setup

### Beta User Instructions
Send your testers:

1. **Mobile App APK/IPA** with your laptop's IP configured
2. **Test Account Credentials** (if using authentication)
3. **Your Network Info**:
   ```
   API Endpoint: http://YOUR_IP:8000
   Test Account: beta@test.com / password123
   Available Hours: 9 AM - 11 PM EST (when laptop is on)
   ```

### Usage Monitoring
```powershell
# Monitor requests
docker-compose logs api_gateway | findstr "INFO"

# Check resource usage
Get-Counter "\Processor(_Total)\% Processor Time"
```

## 📈 Scaling Considerations

### When to Move to Cloud
- More than 10-20 concurrent users
- 24/7 availability needed
- Laptop becoming slow/unreliable
- Need professional SSL certificates
- Bandwidth limitations reached

### Migration Path
1. **Start**: Windows laptop (free)
2. **Growth**: VPS hosting ($5-20/month)
3. **Scale**: Cloud platforms (AWS/GCP/Azure)

## 🔧 Troubleshooting

### Common Issues

**Docker Won't Start**:
```powershell
# Restart Docker Desktop
Stop-Service "Docker Desktop Service"
Start-Service "Docker Desktop Service"
```

**Port Already in Use**:
```powershell
# Find what's using port 8000
netstat -ano | findstr ":8000"
# Kill the process
taskkill /PID <process_id> /F
```

**Out of Disk Space**:
```powershell
# Clean Docker
docker system prune -a -f
docker volume prune -f
```

**Slow Performance**:
```powershell
# Check available RAM
Get-WmiObject -Class Win32_OperatingSystem | Select TotalVisibleMemorySize,FreePhysicalMemory

# Restart services
docker-compose restart
```

## 💡 Cost Savings Comparison

| Solution | Monthly Cost | Setup Time | Concurrent Users |
|----------|--------------|------------|------------------|
| Windows Laptop | $0 + electricity | 1-2 hours | 5-20 |
| Basic VPS | $5-10 | 2-4 hours | 50-100 |
| Cloud (AWS/GCP) | $20-100+ | 4-8 hours | 100+ |

## 🎯 Beta Testing Strategy

### Phase 1: Local Network (Week 1-2)
- Family/friends on your WiFi
- Test basic functionality
- Iron out major bugs

### Phase 2: Trusted Remote Users (Week 3-4)
- 3-5 remote testers
- Port forwarding or VPN access
- Gather detailed feedback

### Phase 3: Wider Beta (Month 2)
- Consider moving to VPS
- 10-20 beta testers
- Prepare for cloud migration

---

**💡 Pro Tip**: This setup can easily handle 5-20 beta testers and costs you nothing but electricity! It's perfect for validating your product before investing in cloud infrastructure.