/// EchoWright Theme Configuration
///
/// Modern, minimalist theme based on the actual EchoWright brand logo
/// with precise color matching from the brand identity.
///
/// Features:
/// - Vibrant turquoise primary color from logo background
/// - Orange-to-coral gradient accents matching the wing design
/// - Golden yellow text matching brand typography
/// - Clean dark mode optimized for reading
/// - Material Design 3 components
/// - Subtle shadows and minimal decorations

library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EchoWrightTheme {
  // Brand Colors from Actual Logo
  static const Color primaryTurquoise =
      Color(0xFF44C0C1); // New brand turquoise background
  static const Color lightTurquoise = Color(0xFF6ED4D0); // Lighter variant
  static const Color darkTurquoise = Color(0xFF2BB5B0); // Darker variant

  // Brand Accent Colors
  static const Color primaryOrange = Color(0xFFFD5E4C); // Brand orange accent
  static const Color lightOrange = Color(0xFFFFA666); // Lighter orange
  static const Color darkOrange = Color(0xFFE6792A); // Darker orange

  static const Color primaryCoral = Color(0xFFE43427); // Brand red accent
  static const Color lightCoral = Color(0xFFEC6B5E); // Lighter coral
  static const Color darkCoral = Color(0xFFD63021); // Darker coral

  // Brand Gold Yellow from Logo Text
  static const Color brandGold = Color(0xFFF1C40F); // Logo text gold
  static const Color lightGold = Color(0xFFF7DC6F); // Lighter gold
  static const Color deepGold = Color(0xFFD4AC0D); // Deeper gold
  static const Color warmGold = Color(0xFFF39C12); // Warm gold accent

  // Professional Design System Colors
  static const Color softTan = Color(0xFFCEB590); // Primary interactive elements
  static const Color darkGreen = Color(0xFF3F594F); // Premium text and headers
  static const Color warmCream = Color(0xFFF5F2ED); // Light backgrounds
  static const Color deepForest = Color(0xFF2A3F35); // Dark text variant
  static const Color softWhite = Color(0xFFFAFAFA); // Card backgrounds

  // Dark Mode Base Colors
  static const Color backgroundDark =
      Color(0xFF44C0C1); // Brand turquoise background
  static const Color surfaceDark = Color(0xFFFFFFFF); // Elevated surfaces/cards - white for contrast
  static const Color backgroundLight =
      Color(0xFF5DCBCC); // Lighter background variant - lighter turquoise
  static const Color dividerDark = Color(0xFF2C3E50); // Subtle dividers - dark for contrast

  // Text Colors - Updated for turquoise background
  static const Color textPrimary = Color(0xFF1A1A1A); // Main text - dark for contrast
  static const Color textSecondary = Color(0xFF2C3E50); // Secondary text - dark blue-gray
  static const Color textMuted = Color(0xFF555555); // Muted/hint text - medium gray
  static const Color textOnPrimary =
      Color(0xFFFFFFFF); // Text on colored backgrounds - white on colors
  static const Color textOnGold = Color(0xFF2C3E50); // Text on gold backgrounds
  static const Color textOnBackground = Color(0xFF1A1A1A); // Text on turquoise background

  // Status Colors
  static const Color successColor = Color(0xFF27AE60); // Success states
  static const Color warningColor =
      Color(0xFFF39C12); // Warning states (warm gold)
  static const Color errorColor = Color(0xFFE74C3C); // Error states (coral)
  static const Color infoColor = Color(0xFF3498DB); // Information states

  // Brand Gradients from Logo
  static const LinearGradient wingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, primaryCoral],
    stops: [0.0, 1.0],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTurquoise, lightTurquoise],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, lightOrange],
  );

  static const LinearGradient coralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryCoral, lightCoral],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandGold, lightGold],
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

  static const List<BoxShadow> brandGlowShadow = [
    BoxShadow(
      color: Color(0x40F1C40F), // Gold glow
      blurRadius: 20,
      offset: Offset(0, 0),
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
        color: brandGold,
        height: 1.12,
      ),
      displayMedium: headingFont.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w600,
        color: brandGold,
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
        secondary: primaryOrange,
        onSecondary: textOnPrimary,
        secondaryContainer: darkOrange,
        onSecondaryContainer: textPrimary,
        tertiary: brandGold,
        onTertiary: textOnGold,
        tertiaryContainer: deepGold,
        onTertiaryContainer: textOnGold,
        error: primaryCoral,
        onError: textPrimary,
        surface: surfaceDark,
        onSurface: textOnBackground,
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
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: brandGold,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: false,
        titleSpacing: 16,
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: brandGold,
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
          foregroundColor: primaryCoral, // Red text for sophistication
          backgroundColor: softTan, // Professional tan background
          disabledForegroundColor: textMuted,
          disabledBackgroundColor: dividerDark,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Softer corners
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkGreen, // Dark green for secondary actions
          backgroundColor: Colors.transparent,
          disabledForegroundColor: textMuted,
          side: BorderSide(
            color: softTan, // Tan border
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryCoral, // Red for text buttons
          disabledForegroundColor: textMuted,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600, // Slightly bolder
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: textPrimary,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        shape: CircleBorder(),
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
            color: primaryCoral,
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
        selectedItemColor: brandGold,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: brandGold,
        ),
        unselectedLabelStyle: textTheme.labelSmall,
      ),

      // Navigation Rail Theme
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceDark,
        selectedIconTheme: const IconThemeData(
          color: brandGold,
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: textMuted,
          size: 24,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: brandGold,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: textMuted,
        ),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: brandGold,
        unselectedLabelColor: textMuted,
        indicatorColor: brandGold,
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelMedium,
        overlayColor: WidgetStateProperty.all(
          brandGold.withValues(alpha: 0.1),
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
        space: 0,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: backgroundLight,
        selectedColor: brandGold.withValues(alpha: 0.2),
        secondarySelectedColor: primaryTurquoise.withValues(alpha: 0.2),
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
            return brandGold;
          }
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return brandGold.withValues(alpha: 0.5);
          }
          return dividerDark;
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryTurquoise,
        inactiveTrackColor: dividerDark,
        thumbColor: brandGold,
        overlayColor: brandGold.withValues(alpha: 0.2),
        valueIndicatorColor: brandGold,
        valueIndicatorTextStyle: textTheme.bodySmall?.copyWith(
          color: textOnGold,
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
  Color get primaryOrange => EchoWrightTheme.primaryOrange;
  Color get primaryCoral => EchoWrightTheme.primaryCoral;
  Color get brandGold => EchoWrightTheme.brandGold;
  Color get surfaceDark => EchoWrightTheme.surfaceDark;
  Color get textSecondary => EchoWrightTheme.textSecondary;
  Color get textMuted => EchoWrightTheme.textMuted;
  
  // Professional Design System Colors
  Color get softTan => EchoWrightTheme.softTan;
  Color get darkGreen => EchoWrightTheme.darkGreen;
  Color get warmCream => EchoWrightTheme.warmCream;
  Color get deepForest => EchoWrightTheme.deepForest;
  Color get softWhite => EchoWrightTheme.softWhite;

  LinearGradient get primaryGradient => EchoWrightTheme.primaryGradient;
  LinearGradient get wingGradient => EchoWrightTheme.wingGradient;
  LinearGradient get orangeGradient => EchoWrightTheme.orangeGradient;
  LinearGradient get coralGradient => EchoWrightTheme.coralGradient;
  LinearGradient get goldGradient => EchoWrightTheme.goldGradient;

  List<BoxShadow> get subtleShadow => EchoWrightTheme.subtleShadow;
  List<BoxShadow> get elevatedShadow => EchoWrightTheme.elevatedShadow;
  List<BoxShadow> get brandGlowShadow => EchoWrightTheme.brandGlowShadow;
}
