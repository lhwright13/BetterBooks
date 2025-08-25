/// EchoWright Theme Configuration
///
/// Modern, minimalist theme inspired by Audible's clean design
/// with EchoWright's unique turquoise and coral brand identity.
///
/// Features:
/// - Turquoise primary color from brand logo
/// - Coral gradient accents for CTAs and highlights
/// - Gold text for brand personality
/// - Clean dark mode optimized for reading
/// - Material Design 3 components
/// - Subtle shadows and minimal decorations

library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EchoWrightTheme {
  // Brand Colors from Logo
  static const Color primaryTurquoise =
      Color(0xFF4ECDC4); // Main brand turquoise
  static const Color lightTurquoise = Color(0xFF7DD3D8); // Lighter variant
  static const Color darkTurquoise = Color(0xFF2FB3AA); // Darker variant

  // Coral Accent Colors
  static const Color accentCoral = Color(0xFFFF6B6B); // Primary coral
  static const Color lightCoral = Color(0xFFFF8E8E); // Light coral
  static const Color darkCoral = Color(0xFFE85555); // Dark coral
  static const Color warmCoral = Color(0xFFFFA07A); // Warm coral

  // Brand Text Colors
  static const Color brandGold = Color(0xFFFFD93D); // Logo gold yellow
  static const Color warmGold = Color(0xFFFFE066); // Warmer gold
  static const Color deepGold = Color(0xFFE6C136); // Deeper gold

  // Dark Mode Base Colors
  static const Color backgroundDark =
      Color(0xFF1A1A1A); // Primary dark background
  static const Color surfaceDark = Color(0xFF2D2D2D); // Elevated surfaces/cards
  static const Color backgroundLight =
      Color(0xFF242424); // Lighter background variant
  static const Color dividerDark = Color(0xFF404040); // Subtle dividers

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // Main text
  static const Color textSecondary = Color(0xFFE0E0E0); // Secondary text
  static const Color textMuted = Color(0xFFA0A0A0); // Muted/hint text
  static const Color textOnPrimary =
      Color(0xFF000000); // Text on colored backgrounds

  // Status Colors
  static const Color successColor = Color(0xFF4CAF50); // Success states
  static const Color warningColor = Color(0xFFFFC107); // Warning states
  static const Color errorColor = Color(0xFFFF5722); // Error states
  static const Color infoColor = Color(0xFF2196F3); // Information states

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTurquoise, lightTurquoise],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentCoral, warmCoral],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandGold, warmGold],
  );

  // Shadows
  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // Typography System
  static TextTheme get textTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    final headingFont = GoogleFonts.poppins();

    return baseTextTheme.copyWith(
      // Display styles - large hero text
      displayLarge: headingFont.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.12,
      ),
      displayMedium: headingFont.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.16,
      ),
      displaySmall: headingFont.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.22,
      ),

      // Headlines - section headers
      headlineLarge: headingFont.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.25,
      ),
      headlineMedium: headingFont.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.29,
      ),
      headlineSmall: headingFont.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.33,
      ),

      // Titles - card headers, buttons
      titleLarge: headingFont.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.27,
      ),
      titleMedium: headingFont.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.33,
      ),
      titleSmall: headingFont.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.43,
      ),

      // Body text - main content
      bodyLarge: baseTextTheme.bodyLarge!.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.43,
      ),
      bodySmall: baseTextTheme.bodySmall!.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMuted,
        height: 1.33,
      ),

      // Labels - buttons, form labels, captions
      labelLarge: baseTextTheme.labelLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium!.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.33,
        letterSpacing: 0.5,
      ),
      labelSmall: baseTextTheme.labelSmall!.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textMuted,
        height: 1.45,
        letterSpacing: 0.5,
      ),
    );
  }

  // Main Theme Configuration
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: primaryTurquoise,
        onPrimary: textOnPrimary,
        primaryContainer: darkTurquoise,
        onPrimaryContainer: textPrimary,
        secondary: accentCoral,
        onSecondary: textPrimary,
        secondaryContainer: darkCoral,
        onSecondaryContainer: textPrimary,
        tertiary: brandGold,
        onTertiary: textOnPrimary,
        error: errorColor,
        onError: textPrimary,
        surface: surfaceDark,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: dividerDark,
        shadow: Colors.black,
        inverseSurface: textPrimary,
        onInverseSurface: backgroundDark,
        inversePrimary: darkTurquoise,
        surfaceTint: primaryTurquoise,
      ),

      // Background
      scaffoldBackgroundColor: backgroundDark,

      // Typography
      textTheme: textTheme,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge,
        centerTitle: false,
        titleSpacing: 16,
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceDark,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(0),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: accentCoral,
          disabledForegroundColor: textMuted,
          disabledBackgroundColor: dividerDark,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: textMuted,
          side: BorderSide(
            color: primaryTurquoise,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTurquoise,
          disabledForegroundColor: textMuted,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: textMuted,
          highlightColor: primaryTurquoise.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundLight,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dividerDark,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dividerDark,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryTurquoise,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorColor,
            width: 1,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: primaryTurquoise.withValues(alpha: 0.1),
        iconColor: textSecondary,
        textColor: textPrimary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium,
        leadingAndTrailingTextStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryTurquoise,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelSmall,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: primaryTurquoise,
        unselectedLabelColor: textMuted,
        indicatorColor: primaryTurquoise,
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelMedium,
        overlayColor: WidgetStateProperty.all(
          primaryTurquoise.withValues(alpha: 0.1),
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryTurquoise,
        linearTrackColor: dividerDark,
        circularTrackColor: dividerDark,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: dividerDark,
        thickness: 1,
        space: 1,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: backgroundLight,
        selectedColor: primaryTurquoise.withValues(alpha: 0.2),
        secondarySelectedColor: accentCoral.withValues(alpha: 0.2),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryTurquoise;
          }
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryTurquoise.withValues(alpha: 0.5);
          }
          return dividerDark;
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryTurquoise,
        inactiveTrackColor: dividerDark,
        thumbColor: primaryTurquoise,
        overlayColor: primaryTurquoise.withValues(alpha: 0.2),
        valueIndicatorColor: primaryTurquoise,
        valueIndicatorTextStyle: textTheme.bodySmall?.copyWith(
          color: textOnPrimary,
        ),
      ),

      // Visual density for better touch targets
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

// Extension for easy access to brand colors
extension EchoWrightThemeExtension on ThemeData {
  Color get primaryTurquoise => EchoWrightTheme.primaryTurquoise;
  Color get accentCoral => EchoWrightTheme.accentCoral;
  Color get brandGold => EchoWrightTheme.brandGold;
  Color get surfaceDark => EchoWrightTheme.surfaceDark;
  Color get textSecondary => EchoWrightTheme.textSecondary;
  Color get textMuted => EchoWrightTheme.textMuted;

  LinearGradient get primaryGradient => EchoWrightTheme.primaryGradient;
  LinearGradient get accentGradient => EchoWrightTheme.accentGradient;
  LinearGradient get goldGradient => EchoWrightTheme.goldGradient;

  List<BoxShadow> get subtleShadow => EchoWrightTheme.subtleShadow;
  List<BoxShadow> get elevatedShadow => EchoWrightTheme.elevatedShadow;
}
