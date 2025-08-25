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

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'providers/auth_provider.dart';
import 'screens/main_home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/enhanced_player_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/user_settings_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/bookstore_screen.dart';
import 'theme/echowright_theme.dart';

/// Entry point for the EchoWright application
/// Initializes the app and sets up the root widget
void main() {
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
        home: AuthWrapper(),
        routes: {
          '/library': (context) => LibraryScreen(),
          '/player': (context) => EnhancedPlayerScreen(),
          '/chat': (context) => ChatScreen(),
          '/settings': (context) => UserSettingsScreen(),
          '/verify-email': (context) => EmailVerificationScreen(email: ''),
          '/store': (context) => BookstoreScreen(),
        },
      ),
    );
  }
}

/// Wrapper widget that manages authentication flow
class AuthWrapper extends StatelessWidget {
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

        // Show main app if user is authenticated and verified
        if (authProvider.isAuthenticated) {
          // Check if email verification is needed
          if (authProvider.needsEmailVerification) {
            return EmailVerificationScreen(
              email: authProvider.currentUser?.email ?? '',
            );
          }
          return MainHomeScreen();
        }

        // Show authentication screen if not authenticated
        return AuthScreen();
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'EchoWright',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Authentication screen for login/signup
class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo and title
                  Icon(
                    Icons.auto_stories,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'EchoWright',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-Powered Audiobook Companion',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
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
                      ),
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
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),

                  // Password field
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
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
                          onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
                          icon: Icon(Icons.account_circle),
                          label: Text('Google'),
                        ),
                      ),
                      SizedBox(width: 16),
                      // Apple Sign In
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: authProvider.isLoading ? null : _handleAppleSignIn,
                          icon: Icon(Icons.apple),
                          label: Text('Apple'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleEmailAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_isSignUp) {
      await authProvider.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
    } else {
      await authProvider.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  void _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signInWithGoogle();
  }

  void _handleAppleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signInWithApple();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
