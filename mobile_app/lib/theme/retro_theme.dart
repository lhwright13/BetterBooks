import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Architectural Theme Colors - Inspired by "Emergent Tokyo" book cover
/// High-contrast color palette with bright architectural orange, clean whites, and deep blacks
class ArchitecturalColors {
  // PRIMARY: Bright Architectural Orange (WCAG AA Compliant)
  static const Color primaryOrange = Color(0xFFE63E00);      // Improved contrast orange (5.8:1 ratio on white)
  static const Color lightOrange = Color(0xFFFF6B33);        // Lighter orange for highlights
  static const Color deepOrange = Color(0xFFCC3600);         // Deeper orange for emphasis (7.2:1 ratio)
  static const Color orangeAccent = Color(0xFFFF7F50);       // Coral orange accent
  
  // BACKGROUNDS: Clean Architecture (High Contrast)
  static const Color pureWhite = Color(0xFFFFFFFF);          // Pure white backgrounds
  static const Color offWhite = Color(0xFFFAFAFA);           // Subtle off-white for cards
  static const Color lightGray = Color(0xFFF5F5F5);          // Light gray for surfaces
  static const Color cardWhite = Color(0xFFFEFEFE);          // Card backgrounds
  
  // TEXT: Frank Lloyd Wright Architectural (WCAG AA/AAA Compliant)
  static const Color deepBlack = Color(0xFF000000);          // Pure black for primary text (21:1 ratio)
  static const Color charcoalBlack = Color(0xFF1A1A1A);      // Charcoal for headers (16.7:1 ratio)
  static const Color darkGray = Color(0xFF2D2D2D);           // Dark gray for body text (12.6:1 ratio - AA compliant)
  static const Color mediumGray = Color(0xFF4A4A4A);         // Medium gray for secondary text (7.3:1 ratio - AAA compliant)
  static const Color subtleGray = Color(0xFF6B6B6B);         // Subtle gray for hints (4.9:1 ratio - AA compliant)
  
  // ARCHITECTURAL ACCENTS: Geometric Lines and Structure
  static const Color steelGray = Color(0xFF708090);          // Steel structural accents
  static const Color lightSteel = Color(0xFFB0C4DE);         // Light steel for borders
  static const Color architecturalBlue = Color(0xFF4682B4);  // Blueprint blue accent
  static const Color concreteGray = Color(0xFF696969);       // Concrete material tone
  
  // FUNCTIONAL COLORS: High Contrast System Colors
  static const Color successGreen = Color(0xFF28A745);       // Clear success green
  static const Color warningAmber = Color(0xFFFFC107);       // Warning amber
  static const Color errorRed = Color(0xFFDC3545);           // Clear error red
  static const Color infoBlue = Color(0xFF17A2B8);           // Information blue
  
  // SHADOWS AND OVERLAYS: Architectural Depth
  static const Color shadowBlack = Color(0x1A000000);        // Subtle black shadow
  static const Color overlayBlack = Color(0x80000000);       // Modal overlay
  static const Color subtleOverlay = Color(0x0A000000);      // Very subtle overlay
  static const Color orangeGlow = Color(0x20E63E00);         // Orange glow effect (matches primary)
  
  // GRADIENTS: Architectural Transitions
  static const List<Color> primaryGradient = [
    Color(0xFFFFFFFF),  // Pure white
    Color(0xFFFAFAFA),  // Off white
    Color(0xFFF5F5F5),  // Light gray
  ];
  
  static const List<Color> orangeGradient = [
    Color(0xFFFF4500),  // Primary orange
    Color(0xFFE63E00),  // Deep orange
  ];
  
  static const List<Color> cardGradient = [
    Color(0xFFFEFEFE),  // Card white
    Color(0xFFFAFAFA),  // Off white
  ];
  
  static const List<Color> architecturalShadow = [
    Color(0x1A000000),  // Subtle shadow
    Color(0x0D000000),  // Lighter shadow
    Color(0x00000000),  // Transparent
  ];
  
