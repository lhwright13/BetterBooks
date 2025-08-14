/**
 * modern_theme.dart - Modern EchoWright Theme Configuration
 * 
 * Defines the visual design system for the EchoWright mobile application.
 * Inspired by Audible's clean, reading-focused design with warm, inviting colors.
 * 
 * Features:
 * - Warm orange and yellow gradient brand colors
 * - Dark mode optimized for comfortable reading
 * - Accessibility-friendly contrast ratios
 * - Material Design 3 components
 * - Custom typography for reading experiences
 */

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernTheme {
  // Brand Colors - Warm and Inviting
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color primaryYellow = Color(0xFFF7931E);
  static const Color accentYellow = Color(0xFFFFD23E);
  
  // Background Colors - Dark Mode Optimized
  static const Color backgroundPrimary = Color(0xFF0F0F0F);
  static const Color backgroundSecondary = Color(0xFF1A1A1A);
  static const Color backgroundTertiary = Color(0xFF242424);
  static const Color backgroundCard = Color(0xFF2A2A2A);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color textTertiary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF808080);
  
  // Status Colors
  static const Color successColor = Color(0xFF4ADE80);
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, primaryYellow],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryYellow, accentYellow],
  );

  // Typography
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      // Display styles - for hero text
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.22,
      ),
      
      // Headline styles - for section headers
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.33,
      ),
      
      // Title styles - for card headers
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.33,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.43,
      ),
      
      // Body styles - for main content
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textTertiary,
        height: 1.33,
      ),
      
      // Label styles - for buttons and form labels
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.43,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textTertiary,
        height: 1.45,
      ),
    ),
  );

  // Main Theme
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: primaryOrange,
        onPrimary: Colors.white,
        primaryContainer: backgroundCard,
        onPrimaryContainer: textPrimary,
        secondary: primaryYellow,
        onSecondary: Colors.white,
        secondaryContainer: backgroundTertiary,
        onSecondaryContainer: textSecondary,
        tertiary: accentYellow,
        onTertiary: Colors.black,
        error: errorColor,
        onError: Colors.white,
        errorContainer: Color(0xFF2D1B1B),
        onErrorContainer: Color(0xFFFFB4AB),
        surface: backgroundSecondary,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: Color(0xFF525252),
        shadow: Colors.black,
        inverseSurface: textPrimary,
        onInverseSurface: backgroundPrimary,
        inversePrimary: Color(0xFF8B4000),
        surfaceTint: primaryOrange,
      ),
      
      // Typography
      textTheme: textTheme,
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: Colors.black26,
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge,
        toolbarTextStyle: textTheme.bodyMedium,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: backgroundCard,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primaryOrange,
          disabledForegroundColor: textMuted,
          disabledBackgroundColor: backgroundTertiary,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: textMuted,
          side: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: textTheme.labelMedium,
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryOrange,
          disabledForegroundColor: textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: textTheme.labelMedium,
        ),
      ),
      
      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: textMuted,
          highlightColor: primaryOrange.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 6,
        highlightElevation: 8,
        shape: CircleBorder(),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundTertiary,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: primaryOrange,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: errorColor,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // List Tile Theme
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: primaryOrange.withOpacity(0.1),
        iconColor: textSecondary,
        textColor: textPrimary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundSecondary,
        selectedItemColor: primaryOrange,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      
      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundSecondary,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryOrange.withOpacity(0.2),
        elevation: 8,
        height: 80,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return textTheme.labelSmall?.copyWith(color: primaryOrange);
          }
          return textTheme.labelSmall?.copyWith(color: textMuted);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: primaryOrange, size: 24);
          }
          return const IconThemeData(color: textMuted, size: 24);
        }),
      ),
      
      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryOrange,
        inactiveTrackColor: backgroundTertiary,
        thumbColor: primaryOrange,
        overlayColor: primaryOrange.withOpacity(0.2),
        valueIndicatorColor: primaryOrange,
        valueIndicatorTextStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
      
      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryOrange;
          }
          return textMuted;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryOrange.withOpacity(0.5);
          }
          return backgroundTertiary;
        }),
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryOrange,
        linearTrackColor: backgroundTertiary,
        circularTrackColor: backgroundTertiary,
      ),
      
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.1),
        thickness: 1,
        space: 1,
      ),
      
      // Scaffold Background
      scaffoldBackgroundColor: backgroundPrimary,
      
      // Other properties
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

// Extension for easy access to theme colors
extension ModernThemeExtension on ThemeData {
  Color get primaryOrange => ModernTheme.primaryOrange;
  Color get primaryYellow => ModernTheme.primaryYellow;
  Color get accentYellow => ModernTheme.accentYellow;
  Color get backgroundCard => ModernTheme.backgroundCard;
  Color get textSecondary => ModernTheme.textSecondary;
  Color get textTertiary => ModernTheme.textTertiary;
  LinearGradient get primaryGradient => ModernTheme.primaryGradient;
  LinearGradient get accentGradient => ModernTheme.accentGradient;
}