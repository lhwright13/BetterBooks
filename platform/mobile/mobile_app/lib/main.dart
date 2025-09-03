/**
 * main.dart - Entry point for the EchoWright mobile application
 * 
 * This is the root file of the EchoWright Flutter app - an AI-powered audiobook 
 * companion that allows users to interact with books through AI personas, 
 * ask questions about content, and enjoy immersive audiobook experiences.
 * 
 * Key responsibilities:
 * - Initialize the Flutter app with Material Design 3
 * - Set up global state management using Provider pattern
 * - Define navigation routes for all app screens
 * - Configure the app's theme and branding
 * 
 * Architecture integration:
 * - Uses Provider for state management across the app
 * - Connects to backend microservices via API calls
 * - Supports multiple AI personas for book interaction
 * - Handles audiobook playback and voice interaction
 */

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'providers/app_state.dart';
import 'providers/auth_provider.dart';
import 'services/log_service.dart';
import 'screens/main_home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/enhanced_player_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/user_settings_screen.dart';
// Email verification screen removed
import 'screens/bookstore_screen.dart';
import 'theme/echowright_theme.dart';

/// Entry point for the EchoWright application
/// Initializes the app and sets up the root widget
void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    LogService.error(
      'Flutter Error: ${details.exception}',
      'main',
      details.exception,
    );
    
    // In development, also print to console
    FlutterError.presentError(details);
  };
  
  // Catch errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.error(
      'Uncaught Error: $error',
      'main', 
      error,
    );
    return true;
  };
  
  // Initialize logging
  bool isDebugMode = true;
  try {
    // Check if we're in debug mode
    assert(() {
      isDebugMode = true;
      return true;
    }());
    isDebugMode = false; // If assert is disabled, we're in release mode
  } catch (e) {
    // Fallback
    isDebugMode = true;
  }
  
  LogService.init(isDebugMode: isDebugMode);
  LogService.info('EchoWright app starting...', 'main');
  
  runApp(const EchoWrightApp());
}

/// Root widget for the EchoWright application
/// Sets up global state management and navigation routing
class EchoWrightApp extends StatelessWidget {
  const EchoWrightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication state provider
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        // Global app state provider
        ChangeNotifierProvider(create: (context) => AppState()),
      ],
      child: MaterialApp(
        title: 'EchoWright',
        theme: EchoWrightTheme.theme,
        home: const AuthWrapper(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.0)),
            child: child!,
          );
        },
        routes: {
          '/library': (context) => LibraryScreen(),
          '/player': (context) => EnhancedPlayerScreen(),
          '/chat': (context) => ChatScreen(),
          '/settings': (context) => UserSettingsScreen(),
          // Email verification route removed
          '/store': (context) => BookstoreScreen(),
        },
      ),
    );
  }
}

/// Wrapper widget that manages authentication flow
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Initialize authentication on app start
        if (!authProvider.isInitialized) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            authProvider.initialize();
          });
          return const SplashScreen();
        }

        // Show loading screen during authentication operations
        if (authProvider.isLoading) {
          return const SplashScreen();
        }

        // Show main app if user is authenticated (email verification removed)
        if (authProvider.isAuthenticated) {
          return MainHomeScreen();
        }

        // Show authentication screen if not authenticated
        return const AuthScreen();
      },
    );
  }
}

/// Simple splash screen shown during app initialization
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EchoWrightTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/login_logo.svg',
              width: 350,
              height: 200,
              placeholderBuilder: (BuildContext context) => Container(
                width: 350,
                height: 200,
                decoration: BoxDecoration(
                  color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.audiotrack,
                  size: 80,
                  color: EchoWrightTheme.primaryCoral,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              color: EchoWrightTheme.brandGold,
            ),
          ],
        ),
      ),
    );
  }
}