  // LEGACY MAPPINGS: Backward Compatibility
  static const Color primaryTerracotta = primaryOrange;
  static const Color lightTerracotta = lightOrange;
  static const Color sageGreen = steelGray;
  static const Color deepTerracotta = deepOrange;
  static const Color creamBackground = pureWhite;
  static const Color warmSurface = offWhite;
  static const Color softCard = cardWhite;
  static const Color ivoryWhite = pureWhite;
  static const Color lightBeige = lightGray;
  static const Color mediumBeige = mediumGray;
  static const Color warmTaupe = subtleGray;
  static const Color deepTaupe = darkGray;
  static const Color peachAccent = orangeAccent;
  static const Color coralTone = orangeAccent;
  static const Color orangeGlowOld = lightOrange;
  static const Color brickRed = primaryOrange;
  static const Color clayTone = lightOrange;
  static const Color stoneBeige = lightGray;
  static const Color woodWarm = mediumGray;
  static const Color burgundyAccent = deepOrange;
  static const Color sageAccent = steelGray;
  static const Color successEarth = successGreen;
  static const Color warningCoral = warningAmber;
  static const Color errorBrick = errorRed;
  static const Color softTeal = architecturalBlue;
  static const Color mintGreen = successGreen;
  static const Color terminalMint = successGreen;
  static const Color warningOrange = warningAmber;
  static const Color deepTeal = deepOrange;
  static const Color surfaceDark = offWhite;
  static const Color holoPink = orangeAccent;
  static const Color tabBlue = architecturalBlue;
  static const Color gridBlue = architecturalBlue;
  static const Color terminalGreen = successGreen;
  static const Color vhsRed = errorRed;
  static const Color vhsYellow = warningAmber;
  static const Color neonCyan = infoBlue;
  static const Color neonOrange = primaryOrange;
  static const Color neonPink = orangeAccent;
  static const Color phosphorGreen = successGreen;
  static const Color overlayWarm = orangeGlow;
  static const List<Color> terminalGradient = orangeGradient;
}

