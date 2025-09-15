part of 'mock_services.dart';

// Generate mocks by running: dart run build_runner build
@GenerateMocks([
  // Repositories
  BookRepository,
  UserRepository,
  PurchaseRepository,
  LibraryRepository,
  
  // API Client
  ApiClient,
  
  // Services
  DownloadService,
  VoiceService,
  PlayerStateService,
  AuthService,
  NetworkService,
])
void main() {}