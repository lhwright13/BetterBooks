import '../../data/repositories/user_repository.dart';
import '../../data/models/auth_models.dart';
import 'base_controller.dart';

class AuthController extends BaseController {
  final UserRepository _userRepository;
  
  Map<String, dynamic>? _currentUser;
  bool _isAuthenticated = false;

  AuthController(this._userRepository) {
    _checkAuthenticationStatus();
  }

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  void _checkAuthenticationStatus() {
    _isAuthenticated = _userRepository.isAuthenticated();
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    return handleAsyncOperation(
      () async {
        logInfo('Attempting to sign in user: $email');
        
        final authResponse = await _userRepository.signIn(email, password);
        
        _currentUser = authResponse.user;
        _isAuthenticated = true;
        
        logInfo('User signed in successfully');
        notifyListeners();
        
        return true;
      },
      errorMessage: 'Failed to sign in. Please check your credentials.',
    );
  }

  Future<bool> signUp(String email, String password) async {
    return handleAsyncOperation(
      () async {
        logInfo('Attempting to sign up user: $email');
        
        final authResponse = await _userRepository.signUp(email, password);
        
        _currentUser = authResponse.user;
        _isAuthenticated = true;
        
        logInfo('User signed up successfully');
        notifyListeners();
        
        return true;
      },
      errorMessage: 'Failed to create account. Please try again.',
    );
  }

  Future<bool> signInWithGoogle({
    required String idToken,
    required String accessToken,
    String? email,
    String? displayName,
  }) async {
    return handleAsyncOperation(
      () async {
        logInfo('Attempting Google sign in');
        
        final authResponse = await _userRepository.signInWithGoogle(
          idToken: idToken,
          accessToken: accessToken,
          email: email,
          displayName: displayName,
        );
        
        _currentUser = authResponse.user;
        _isAuthenticated = true;
        
        logInfo('Google sign in successful');
        notifyListeners();
        
        return true;
      },
      errorMessage: 'Google sign in failed. Please try again.',
    );
  }

  Future<bool> signInWithApple({
    required String identityToken,
    String? authorizationCode,
    String? email,
    String? fullName,
  }) async {
    return handleAsyncOperation(
      () async {
        logInfo('Attempting Apple sign in');
        
        final authResponse = await _userRepository.signInWithApple(
          identityToken: identityToken,
          authorizationCode: authorizationCode,
          email: email,
          fullName: fullName,
        );
        
        _currentUser = authResponse.user;
        _isAuthenticated = true;
        
        logInfo('Apple sign in successful');
        notifyListeners();
        
        return true;
      },
      errorMessage: 'Apple sign in failed. Please try again.',
    );
  }

  Future<void> signOut() async {
    return handleAsyncOperation(
      () async {
        logInfo('Signing out user');
        
        await _userRepository.signOut();
        
        _currentUser = null;
        _isAuthenticated = false;
        
        logInfo('User signed out successfully');
        notifyListeners();
      },
      errorMessage: 'Failed to sign out. Please try again.',
    );
  }

  Future<int> getUserCredits() async {
    return handleAsyncOperation(
      () async {
        logInfo('Fetching user credits');
        return await _userRepository.getUserCredits();
      },
      showLoading: false,
      errorMessage: 'Failed to load credits.',
    );
  }
}