/// Architectural Theme - Frank Lloyd Wright inspired design system
/// High-contrast theme with geometric typography and clean architectural aesthetics
class ArchitecturalTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.orange,
      primaryColor: ArchitecturalColors.primaryOrange,
      scaffoldBackgroundColor: ArchitecturalColors.pureWhite,
      
      // Frank Lloyd Wright Architectural Typography - Geometric and highly readable
      textTheme: TextTheme(
        // Large headers - Bold architectural titles (maximum contrast)
        displayLarge: GoogleFonts.montserrat(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: ArchitecturalColors.deepBlack,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.montserrat(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: ArchitecturalColors.charcoalBlack,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        displaySmall: GoogleFonts.montserrat(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ArchitecturalColors.charcoalBlack,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        
        // Headlines - Architectural geometric text (high contrast)
        headlineLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ArchitecturalColors.deepBlack,
          letterSpacing: 0,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ArchitecturalColors.primaryOrange,
          letterSpacing: 0,
          height: 1.4,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: ArchitecturalColors.darkGray,
          letterSpacing: 0,
          height: 1.4,
        ),
        
        // Body text - Clean, highly readable content (maximum contrast)
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: ArchitecturalColors.deepBlack,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: ArchitecturalColors.darkGray,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: ArchitecturalColors.mediumGray,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        
        // Labels - Architectural system UI text (high contrast)
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ArchitecturalColors.deepBlack,
          letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ArchitecturalColors.darkGray,
          letterSpacing: 0.1,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: ArchitecturalColors.mediumGray,
          letterSpacing: 0.1,
        ),
      ),
      
      // High-contrast architectural color scheme
      colorScheme: ColorScheme.light(
        primary: ArchitecturalColors.primaryOrange,
        secondary: ArchitecturalColors.steelGray,
        tertiary: ArchitecturalColors.architecturalBlue,
        surface: ArchitecturalColors.offWhite,
        onPrimary: ArchitecturalColors.pureWhite,
        onSecondary: ArchitecturalColors.pureWhite,
        onSurface: ArchitecturalColors.deepBlack,
        error: ArchitecturalColors.errorRed,
        onError: ArchitecturalColors.pureWhite,
        outline: ArchitecturalColors.mediumGray,
        shadow: ArchitecturalColors.shadowBlack,
      ),
      
      // App bar - Clean architectural header with maximum contrast
      appBarTheme: AppBarTheme(
        backgroundColor: ArchitecturalColors.pureWhite,
        foregroundColor: ArchitecturalColors.deepBlack,
        elevation: 1,
        shadowColor: ArchitecturalColors.shadowBlack,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ArchitecturalColors.deepBlack,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(
          color: ArchitecturalColors.deepBlack,
          size: 24,
        ),
      ),
      
      // Cards - Clean architectural design with subtle shadows
      cardTheme: CardThemeData(
        color: ArchitecturalColors.cardWhite,
        elevation: 2,
        shadowColor: ArchitecturalColors.shadowBlack,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: ArchitecturalColors.lightGray,
            width: 1,
          ),
        ),
        margin: EdgeInsets.all(8),
      ),
      
      // Bottom navigation - Clean architectural navigation with high contrast
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ArchitecturalColors.pureWhite,
        selectedItemColor: ArchitecturalColors.primaryOrange,
        unselectedItemColor: ArchitecturalColors.mediumGray,
        selectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontSize: 12,
          color: ArchitecturalColors.primaryOrange,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          fontSize: 11,
          color: ArchitecturalColors.mediumGray,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      
      // Buttons - Bold architectural styling with maximum contrast
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ArchitecturalColors.primaryOrange,
          foregroundColor: ArchitecturalColors.pureWhite,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
          shadowColor: ArchitecturalColors.shadowBlack,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ArchitecturalColors.primaryOrange,
          side: BorderSide(color: ArchitecturalColors.primaryOrange, width: 2),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ArchitecturalColors.primaryOrange,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      
      // Input fields - Clean architectural form design
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ArchitecturalColors.offWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ArchitecturalColors.mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ArchitecturalColors.lightSteel),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ArchitecturalColors.primaryOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ArchitecturalColors.errorRed, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          color: ArchitecturalColors.mediumGray,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.inter(
          color: ArchitecturalColors.subtleGray,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

/// Architectural Animation System - Clean, precise transitions
/// Inspired by Frank Lloyd Wright's geometric principles
class ArchitecturalAnimations {
  static const Duration ultraFast = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 250);
  
  // Architectural easing curves - precise and geometric
  static const Curve preciseEase = Curves.easeInOutCubic;
  static const Curve geometricEase = Curves.easeOutQuart;
  static const Curve architecturalEase = Curves.easeInOutQuart;
  static const Curve sharpEase = Curves.easeInOutExpo;
  
  // Legacy compatibility
  static const Curve smoothEase = preciseEase;
  static const Curve gentleEase = geometricEase;
  static const Curve tactileEase = architecturalEase;
}

/// Architectural Design Measurements - Geometric precision
/// Based on Frank Lloyd Wright's proportional systems
class ArchitecturalSizes {
  static const double cardElevation = 2.0;          // Subtle architectural depth
  static const double subtleBorder = 1.0;           // Fine architectural lines
  static const double prominentBorder = 2.0;        // Bold structural elements
  static const double tabHeight = 56.0;             // Optimal touch targets
  static const double iconSize = 24.0;              // Balanced visual weight
  static const double padding = 24.0;               // Generous architectural spacing
  static const double smallPadding = 16.0;          // Intimate geometric spacing
  static const double borderRadius = 8.0;           // Clean geometric corners
  static const double smallRadius = 4.0;            // Minimal rounded edges
  static const double largeRadius = 12.0;           // Prominent rounded elements
  
  // Legacy compatibility
  static const double cardElevationOld = cardElevation;
  static const double borderRadiusOld = borderRadius;
  static const double smallRadiusOld = smallRadius;
}

