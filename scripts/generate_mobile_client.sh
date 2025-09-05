#!/bin/bash

# Script to generate Dart/Flutter API client from OpenAPI specification
# This automates the process of keeping the mobile app in sync with backend API changes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
OPENAPI_SPEC="docs/api/openapi_v1.1.yaml"
MOBILE_APP_DIR="platform/mobile/mobile_app"
GENERATED_API_DIR="$MOBILE_APP_DIR/lib/api/generated"
OPENAPI_GENERATOR_VERSION="6.6.0"

echo -e "${GREEN}🚀 EchoWright Mobile Client Generator${NC}"
echo "=================================================="

# Check if OpenAPI spec exists
if [ ! -f "$OPENAPI_SPEC" ]; then
    echo -e "${RED}❌ OpenAPI spec not found: $OPENAPI_SPEC${NC}"
    echo "Please run: curl http://128.203.92.141:8000/openapi.json > docs/api/openapi.json"
    exit 1
fi

echo -e "${YELLOW}📝 Using OpenAPI spec: $OPENAPI_SPEC${NC}"

# Check if mobile app directory exists
if [ ! -d "$MOBILE_APP_DIR" ]; then
    echo -e "${RED}❌ Mobile app directory not found: $MOBILE_APP_DIR${NC}"
    exit 1
fi

# Check for OpenAPI Generator
OPENAPI_CMD=""
if command -v openapi-generator &> /dev/null; then
    OPENAPI_CMD="openapi-generator"
elif command -v openapi-generator-cli &> /dev/null; then
    OPENAPI_CMD="openapi-generator-cli"
elif command -v npx &> /dev/null && npx openapi-generator-cli version &> /dev/null; then
    OPENAPI_CMD="npx openapi-generator-cli"
fi

if [ -z "$OPENAPI_CMD" ]; then
    echo -e "${YELLOW}📦 Installing OpenAPI Generator...${NC}"
    if command -v npm &> /dev/null; then
        npm install -g @openapitools/openapi-generator-cli
    elif command -v brew &> /dev/null; then
        brew install openapi-generator
    else
        echo -e "${RED}❌ Please install OpenAPI Generator:${NC}"
        echo "  npm install -g @openapitools/openapi-generator-cli"
        echo "  or"
        echo "  brew install openapi-generator"
        exit 1
    fi
fi

echo -e "${GREEN}✅ OpenAPI Generator found${NC}"

# Create output directory
mkdir -p "$GENERATED_API_DIR"

# Generate Dart client
echo -e "${YELLOW}🔨 Generating Dart API client...${NC}"

$OPENAPI_CMD generate \
    -i "$OPENAPI_SPEC" \
    -g dart \
    -o "$GENERATED_API_DIR" \
    --additional-properties=\
packageName=echowright_api,\
pubName=echowright_api,\
pubVersion=1.0.0,\
pubDescription="Generated API client for EchoWright audiobook platform",\
pubAuthor="EchoWright",\
pubHomepage="https://echowright.com",\
dateLibrary=core,\
nullableFields=true,\
wrapper=none \
    --type-mappings=DateTime=DateTime \
    --import-mappings=DateTime=dart:core \
    --skip-validate-spec

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Dart client generated successfully${NC}"
else
    echo -e "${RED}❌ Failed to generate Dart client${NC}"
    exit 1
fi

# Create a wrapper API service that integrates with existing mobile app patterns
echo -e "${YELLOW}🔧 Creating API service wrapper...${NC}"

cat > "$MOBILE_APP_DIR/lib/api/api_client.dart" << 'EOF'
/// Generated API Client for EchoWright
/// This file integrates the generated OpenAPI client with the existing mobile app architecture
/// 
/// Usage:
/// ```dart
/// final apiClient = ApiClient();
/// final books = await apiClient.searchBooks(query: "gatsby");
/// ```

import 'dart:io';
import 'package:http/http.dart' as http;
import 'generated/lib/api.dart';
import '../services/auth_service.dart';

class ApiClient {
  static const String _baseUrl = 'http://128.203.92.141:8000';
  static const String _devUrl = 'http://localhost:8000';
  
  late final DefaultApi _api;
  late final ApiClient _apiClient;
  
  ApiClient({String? baseUrl}) {
    final url = baseUrl ?? _baseUrl;
    _apiClient = ApiClient(basePath: url);
    _api = DefaultApi(_apiClient);
  }
  
  /// Get authentication headers with current JWT token
  Future<Map<String, String>> _getAuthHeaders() async {
    final accessToken = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }
  
