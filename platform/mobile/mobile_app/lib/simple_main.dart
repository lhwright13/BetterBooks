import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/simple_test_auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // App can still run without Firebase in development
    if (kDebugMode) {
      print('Firebase initialization failed: $e');
    }
  }
  
  runApp(const SimpleEchoWrightApp());
}

class SimpleEchoWrightApp extends StatelessWidget {
  const SimpleEchoWrightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoWright - Simple Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SimpleSplashScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/auth': (context) => const SimpleTestAuthScreen(),
      },
    );
  }
}

class SimpleSplashScreen extends StatefulWidget {
  const SimpleSplashScreen({super.key});

  @override
  State<SimpleSplashScreen> createState() => _SimpleSplashScreenState();
}

class _SimpleSplashScreenState extends State<SimpleSplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAuth();
  }

  _navigateToAuth() async {
    try {
      print('🔍 Simple app - Starting navigation...');
      
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        print('🔍 Simple app - Navigating to auth screen...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SimpleTestAuthScreen(),
          ),
        );
        print('✅ Simple app - Navigation successful!');
      }
    } catch (e) {
      print('❌ Simple app - Error in navigation: $e');
      print('❌ Simple app - Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.audiotrack,
                size: 64,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'EchoWright - Simple Test',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Testing basic navigation...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}