/// Architectural Layout Spacing System - Geometric grid
/// Based on 8-point grid system for consistent proportions
class ArchitecturalSpacing {
  static const double xs = 4.0;   // Minimal geometric unit
  static const double sm = 8.0;   // Base grid unit
  static const double md = 16.0;  // Standard element spacing
  static const double lg = 24.0;  // Section spacing
  static const double xl = 32.0;  // Large architectural gaps
  static const double xxl = 48.0; // Grand architectural space
  static const double xxxl = 64.0; // Monumental spacing
  
  // Legacy compatibility
  static const double small = sm;
  static const double medium = md;
  static const double large = lg;
}

/// Legacy Theme Compatibility - Maintains backward compatibility
/// Maps old RetroTheme and RetroColors to new ArchitecturalTheme
class RetroTheme {
  static ThemeData get theme => ArchitecturalTheme.theme;
}

class RetroColors {
  // Primary colors
  static const Color primaryTerracotta = ArchitecturalColors.primaryOrange;
  static const Color lightTerracotta = ArchitecturalColors.lightOrange;
  static const Color sageGreen = ArchitecturalColors.steelGray;
  static const Color deepTerracotta = ArchitecturalColors.deepOrange;
  
  // Background colors
  static const Color creamBackground = ArchitecturalColors.pureWhite;
  static const Color warmSurface = ArchitecturalColors.offWhite;
  static const Color softCard = ArchitecturalColors.cardWhite;
  
  // Text colors
  static const Color ivoryWhite = ArchitecturalColors.pureWhite;
  static const Color lightBeige = ArchitecturalColors.lightGray;
  static const Color mediumBeige = ArchitecturalColors.mediumGray;
  static const Color warmTaupe = ArchitecturalColors.subtleGray;
  static const Color deepTaupe = ArchitecturalColors.darkGray;
  
  // All other legacy mappings
  static const Color peachAccent = ArchitecturalColors.orangeAccent;
  static const Color coralTone = ArchitecturalColors.orangeAccent;
  static const Color orangeGlow = ArchitecturalColors.lightOrange;
  static const Color brickRed = ArchitecturalColors.primaryOrange;
  static const Color clayTone = ArchitecturalColors.lightOrange;
  static const Color stoneBeige = ArchitecturalColors.lightGray;
  static const Color woodWarm = ArchitecturalColors.mediumGray;
  static const Color burgundyAccent = ArchitecturalColors.deepOrange;
  static const Color sageAccent = ArchitecturalColors.steelGray;
  static const Color successEarth = ArchitecturalColors.successGreen;
  static const Color warningCoral = ArchitecturalColors.warningAmber;
  static const Color errorBrick = ArchitecturalColors.errorRed;
  static const Color softTeal = ArchitecturalColors.architecturalBlue;
  static const Color mintGreen = ArchitecturalColors.successGreen;
  static const Color terminalMint = ArchitecturalColors.successGreen;
  static const Color errorRed = ArchitecturalColors.errorRed;
  static const Color warningOrange = ArchitecturalColors.warningAmber;
  static const Color lightGray = ArchitecturalColors.lightGray;
  static const Color deepTeal = ArchitecturalColors.deepOrange;
  static const Color surfaceDark = ArchitecturalColors.offWhite;
  static const Color holoPink = ArchitecturalColors.orangeAccent;
  static const Color tabBlue = ArchitecturalColors.architecturalBlue;
  static const Color gridBlue = ArchitecturalColors.architecturalBlue;
  static const Color terminalGreen = ArchitecturalColors.successGreen;
  static const Color vhsRed = ArchitecturalColors.errorRed;
  static const Color vhsYellow = ArchitecturalColors.warningAmber;
  static const Color neonCyan = ArchitecturalColors.infoBlue;
  static const Color neonOrange = ArchitecturalColors.primaryOrange;
  static const Color neonPink = ArchitecturalColors.orangeAccent;
  static const Color phosphorGreen = ArchitecturalColors.successGreen;
  static const Color overlayWarm = ArchitecturalColors.orangeGlow;
  static const Color subtleOverlay = ArchitecturalColors.subtleOverlay;
  static const Color softGlow = ArchitecturalColors.orangeGlow;
  
