// Entry point for the Flutter application
import 'package:flutter/material.dart';

// The Flutter `main` function simply runs the `MyApp` widget.
void main() {
  runApp(const MyApp());
}

// Basic placeholder widget displaying the app name on screen.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('BetterBooks')),
      ),
    );
  }
}
