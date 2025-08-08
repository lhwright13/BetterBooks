import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Space Command Theme Colors - Retro Space-Race Aesthetic
/// Inspired by vintage space missions and command centers - dusty reds, golden yellows, teal blues
class SpaceColors {
  // PRIMARY: Dusty Reds (Mission Command)
  static const Color dustyRed = Color(0xFFCC6B5A);           // Primary dusty red
  static const Color warmRed = Color(0xFFD85D47);            // Warmer red accent
  static const Color deepRed = Color(0xFFB85A4A);            // Deeper red for emphasis
  static const Color softRed = Color(0xFFE8887A);            // Soft red highlight
  
  // SECONDARY: Golden Yellows (Navigation Systems)
  static const Color goldenYellow = Color(0xFFE6B847);       // Primary golden yellow
  static const Color deepGold = Color(0xFFD4A328);           // Deep gold accent
  static const Color lightGold = Color(0xFFF2C95D);          // Light gold highlight
  static const Color amberGlow = Color(0xFFEEC64A);          // Amber glow effect
  
  // TERTIARY: Teal Blues (Communication Arrays)
  static const Color tealBlue = Color(0xFF4A9B9B);           // Primary teal blue
  static const Color cyanBlue = Color(0xFF6BB6B6);           // Cyan blue accent
  static const Color deepTeal = Color(0xFF5C9999);           // Deep teal variant
  static const Color softCyan = Color(0xFF8BCCCC);           // Soft cyan highlight
  
  // BACKGROUNDS: Cream Command Center (Warm Neutrals)
  static const Color creamBg = Color(0xFFF5F1E8);            // Primary cream background
  static const Color warmBeige = Color(0xFFEDE7D3);          // Warm beige surface
  static const Color lightCream = Color(0xFFFAF6ED);         // Light cream cards
  static const Color ivoryWhite = Color(0xFFFEFCF5);         // Ivory white highlights
  
  // TEXT: Mission Control Interface (High Contrast for Readability)
  static const Color missionBlack = Color(0xFF2C2C2C);       // Primary text (mission readouts)
  static const Color commandGray = Color(0xFF4A4A4A);        // Secondary text (system info)
  static const Color systemGray = Color(0xFF666666);         // Tertiary text (labels)
  static const Color subtleGray = Color(0xFF888888);         // Subtle text (hints)
  static const Color darkSpace = Color(0xFF1A1A1A);          // Deep space black
  
  // ACCENTS: Space Mission Elements
  static const Color rocketSilver = Color(0xFF9CA3AF);       // Metallic accents
  static const Color starWhite = Color(0xFFF9FAFB);          // Bright highlights
  static const Color nebulaBlue = Color(0xFF3B82F6);         // Information blue
  static const Color solarOrange = Color(0xFFF97316);        // Warning/energy orange
  
  // FUNCTIONAL COLORS: Mission Status Indicators
  static const Color successGreen = Color(0xFF10B981);       // Mission success
  static const Color warningAmber = Color(0xFFD4A328);       // Caution status  
  static const Color errorRed = Color(0xFFEF4444);           // Critical alert
  static const Color infoTeal = Color(0xFF4A9B9B);           // Information status
  
  // SHADOWS AND OVERLAYS: Atmospheric Depth
  static const Color spaceShadow = Color(0x1A000000);        // Subtle space shadow
  static const Color orbitGlow = Color(0x20CC6B5A);          // Dusty red orbital glow
  static const Color stellarOverlay = Color(0x0F4A9B9B);     // Teal stellar overlay
  static const Color cosmicMist = Color(0x0AE6B847);         // Golden cosmic mist
  
  // GRADIENTS: Space Atmospheric Effects
  static const List<Color> commandGradient = [
    Color(0xFFF5F1E8),  // Cream background
    Color(0xFFEDE7D3),  // Warm beige
    Color(0xFFFAF6ED),  // Light cream
  ];
  
  static const List<Color> dustyRedGradient = [
    Color(0xFFD85D47),  // Warm red
    Color(0xFFCC6B5A),  // Dusty red
  ];
  
  static const List<Color> goldenGradient = [
    Color(0xFFF2C95D),  // Light gold
    Color(0xFFE6B847),  // Golden yellow
    Color(0xFFD4A328),  // Deep gold
  ];
  
  static const List<Color> tealGradient = [
    Color(0xFF8BCCCC),  // Soft cyan
    Color(0xFF6BB6B6),  // Cyan blue
    Color(0xFF4A9B9B),  // Teal blue
  ];
  
  static const List<Color> spaceDepthGradient = [
    Color(0x1A000000),  // Space shadow
    Color(0x0D000000),  // Lighter shadow
    Color(0x00000000),  // Transparent
  ];
  