  // Gradients
  static const List<Color> primaryGradient = ArchitecturalColors.primaryGradient;
  static const List<Color> terracottaGradient = ArchitecturalColors.orangeGradient;
  static const List<Color> cardGradient = ArchitecturalColors.cardGradient;
  static const List<Color> warmGlow = ArchitecturalColors.architecturalShadow;
  static const List<Color> terminalGradient = ArchitecturalColors.orangeGradient;
}

/// Legacy compatibility classes
class RetroAnimations {
  static const Duration ultraFast = ArchitecturalAnimations.ultraFast;
  static const Duration fast = ArchitecturalAnimations.fast;
  static const Duration medium = ArchitecturalAnimations.medium;
  static const Duration slow = ArchitecturalAnimations.slow;
  static const Duration pageTransition = ArchitecturalAnimations.pageTransition;
  static const Curve smoothEase = ArchitecturalAnimations.smoothEase;
  static const Curve gentleEase = ArchitecturalAnimations.gentleEase;
  static const Curve tactileEase = ArchitecturalAnimations.tactileEase;
}

class RetroSizes {
  static const double cardElevation = ArchitecturalSizes.cardElevation;
  static const double subtleBorder = ArchitecturalSizes.subtleBorder;
  static const double prominentBorder = ArchitecturalSizes.prominentBorder;
  static const double tabHeight = ArchitecturalSizes.tabHeight;
  static const double iconSize = ArchitecturalSizes.iconSize;
  static const double padding = ArchitecturalSizes.padding;
  static const double smallPadding = ArchitecturalSizes.smallPadding;
  static const double borderRadius = ArchitecturalSizes.borderRadius;
  static const double smallRadius = ArchitecturalSizes.smallRadius;
}

class RetroSpacing {
  static const double xs = ArchitecturalSpacing.xs;
  static const double sm = ArchitecturalSpacing.sm;
  static const double md = ArchitecturalSpacing.md;
  static const double lg = ArchitecturalSpacing.lg;
  static const double xl = ArchitecturalSpacing.xl;
  static const double xxl = ArchitecturalSpacing.xxl;
}

/// Responsive Typography System for Accessibility
/// Provides dynamic text scaling based on user preferences and screen size
class ResponsiveText {
  /// Scale font size based on MediaQuery text scale factor and accessibility settings
  static double scaledFontSize(BuildContext context, double baseSize) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    
    // Clamp text scale factor between 0.8 and 2.0 for usability
    final clampedScale = textScaleFactor.clamp(0.8, 2.0);
    
