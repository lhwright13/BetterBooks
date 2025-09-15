import 'package:get_it/get_it.dart';
import '../../data/api/api_client.dart';
import '../../services/voice_service.dart';
import '../../services/player_state_service.dart';
import '../../services/download_service.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../../presentation/controllers/player_controller.dart';
import '../../presentation/controllers/library_controller.dart';
import '../../presentation/controllers/purchase_controller.dart';
import '../services/error_handler.dart';
import '../services/navigation_service.dart';

final getIt = GetIt.instance;

class ServiceLocator {
  static Future<void> init() async {
    // Core services
    getIt.registerLazySingleton<ErrorHandler>(() => ErrorHandler());
    getIt.registerLazySingleton<NavigationService>(() => NavigationService());
    getIt.registerLazySingleton<ApiClient>(() => ApiClient());
    
    // Business services - refactored from singletons to DI
    getIt.registerLazySingleton<VoiceService>(() => VoiceService());
    getIt.registerLazySingleton<PlayerStateService>(() => PlayerStateService.instance);
    getIt.registerLazySingleton<DownloadService>(() => DownloadService.instance);
    
    // Repositories
    getIt.registerLazySingleton<BookRepository>(
      () => BookRepository(getIt<ApiClient>()),
    );
    getIt.registerLazySingleton<UserRepository>(
      () => UserRepository(getIt<ApiClient>()),
    );
    getIt.registerLazySingleton<LibraryRepository>(
      () => LibraryRepository(getIt<ApiClient>()),
    );
    getIt.registerLazySingleton<PurchaseRepository>(
      () => PurchaseRepository(getIt<ApiClient>()),
    );
    
    // Controllers
    getIt.registerLazySingleton<AuthController>(
      () => AuthController(getIt<UserRepository>()),
    );
    getIt.registerLazySingleton<PlayerController>(
      () => PlayerController(getIt<PlayerStateService>()),
    );
    getIt.registerLazySingleton<LibraryController>(
      () => LibraryController(getIt<LibraryRepository>()),
    );
    getIt.registerLazySingleton<PurchaseController>(
      () => PurchaseController(getIt<PurchaseRepository>()),
    );
  }
  
  static void reset() {
    getIt.reset();
  }
}