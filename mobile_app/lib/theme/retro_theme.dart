import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RetroColors {
  // Terminal Colors (inspired by classic computer interfaces)
  static const Color terminalDark = Color(0xFF0A0A0A);
  static const Color terminalGreen = Color(0xFF00FF41);
  static const Color terminalAmber = Color(0xFFFFBF00);
  static const Color phosphorGreen = Color(0xFF39FF14);
  
  // 80s Neon Palette
  static const Color neonCyan = Color(0xFF00FFFF);
  static const Color neonPink = Color(0xFFFF1493);
  static const Color neonOrange = Color(0xFFFF6600);
  static const Color neonPurple = Color(0xFF9D00FF);
  
  // VHS/Retro Colors
  static const Color vhsRed = Color(0xFFFF0040);
  static const Color vhsOrange = Color(0xFFFF8000);
  static const Color vhsYellow = Color(0xFFFFFF00);
  
  // Filing System Colors
  static const Color cardStock = Color(0xFFF5F5DC);
  static const Color tabBlue = Color(0xFF4169E1);
  static const Color tabGreen = Color(0xFF228B22);
  static const Color tabYellow = Color(0xFFFFD700);
  
  // Grid and Interface
  static const Color gridBlue = Color(0xFF0080FF);
  static const Color hudOverlay = Color(0x30000000);
  static const Color scanlineOverlay = Color(0x10FFFFFF);
  
  // Background Gradients
  static const List<Color> terminalGradient = [
    Color(0xFF0F0F23),
    Color(0xFF16213E),
    Color(0xFF0F3460),
  ];
  
  static const List<Color> vhsGradient = [
    Color(0xFF1A0A2E),
    Color(0xFF16213E),
    Color(0xFF533483),
  ];
}

class RetroTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      primarySwatch: Colors.cyan,
      primaryColor: RetroColors.neonCyan,
      scaffoldBackgroundColor: RetroColors.terminalDark,
      
      // Typography - Mix of tech fonts for different purposes
      textTheme: TextTheme(
        // Headers - Bold tech font like terminal readouts
        displayLarge: GoogleFonts.orbitron(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: RetroColors.neonCyan,
          letterSpacing: 2.0,
        ),
        displayMedium: GoogleFonts.orbitron(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: RetroColors.neonCyan,
          letterSpacing: 1.5,
        ),
        displaySmall: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: RetroColors.neonCyan,
          letterSpacing: 1.2,
        ),
        
        // Titles - Clean monospace for system labels
        headlineLarge: GoogleFonts.sourceCodePro(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: RetroColors.terminalGreen,
          letterSpacing: 0.8,
        ),
        headlineMedium: GoogleFonts.sourceCodePro(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: RetroColors.terminalGreen,
          letterSpacing: 0.6,
        ),
        headlineSmall: GoogleFonts.sourceCodePro(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: RetroColors.terminalGreen,
          letterSpacing: 0.4,
        ),
        
        // Body text - Terminal style for readability
        bodyLarge: GoogleFonts.sourceCodePro(
          fontSize: 14,
          color: RetroColors.terminalAmber,
          letterSpacing: 0.2,
        ),
        bodyMedium: GoogleFonts.sourceCodePro(
          fontSize: 12,
          color: RetroColors.terminalAmber,
          letterSpacing: 0.1,
        ),
        bodySmall: GoogleFonts.sourceCodePro(
          fontSize: 10,
          color: RetroColors.terminalAmber.withOpacity(0.8),
        ),
        
        // Labels - Rajdhani for system UI elements
        labelLarge: GoogleFonts.rajdhani(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: RetroColors.phosphorGreen,
          letterSpacing: 1.0,
        ),
        labelMedium: GoogleFonts.rajdhani(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: RetroColors.phosphorGreen,
          letterSpacing: 0.8,
        ),
        labelSmall: GoogleFonts.rajdhani(
          fontSize: 8,
          fontWeight: FontWeight.w500,
          color: RetroColors.phosphorGreen.withOpacity(0.8),
          letterSpacing: 0.6,
        ),
      ),
      
      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: RetroColors.neonCyan,
        secondary: RetroColors.neonPink,
        tertiary: RetroColors.phosphorGreen,
        surface: Color(0xFF1A1A2E),
        background: RetroColors.terminalDark,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: RetroColors.terminalAmber,
        onBackground: RetroColors.terminalAmber,
        error: RetroColors.vhsRed,
        outline: RetroColors.gridBlue,
      ),
      
      // App bar - Terminal style header
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF0F0F23),
        foregroundColor: RetroColors.neonCyan,
        elevation: 0,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: RetroColors.neonCyan,
          letterSpacing: 1.5,
        ),
      ),
      
      // Cards - Filing system aesthetic
      cardTheme: CardThemeData(
        color: Color(0xFF16213E),
        elevation: 8,
        shadowColor: RetroColors.neonCyan.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0), // Sharp corners like index cards
          side: BorderSide(
            color: RetroColors.gridBlue.withOpacity(0.4),
            width: 1,
          ),
        ),
        margin: EdgeInsets.all(4),
      ),
      
      // Bottom navigation - Tab system
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0A0A0A),
        selectedItemColor: RetroColors.neonCyan,
        unselectedItemColor: RetroColors.terminalAmber.withOpacity(0.6),
        selectedLabelStyle: GoogleFonts.sourceCodePro(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
        unselectedLabelStyle: GoogleFonts.sourceCodePro(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          fontSize: 9,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      
      // Buttons - Retro tech style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RetroColors.neonCyan,
          foregroundColor: Colors.black,
          textStyle: GoogleFonts.rajdhani(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0), // Sharp corners
          ),
          elevation: 6,
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RetroColors.neonPink,
          side: BorderSide(color: RetroColors.neonPink, width: 2),
          textStyle: GoogleFonts.rajdhani(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
        ),
      ),
      
      // Input fields - Terminal style
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF0F0F23),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: RetroColors.gridBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: RetroColors.gridBlue.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: RetroColors.neonCyan, width: 2),
        ),
        labelStyle: GoogleFonts.sourceCodePro(
          color: RetroColors.terminalAmber,
        ),
        hintStyle: GoogleFonts.sourceCodePro(
          color: RetroColors.terminalAmber.withOpacity(0.6),
        ),
      ),
    );
  }
}

// Animation durations for consistent retro feel
class RetroAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration scanline = Duration(milliseconds: 100);
}

// Retro-specific measurements
class RetroSizes {
  static const double cardElevation = 8.0;
  static const double borderWidth = 1.0;
  static const double tabHeight = 48.0;
  static const double iconSize = 20.0;
  static const double padding = 16.0;
  static const double smallPadding = 8.0;
}