  // Auth endpoints
  Future<AuthResponse> signUp({
    required String email, 
    required String password,
    String? displayName,
  }) async {
    final request = EmailSignUpRequest(
      email: email,
      password: password,
      displayName: displayName,
    );
    return await _api.emailSignUpAuthSignupPost(request);
  }
  
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final request = EmailSignInRequest(email: email, password: password);
    return await _api.emailSignInAuthSigninPost(request);
  }
  
  Future<AuthResponse> refreshToken(String refreshToken) async {
    final request = RefreshTokenRequest(refreshToken: refreshToken);
    return await _api.refreshTokenEndpointAuthRefreshPost(request);
  }
  
  Future<Map<String, dynamic>> getCurrentUser() async {
    return await _api.getCurrentUserInfoAuthMeGet();
  }
  
  Future<void> logout() async {
    await _api.logoutAuthLogoutPost();
  }
  
  // Bookstore endpoints
  Future<BrowseResponse> browseBooks({
    bool featured = false,
    bool bestsellers = false,
    bool newReleases = false,
    int page = 1,
    int limit = 20,
  }) async {
    return await _api.browseBooksBookstoreBrowseGet(
      featured: featured,
      bestsellers: bestsellers,
      newReleases: newReleases,
      page: page,
      limit: limit,
    );
  }
  
  Future<BrowseResponse> searchBooks({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    return await _api.searchBooksBookstoreSearchGet(
      q: query,
      page: page,
      limit: limit,
    );
  }
  
  Future<BrowseResponse> getFeaturedBooks({int limit = 10}) async {
    return await _api.getFeaturedBooksBookstoreFeaturedGet(limit: limit);
  }
  
  Future<BrowseResponse> getBestsellingBooks({int limit = 10}) async {
    return await _api.getBestsellingBooksBookstoreBestsellersGet(limit: limit);
  }
  
  Future<DetailedBook> getBookDetails(String bookId) async {
    return await _api.getBookDetailsBookstoreBooksBookIdGet(bookId);
  }
  
  Future<CreditBalanceResponse> getUserCredits() async {
    return await _api.getUserCreditsBookstoreUserCreditsGet();
  }
  
  Future<UserLibraryResponse> getUserLibrary() async {
    return await _api.getUserLibraryBookstoreUserLibraryGet();
  }
  
  Future<PurchaseResponse> purchaseBook({
    required String bookId,
    int creditsToUse = 1,
  }) async {
    final request = PurchaseRequest(
      bookId: bookId, 
      creditsToUse: creditsToUse,
    );
    return await _api.purchaseBookBookstorePurchasePost(request);
  }
  
  Future<CreditBalanceResponse> initializeUserCredits({int initialCredits = 5}) async {
    return await _api.initializeUserCreditsBookstoreUserInitializeCreditsPost(
      initialCredits: initialCredits,
    );
  }
  
  // AI/Chat endpoints  
  Future<dynamic> completeText({
    required String prompt,
    String? config,
    int? maxTokens,
    double? temperature,
  }) async {
    final request = CompletionRequest(
      prompt: prompt,
      config: config,
      maxTokens: maxTokens,
      temperature: temperature,
    );
    return await _api.completeTextCompletePost(request);
  }
  
  Future<HttpResponse> textToSpeech({
    required String text,
    String? voice,
    double? speed,
  }) async {
    final request = TTSRequest(
      text: text,
      voice: voice, 
      speed: speed,
    );
    return await _api.textToSpeechTtsPost(request);
  }
  
  // Personas
  Future<BookPersonasResponse> getBookPersonas(String bookId) async {
    return await _api.getBookPersonasEndpointBookstoreBooksBookIdPersonasGet(bookId);
  }
  
  Future<PersonaResponse> getPersona(String personaId) async {
    return await _api.getPersonaEndpointPersonasPersonaIdGet(personaId);
  }
  
  Future<dynamic> listPersonas() async {
    return await _api.listPersonasEndpointPersonasGet();
  }
}

/// Exception wrapper for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;
  
  ApiException(this.message, {this.statusCode, this.response});
  
  @override
  String toString() => 'ApiException: $message ${statusCode != null ? '(HTTP $statusCode)' : ''}';
}
EOF

echo -e "${GREEN}✅ API service wrapper created${NC}"

# Update pubspec.yaml to include generated dependencies
echo -e "${YELLOW}📋 Updating pubspec.yaml dependencies...${NC}"

# Check if the generated client has its own pubspec
if [ -f "$GENERATED_API_DIR/pubspec.yaml" ]; then
    echo -e "${YELLOW}📦 Generated client dependencies found${NC}"
    
    # Extract dependencies from generated client
    generated_deps=$(grep -A 20 "dependencies:" "$GENERATED_API_DIR/pubspec.yaml" | grep "^  " | grep -v "^  sdk:" || true)
    
    if [ ! -z "$generated_deps" ]; then
        echo "Generated dependencies to add to main pubspec.yaml:"
        echo "$generated_deps"
        echo ""
        echo -e "${YELLOW}⚠️  Please manually add these dependencies to $MOBILE_APP_DIR/pubspec.yaml${NC}"
    fi
fi

# Create a simple test file
echo -e "${YELLOW}🧪 Creating API client test...${NC}"

cat > "$MOBILE_APP_DIR/test/api_client_test.dart" << 'EOF'
import 'package:flutter_test/flutter_test.dart';
import '../lib/api/api_client.dart';

void main() {
  group('ApiClient', () {
    late ApiClient apiClient;
    
    setUp(() {
      // Use development server for testing
      apiClient = ApiClient(baseUrl: 'http://localhost:8000');
    });
    
    test('should create API client instance', () {
      expect(apiClient, isNotNull);
    });
    
    // Add more tests as needed
    // test('should fetch featured books', () async {
    //   final response = await apiClient.getFeaturedBooks();
    //   expect(response.books, isNotNull);
    // });
  });
}
EOF

echo ""
echo -e "${GREEN}✅ Mobile API client generation completed!${NC}"
echo "=================================================="
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Add generated dependencies to pubspec.yaml"
echo "2. Run: flutter pub get"
echo "3. Update existing service classes to use new ApiClient"
echo "4. Test the generated client with: flutter test test/api_client_test.dart"
echo ""
echo -e "${YELLOW}📁 Generated files:${NC}"
echo "• $GENERATED_API_DIR/ - Generated OpenAPI client"
echo "• $MOBILE_APP_DIR/lib/api/api_client.dart - Wrapper service"
echo "• $MOBILE_APP_DIR/test/api_client_test.dart - Test file"
echo ""
echo -e "${GREEN}🎉 Happy coding!${NC}"