import '../api/api_client.dart';
import '../models/auth_models.dart';
import 'base_repository.dart';
import '../../core/services/error_handler.dart';

class UserRepository extends BaseRepository {
  UserRepository(ApiClient apiClient) : super(apiClient, ErrorHandler());

  Future<AuthResponse> signIn(String email, String password) async {
    return handleApiCall(() async {
      logInfo('User signing in with email: $email');
      return await ApiClient.signIn(email: email, password: password);
    });
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return handleApiCall(() async {
      logInfo('User signing up with email: $email');
      return await ApiClient.signUp(email: email, password: password);
    });
  }

  Future<AuthResponse> signInWithGoogle({
    required String idToken,
    required String accessToken,
    String? email,
    String? displayName,
  }) async {
    return handleApiCall(() async {
      logInfo('User signing in with Google');
      return await ApiClient.signInWithGoogle(
        idToken: idToken,
        accessToken: accessToken,
        email: email,
        displayName: displayName,
      );
    });
  }

  Future<AuthResponse> signInWithApple({
    required String identityToken,
    String? authorizationCode,
    String? email,
    String? fullName,
  }) async {
    return handleApiCall(() async {
      logInfo('User signing in with Apple');
      return await ApiClient.signInWithApple(
        identityToken: identityToken,
        authorizationCode: authorizationCode,
        email: email,
        fullName: fullName,
      );
    });
  }

  Future<int> getUserCredits() async {
    return handleApiCall(() async {
      logInfo('Fetching user credits');
      final response = await ApiClient.getUserCredits();
      return response.availableCredits;
    });
  }

  Future<void> signOut() async {
    return handleApiCall(() async {
      logInfo('User signing out');
      await ApiClient.logout();
    });
  }

  bool isAuthenticated() {
    return ApiClient.authToken != null;
  }
}