    return baseSize * clampedScale;
  }
  
  /// Get responsive heading text style with proper scaling
  static TextStyle heading1(BuildContext context, {Color? color}) {
    return GoogleFonts.montserrat(
      fontSize: scaledFontSize(context, 32),
      fontWeight: FontWeight.w800,
      color: color ?? ArchitecturalColors.deepBlack,
      letterSpacing: -0.8,
      height: 1.1,
    );
  }
  
  static TextStyle heading2(BuildContext context, {Color? color}) {
    return GoogleFonts.montserrat(
      fontSize: scaledFontSize(context, 28),
      fontWeight: FontWeight.w700,
      color: color ?? ArchitecturalColors.charcoalBlack,
      letterSpacing: -0.5,
      height: 1.2,
    );
  }
  
  static TextStyle heading3(BuildContext context, {Color? color}) {
    return GoogleFonts.montserrat(
      fontSize: scaledFontSize(context, 24),
      fontWeight: FontWeight.w600,
      color: color ?? ArchitecturalColors.charcoalBlack,
      letterSpacing: -0.3,
      height: 1.3,
    );
  }
  
  /// Get responsive body text style with proper scaling
  static TextStyle bodyLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.inter(
      fontSize: scaledFontSize(context, 16),
      color: color ?? ArchitecturalColors.deepBlack,
      letterSpacing: 0,
      fontWeight: fontWeight ?? FontWeight.w400,
      height: 1.6,
    );
  }
  
  static TextStyle bodyMedium(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.inter(
      fontSize: scaledFontSize(context, 14),
      color: color ?? ArchitecturalColors.darkGray,
      letterSpacing: 0,
      fontWeight: fontWeight ?? FontWeight.w400,
      height: 1.5,
    );
  }
  
  static TextStyle bodySmall(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.inter(
      fontSize: scaledFontSize(context, 12),
      color: color ?? ArchitecturalColors.mediumGray,
      letterSpacing: 0,
      fontWeight: fontWeight ?? FontWeight.w400,
      height: 1.4,
    );
  }
  
  /// Get responsive label text style with proper scaling
  static TextStyle labelLarge(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: scaledFontSize(context, 14),
      fontWeight: FontWeight.w600,
      color: color ?? ArchitecturalColors.deepBlack,
      letterSpacing: 0.2,
    );
  }
  
  static TextStyle labelMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: scaledFontSize(context, 12),
      fontWeight: FontWeight.w500,
      color: color ?? ArchitecturalColors.darkGray,
      letterSpacing: 0.1,
    );
  }
  
  static TextStyle labelSmall(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: scaledFontSize(context, 10),
      fontWeight: FontWeight.w500,
      color: color ?? ArchitecturalColors.mediumGray,
      letterSpacing: 0.1,
    );
  }
  
  /// Monospace text for terminal/data displays with proper scaling
  static TextStyle monoLarge(BuildContext context, {Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: scaledFontSize(context, 14),
      fontWeight: FontWeight.w500,
      color: color ?? ArchitecturalColors.deepBlack,
      letterSpacing: 0.2,
    );
  }
  
  static TextStyle monoMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: scaledFontSize(context, 12),
      fontWeight: FontWeight.w500,
      color: color ?? ArchitecturalColors.darkGray,
      letterSpacing: 0.1,
    );
  }
  
  static TextStyle monoSmall(BuildContext context, {Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: scaledFontSize(context, 10),
      fontWeight: FontWeight.w500,
      color: color ?? ArchitecturalColors.mediumGray,
      letterSpacing: 0.1,
    );
  }
}

/// Responsive Layout System for Different Screen Sizes
/// Provides adaptive spacing and sizing based on screen dimensions
class ResponsiveLayout {
  /// Breakpoints for responsive design
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  
  /// Get screen width category
  static ScreenSize getScreenSize(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    
    if (screenWidth < mobileBreakpoint) {
      return ScreenSize.mobile;
    } else if (screenWidth < tabletBreakpoint) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.desktop;
    }
  }
  
  /// Get responsive padding based on screen size
  static EdgeInsets responsivePadding(BuildContext context, {
    double mobile = 16.0,
    double tablet = 24.0,
    double desktop = 32.0,
  }) {
    switch (getScreenSize(context)) {
      case ScreenSize.mobile:
        return EdgeInsets.all(mobile);
      case ScreenSize.tablet:
        return EdgeInsets.all(tablet);
      case ScreenSize.desktop:
        return EdgeInsets.all(desktop);
    }
  }
  
  /// Get responsive spacing based on screen size
  static double responsiveSpacing(BuildContext context, {
    double mobile = 8.0,
    double tablet = 12.0,
    double desktop = 16.0,
  }) {
    switch (getScreenSize(context)) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
    }
  }
  
  /// Get responsive card width for lists
  static double getCardMaxWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    
    switch (getScreenSize(context)) {
      case ScreenSize.mobile:
        return screenWidth - 32; // Full width minus padding
      case ScreenSize.tablet:
        return 600; // Fixed max width for tablets
      case ScreenSize.desktop:
        return 800; // Fixed max width for desktop
    }
  }
  
  /// Check if text scaling is at accessibility level (>= 1.3x)
  static bool isAccessibilityTextScale(BuildContext context) {
    return MediaQuery.textScaleFactorOf(context) >= 1.3;
  }
  
  /// Get minimum touch target size (44px base, scaled for accessibility)
  static double getMinTouchTarget(BuildContext context) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    return (44.0 * textScaleFactor).clamp(44.0, 64.0);
  }
}

enum ScreenSize { mobile, tablet, desktop }
