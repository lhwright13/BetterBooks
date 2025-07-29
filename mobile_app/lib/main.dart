import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/main_home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/enhanced_player_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/user_settings_screen.dart';

void main() {
  runApp(const BetterBooksApp());
}

class BetterBooksApp extends StatelessWidget {
  const BetterBooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'BetterBooks',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => MainHomeScreen(),
          '/library': (context) => LibraryScreen(),
          '/player': (context) => EnhancedPlayerScreen(),
          '/chat': (context) => ChatScreen(),
          '/settings': (context) => UserSettingsScreen(),
        },
      ),
    );
  }
}
