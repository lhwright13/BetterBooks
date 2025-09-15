import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/routes.dart';

/// Simple test auth screen to debug navigation issues
class SimpleTestAuthScreen extends StatelessWidget {
  const SimpleTestAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('🔍 SimpleTestAuthScreen build called');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Auth Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Navigation Test Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'The app successfully navigated to the auth screen.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  print('🔍 Button pressed - Main App (placeholder)');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Main app navigation would go here')),
                  );
                },
                child: const Text('Go to Main App'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  print('🔍 Button pressed - Going back to splash');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.audiotrack, size: 64),
                              SizedBox(height: 16),
                              Text('Back to Splash', style: TextStyle(fontSize: 24)),
                              SizedBox(height: 32),
                              CircularProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Back to Splash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}