  // LEGACY MAPPINGS: Backward Compatibility with Old Architectural Theme
  static const Color primaryTerracotta = dustyRed;
  static const Color lightTerracotta = warmRed;
  static const Color sageGreen = tealBlue;
  static const Color deepTerracotta = deepRed;
  static const Color creamBackground = creamBg;
  static const Color warmSurface = warmBeige;
  static const Color softCard = lightCream;
  static const Color lightBeige = systemGray;
  static const Color mediumBeige = commandGray;
  static const Color warmTaupe = subtleGray;
  static const Color deepTaupe = missionBlack;
  static const Color peachAccent = softRed;
  static const Color coralTone = warmRed;
  static const Color orangeGlowOld = amberGlow;
  static const Color brickRed = dustyRed;
  static const Color clayTone = goldenYellow;
  static const Color stoneBeige = warmBeige;
  static const Color woodWarm = commandGray;
  static const Color burgundyAccent = deepRed;
  static const Color sageAccent = tealBlue;
  static const Color successEarth = successGreen;
  static const Color warningCoral = warningAmber;
  static const Color errorBrick = errorRed;
  static const Color softTeal = cyanBlue;
  static const Color mintGreen = successGreen;
  static const Color terminalMint = cyanBlue;
  static const Color warningOrange = solarOrange;
  static const Color deepTealOld = deepTeal;
  static const Color surfaceDark = warmBeige;
  static const Color holoPink = softRed;
  static const Color tabBlue = tealBlue;
  static const Color gridBlue = nebulaBlue;
  static const Color terminalGreen = successGreen;
  static const Color vhsRed = errorRed;
  static const Color vhsYellow = goldenYellow;
  static const Color neonCyan = cyanBlue;
  static const Color neonOrange = solarOrange;
  static const Color neonPink = softRed;
  static const Color phosphorGreen = successGreen;
  static const Color overlayWarm = orbitGlow;
  static const List<Color> terminalGradient = dustyRedGradient;
}

/// Legacy Architectural Colors - Kept for Backward Compatibility
/// Will be gradually phased out in favor of SpaceColors
class ArchitecturalColors {
  // Map all architectural colors to space theme equivalents
  static const Color primaryOrange = SpaceColors.dustyRed;
  static const Color lightOrange = SpaceColors.warmRed;
  static const Color deepOrange = SpaceColors.deepRed;
  static const Color orangeAccent = SpaceColors.softRed;
  static const Color pureWhite = SpaceColors.ivoryWhite;
  static const Color offWhite = SpaceColors.lightCream;
  static const Color lightGray = SpaceColors.warmBeige;
  static const Color cardWhite = SpaceColors.creamBg;
  static const Color deepBlack = SpaceColors.darkSpace;
  static const Color charcoalBlack = SpaceColors.missionBlack;
  static const Color darkGray = SpaceColors.commandGray;
  static const Color mediumGray = SpaceColors.systemGray;
  static const Color subtleGray = SpaceColors.subtleGray;
  static const Color steelGray = SpaceColors.rocketSilver;
  static const Color lightSteel = SpaceColors.starWhite;
  static const Color architecturalBlue = SpaceColors.nebulaBlue;
  static const Color concreteGray = SpaceColors.systemGray;
  static const Color successGreen = SpaceColors.successGreen;
  static const Color warningAmber = SpaceColors.warningAmber;
  static const Color errorRed = SpaceColors.errorRed;
  static const Color infoBlue = SpaceColors.infoTeal;
  static const Color shadowBlack = SpaceColors.spaceShadow;
  static const Color overlayBlack = Color(0x80000000);
  static const Color subtleOverlay = SpaceColors.stellarOverlay;
  static const Color orangeGlow = SpaceColors.orbitGlow;
  
  static const List<Color> primaryGradient = SpaceColors.commandGradient;
  static const List<Color> orangeGradient = SpaceColors.dustyRedGradient;
  static const List<Color> cardGradient = SpaceColors.commandGradient;
  static const List<Color> architecturalShadow = SpaceColors.spaceDepthGradient;
}