/// Authentication screen for login/signup
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  // Validation state
  String? _emailError;
  String? _passwordError;
  String? _nameError;

  // Email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  // Password validation
  bool _isValidPassword(String password) {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    return password.length >= 8 &&
           RegExp(r'[A-Z]').hasMatch(password) &&
           RegExp(r'[a-z]').hasMatch(password) &&
           RegExp(r'[0-9]').hasMatch(password);
  }
  
  String _getPasswordStrengthText(String password) {
    if (password.isEmpty) return '';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Password must contain uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(password)) return 'Password must contain lowercase letter';  
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Password must contain number';
    return 'Strong password ✓';
  }
  
  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = 'Email is required';
      } else if (!_isValidEmail(value)) {
        _emailError = 'Please enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }
  
  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Password is required';
      } else if (!_isValidPassword(value)) {
        _passwordError = _getPasswordStrengthText(value);
      } else {
        _passwordError = null;
      }
    });
  }
  
  void _validateName(String value) {
    setState(() {
      if (value.isEmpty) {
        _nameError = 'Full name is required';
      } else if (value.trim().split(' ').length < 2) {
        _nameError = 'Please enter your first and last name';
      } else {
        _nameError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EchoWrightTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // App logo and title
                  Container(
                    width: 350,
                    height: 220,
                    child: SvgPicture.asset(
                      'assets/images/login_logo.svg',
                      width: 350,
                      height: 220,
                      placeholderBuilder: (BuildContext context) => Container(
                        width: 350,
                        height: 220,
                        decoration: BoxDecoration(
                          color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.audiotrack,
                          size: 80,
                          color: EchoWrightTheme.primaryCoral,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI-Powered Audiobook Companion',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: EchoWrightTheme.primaryCoral,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Error message display
                  if (authProvider.errorMessage != null) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authProvider.errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red[700]),
                            onPressed: authProvider.clearError,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Name field for sign up
                  if (_isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        errorText: _nameError,
                        hintText: 'Enter your first and last name',
                      ),
                      onChanged: _validateName,
                    ),
                    SizedBox(height: 16),
                  ],

                  // Email field
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      errorText: _emailError,
                      hintText: 'Enter your email address',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: _validateEmail,
                  ),
                  SizedBox(height: 16),

                  // Password field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                          errorText: _passwordError?.contains('✓') == true ? null : _passwordError,
                          hintText: 'Enter a strong password',
                        ),
                        obscureText: true,
                        onChanged: _validatePassword,
                      ),
                      if (_passwordController.text.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          _getPasswordStrengthText(_passwordController.text),
                          style: TextStyle(
                            fontSize: 12,
                            color: _isValidPassword(_passwordController.text)
                                ? Colors.green
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 24),

                  // Sign in/up button
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleEmailAuth,
                    child: authProvider.isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                  ),
                  SizedBox(height: 16),

                  // Toggle sign in/up
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        authProvider.clearError();
                        // Clear validation errors
                        _emailError = null;
                        _passwordError = null;
                        _nameError = null;
                        // Clear text fields
                        _emailController.clear();
                        _passwordController.clear();
                        _nameController.clear();
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : 'Don\'t have an account? Sign Up',
                    ),
                  ),

                  SizedBox(height: 32),
                  Text(
                    'Or continue with',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),

                  // OAuth buttons
                  Row(
                    children: [
                      // Google Sign In
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : _handleGoogleSignIn,
                          icon: Icon(Icons.account_circle),
                          label: Text('Google'),
                        ),
                      ),
                      SizedBox(width: 16),
                      // Apple Sign In
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : _handleAppleSignIn,
                          icon: Icon(Icons.apple),
                          label: Text('Apple'),
                        ),
                      ),
                    ],
                  ),
                ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleEmailAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Validate all fields
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    
    _validateEmail(email);
    _validatePassword(password);
    
    if (_isSignUp) {
      _validateName(name);
    }
    
    // Check for validation errors
    bool hasErrors = _emailError != null || _passwordError != null;
    if (_isSignUp && _nameError != null) hasErrors = true;
    
    if (hasErrors) {
      // Show validation errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the errors above'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isSignUp) {
      await authProvider.signUpWithEmail(
        email: email,
        password: password,
        displayName: name,
      );
    } else {
      await authProvider.signInWithEmail(
        email: email,
        password: password,
      );
    }
  }

  void _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();
    
    final success = await authProvider.signInWithGoogle();
    
    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleAppleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();
    
    final success = await authProvider.signInWithApple();
    
    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
