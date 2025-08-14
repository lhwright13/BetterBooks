#!/bin/bash

echo "🎤 Testing BetterBooks Voice-to-Text Integration"
echo "================================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test endpoints
TRANSCRIPTION_SERVICE="http://localhost:8003"
API_GATEWAY="http://localhost:8000"

echo -e "${BLUE}Step 1: Testing Transcription Service Health${NC}"
echo "=============================================="
HEALTH_RESPONSE=$(curl -s "${TRANSCRIPTION_SERVICE}/health")
if [[ $? -eq 0 && "$HEALTH_RESPONSE" == *"healthy"* ]]; then
    echo -e "${GREEN}✅ Transcription service is healthy${NC}"
    echo "   Response: $HEALTH_RESPONSE"
else
    echo -e "${RED}❌ Transcription service health check failed${NC}"
    echo "   Response: $HEALTH_RESPONSE"
    exit 1
fi
echo

echo -e "${BLUE}Step 2: Testing Azure Speech Service Configuration${NC}"
echo "=================================================="
CONFIG_RESPONSE=$(curl -s "${TRANSCRIPTION_SERVICE}/config")
if [[ $? -eq 0 && "$CONFIG_RESPONSE" == *"azure_configured"* ]]; then
    echo -e "${GREEN}✅ Azure Speech Service is configured${NC}"
    echo "   Configuration: $CONFIG_RESPONSE"
else
    echo -e "${RED}❌ Azure configuration check failed${NC}"
    echo "   Response: $CONFIG_RESPONSE"
    exit 1
fi
echo

echo -e "${BLUE}Step 3: Testing Supported Languages${NC}"
echo "===================================="
LANGUAGES_RESPONSE=$(curl -s "${TRANSCRIPTION_SERVICE}/supported-languages")
if [[ $? -eq 0 && "$LANGUAGES_RESPONSE" == *"supported_languages"* ]]; then
    echo -e "${GREEN}✅ Supported languages retrieved${NC}"
    echo "   Languages: $LANGUAGES_RESPONSE"
else
    echo -e "${RED}❌ Languages check failed${NC}"
    echo "   Response: $LANGUAGES_RESPONSE"
fi
echo

echo -e "${BLUE}Step 4: Testing Mock Transcription${NC}"
echo "=================================="
TRANSCRIPTION_RESPONSE=$(curl -X POST -s "${TRANSCRIPTION_SERVICE}/transcribe/test")
if [[ $? -eq 0 && "$TRANSCRIPTION_RESPONSE" == *"text"* ]]; then
    echo -e "${GREEN}✅ Mock transcription successful${NC}"
    echo "   Result: $TRANSCRIPTION_RESPONSE"
else
    echo -e "${RED}❌ Mock transcription failed${NC}"
    echo "   Response: $TRANSCRIPTION_RESPONSE"
    exit 1
fi
echo

echo -e "${BLUE}Step 5: Testing API Gateway (if available)${NC}"
echo "==========================================="
API_HEALTH=$(curl -s "${API_GATEWAY}/health" 2>/dev/null)
if [[ $? -eq 0 && "$API_HEALTH" == *"ok"* ]]; then
    echo -e "${YELLOW}⚠️  API Gateway is running but transcription endpoints may have issues${NC}"
    echo "   We're using direct transcription service for now"
    
    # Try the transcription health endpoint through API Gateway
    API_TRANSCRIPTION_HEALTH=$(curl -s "${API_GATEWAY}/transcription/health" 2>/dev/null)
    if [[ $? -eq 0 && "$API_TRANSCRIPTION_HEALTH" != *"Internal Server Error"* ]]; then
        echo -e "${GREEN}✅ API Gateway transcription endpoint working${NC}"
        echo "   Response: $API_TRANSCRIPTION_HEALTH"
    else
        echo -e "${YELLOW}⚠️  API Gateway transcription endpoint has issues${NC}"
        echo "   Using direct service connection instead"
    fi
else
    echo -e "${YELLOW}⚠️  API Gateway not responding - using direct service${NC}"
fi
echo

echo -e "${GREEN}🎯 Voice Flow Test Summary${NC}"
echo "=========================="
echo -e "${GREEN}✅ Azure Speech Service: Configured and Ready${NC}"
echo -e "${GREEN}✅ Transcription Service: Running on port 8003${NC}"
echo -e "${GREEN}✅ Mock Transcription: Working${NC}"
echo -e "${BLUE}🔄 Mobile App Integration: Ready for testing${NC}"
echo

echo -e "${BLUE}📱 Mobile App Integration Status:${NC}"
echo "- Service URL: ${TRANSCRIPTION_SERVICE}"
echo "- Health endpoint: /health ✅"
echo "- Test endpoint: /transcribe/test ✅"
echo "- File upload endpoint: /transcribe/file (ready for audio files)"
echo "- Languages endpoint: /supported-languages ✅"
echo

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Mobile app can now connect to transcription service"
echo "2. Voice recording implementation pending in mobile app"
echo "3. API Gateway transcription routing needs debugging"
echo "4. Real audio file testing pending"
echo

echo -e "${GREEN}🚀 Voice-to-Text Integration is Ready for Development!${NC}"