/// Space Command Theme - Retro Space-Race Mission Control Design System
/// Inspired by vintage space missions with dusty reds, golden yellows, and teal blues
class SpaceTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.red,
      primaryColor: SpaceColors.dustyRed,
      scaffoldBackgroundColor: SpaceColors.creamBg,
      
      // Space Mission Typography - Clean, technical readouts for command interfaces
      textTheme: TextTheme(
        // Large headers - Mission command titles (high contrast)
        displayLarge: GoogleFonts.orbitron(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: SpaceColors.darkSpace,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.orbitron(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: SpaceColors.missionBlack,
          letterSpacing: -0.3,
          height: 1.2,
        ),
        displaySmall: GoogleFonts.orbitron(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: SpaceColors.dustyRed,
          letterSpacing: 0,
          height: 1.3,
        ),
        
        // Headlines - System interface text (mission control style)
        headlineLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: SpaceColors.missionBlack,
          letterSpacing: 0.1,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: SpaceColors.dustyRed,
          letterSpacing: 0,
          height: 1.4,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: SpaceColors.commandGray,
          letterSpacing: 0,
          height: 1.4,
        ),
        
        // Body text - Technical readouts and content (high contrast)
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: SpaceColors.missionBlack,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: SpaceColors.commandGray,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: SpaceColors.systemGray,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        
        // Labels - System UI text (technical interface style)
        labelLarge: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: SpaceColors.tealBlue,
          letterSpacing: 0.3,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: SpaceColors.commandGray,
          letterSpacing: 0.2,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: SpaceColors.systemGray,
          letterSpacing: 0.2,
        ),
      ),
      
      // Space command color scheme - Mission control interface
      colorScheme: ColorScheme.light(
        primary: SpaceColors.dustyRed,
        secondary: SpaceColors.tealBlue,
        tertiary: SpaceColors.goldenYellow,
        surface: SpaceColors.lightCream,
        onPrimary: SpaceColors.ivoryWhite,
        onSecondary: SpaceColors.ivoryWhite,
        onSurface: SpaceColors.missionBlack,
        error: SpaceColors.errorRed,
        onError: SpaceColors.ivoryWhite,
        outline: SpaceColors.systemGray,
        shadow: SpaceColors.spaceShadow,
        surfaceContainer: SpaceColors.warmBeige,
        onSurfaceVariant: SpaceColors.commandGray,
      ),
      
      // App bar - Mission control header interface
      appBarTheme: AppBarTheme(
        backgroundColor: SpaceColors.creamBg,
        foregroundColor: SpaceColors.darkSpace,
        elevation: 2,
        shadowColor: SpaceColors.spaceShadow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: SpaceColors.dustyRed,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(
          color: SpaceColors.tealBlue,
          size: 24,
        ),
      ),
      
      // Cards - Space command panel design with atmospheric glow
      cardTheme: CardThemeData(
        color: SpaceColors.lightCream,
        elevation: 3,
        shadowColor: SpaceColors.spaceShadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: SpaceColors.dustyRed.withOpacity(0.2),
            width: 1,
          ),
        ),
        margin: EdgeInsets.all(8),
      ),
      
      // Bottom navigation - Mission control navigation panel
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: SpaceColors.warmBeige,
        selectedItemColor: SpaceColors.dustyRed,
        unselectedItemColor: SpaceColors.systemGray,
        selectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          fontSize: 12,
          color: SpaceColors.dustyRed,
        ),
        unselectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          fontSize: 11,
          color: SpaceColors.systemGray,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 6,
      ),
      
      // Buttons - Mission control styling with atmospheric glow effects
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SpaceColors.dustyRed,
          foregroundColor: SpaceColors.ivoryWhite,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: SpaceColors.orbitGlow,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpaceColors.tealBlue,
          side: BorderSide(color: SpaceColors.tealBlue, width: 2),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SpaceColors.goldenYellow,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      
      // Input fields - Mission control interface form design
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SpaceColors.lightCream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: SpaceColors.systemGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: SpaceColors.rocketSilver),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: SpaceColors.tealBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: SpaceColors.errorRed, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          color: SpaceColors.commandGray,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.inter(
          color: SpaceColors.subtleGray,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

/// Legacy Architectural Theme - Maps to Space Theme for Backward Compatibility
/// This ensures existing code continues to work while gradually migrating to SpaceTheme
class ArchitecturalTheme {
  static ThemeData get theme => SpaceTheme.theme;
}

/// Space Mission Animation System - Smooth, orbital transitions
/// Inspired by spacecraft movements and orbital mechanics
class SpaceAnimations {
  static const Duration ultraFast = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration orbit = Duration(milliseconds: 800);
  static const Duration pageTransition = Duration(milliseconds: 350);
  
  // Orbital easing curves - smooth like spacecraft movements
  static const Curve orbitalEase = Curves.easeInOutQuart;
  static const Curve launchEase = Curves.easeOutExpo;
  static const Curve landingEase = Curves.easeInQuart;
  static const Curve floatingEase = Curves.easeInOutSine;
  
  // Legacy compatibility
  static const Curve preciseEase = orbitalEase;
  static const Curve geometricEase = launchEase;
  static const Curve architecturalEase = orbitalEase;
  static const Curve sharpEase = landingEase;
  static const Curve smoothEase = orbitalEase;
  static const Curve gentleEase = floatingEase;
  static const Curve tactileEase = orbitalEase;
}

/// Legacy Architectural Animations - Maps to Space Animations
class ArchitecturalAnimations {
  static const Duration ultraFast = SpaceAnimations.ultraFast;
  static const Duration fast = SpaceAnimations.fast;
  static const Duration medium = SpaceAnimations.medium;
  static const Duration slow = SpaceAnimations.slow;
  static const Duration pageTransition = SpaceAnimations.pageTransition;
  static const Curve preciseEase = SpaceAnimations.preciseEase;
  static const Curve geometricEase = SpaceAnimations.geometricEase;
  static const Curve architecturalEase = SpaceAnimations.architecturalEase;
  static const Curve sharpEase = SpaceAnimations.sharpEase;
  static const Curve smoothEase = SpaceAnimations.smoothEase;
  static const Curve gentleEase = SpaceAnimations.gentleEase;
  static const Curve tactileEase = SpaceAnimations.tactileEase;
}

/// Space Mission Design Measurements - Orbital proportions
/// Based on spacecraft and space station interface design
class SpaceSizes {
  static const double panelElevation = 4.0;         // Command panel depth
  static const double subtleBorder = 1.5;           // Sensor array lines
  static const double prominentBorder = 3.0;        // Primary interface elements
  static const double controlHeight = 58.0;         // Optimal control targets
  static const double iconSize = 24.0;              // Navigation element size
  static const double padding = 20.0;               // Mission control spacing
  static const double smallPadding = 12.0;          // Component spacing
  static const double borderRadius = 12.0;          // Rounded display corners
  static const double smallRadius = 6.0;            // Minor interface rounding
  static const double largeRadius = 16.0;           // Major panel rounding
  static const double orbitRadius = 24.0;           // Circular control elements
  
  // Legacy compatibility
  static const double cardElevation = panelElevation;
  static const double tabHeight = controlHeight;
  static const double cardElevationOld = panelElevation;
  static const double borderRadiusOld = borderRadius;
  static const double smallRadiusOld = smallRadius;
}

/// Legacy Architectural Sizes - Maps to Space Sizes
class ArchitecturalSizes {
  static const double cardElevation = SpaceSizes.panelElevation;
  static const double subtleBorder = SpaceSizes.subtleBorder;
  static const double prominentBorder = SpaceSizes.prominentBorder;
  static const double tabHeight = SpaceSizes.controlHeight;
  static const double iconSize = SpaceSizes.iconSize;
  static const double padding = SpaceSizes.padding;
  static const double smallPadding = SpaceSizes.smallPadding;
  static const double borderRadius = SpaceSizes.borderRadius;
  static const double smallRadius = SpaceSizes.smallRadius;
  static const double largeRadius = SpaceSizes.largeRadius;
  static const double cardElevationOld = SpaceSizes.panelElevation;
  static const double borderRadiusOld = SpaceSizes.borderRadius;
  static const double smallRadiusOld = SpaceSizes.smallRadius;
}

/// Space Mission Layout Spacing System - Orbital grid
/// Based on spacecraft interface spacing for optimal readability
class SpaceSpacing {
  static const double xs = 6.0;   // Minimal component gap
  static const double sm = 12.0;  // Base control spacing
  static const double md = 18.0;  // Standard panel spacing
  static const double lg = 24.0;  // Section dividers
  static const double xl = 36.0;  // Major interface gaps  
  static const double xxl = 48.0; // Mission section spacing
  static const double xxxl = 64.0; // Command center spacing
  
  // Legacy compatibility
  static const double small = sm;
  static const double medium = md;
  static const double large = lg;
}

/// Legacy Architectural Spacing - Maps to Space Spacing
class ArchitecturalSpacing {
  static const double xs = SpaceSpacing.xs;
  static const double sm = SpaceSpacing.sm;
  static const double md = SpaceSpacing.md;
  static const double lg = SpaceSpacing.lg;
  static const double xl = SpaceSpacing.xl;
  static const double xxl = SpaceSpacing.xxl;
  static const double xxxl = SpaceSpacing.xxxl;
  static const double small = SpaceSpacing.small;
  static const double medium = SpaceSpacing.medium;
  static const double large = SpaceSpacing.large;
}

/// Legacy Theme Compatibility - Maintains backward compatibility  
/// Maps old RetroTheme and RetroColors to new SpaceTheme
class RetroTheme {
  static ThemeData get theme => SpaceTheme.theme;
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
  static const Color deepTealRetro = ArchitecturalColors.deepOrange;
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
