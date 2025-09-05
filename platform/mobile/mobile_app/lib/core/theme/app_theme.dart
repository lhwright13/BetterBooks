import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EchoWright Application Theme
/// 
/// WCAG AA compliant theme with proper color contrast ratios:
/// - Primary Yellow (#F1CF47) for headers, footers, and accents
/// - Pastel Gray-Blue (#B0B8CE) for backgrounds
/// - Pure Black (#000000) for text
/// - Clean and accessible color palette
/// - Material Design 3 components
class AppTheme {
  // EchoWright Brand Colors (WCAG AA Compliant)
  static const Color primaryYellow = Color(0xFFF1CF47); // Brand yellow for headers/accents
  static const Color backgroundGrayBlue = Color(0xFFB0B8CE); // Pastel gray-blue backgrounds
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Pure white for cards
  static const Color surfaceDark = Color(0xFF2A2A2A); // Dark mode surface
  static const Color secondaryGrayBlue = Color(0xFF8A93A8); // Darker gray-blue for borders
  
  // Text Colors (High Contrast)
  static const Color textPrimary = Color(0xFF000000); // Pure black text
  static const Color textSecondary = Color(0xFF333333); // Dark gray for secondary text
  static const Color textMuted = Color(0xFF666666); // Medium gray for muted text
  static const Color textOnYellow = Color(0xFF000000); // Black text on yellow
  static const Color textOnDark = Color(0xFFFFFFFF); // White text on dark
  
  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      colorScheme: ColorScheme.light(
        primary: primaryYellow,
        secondary: secondaryGrayBlue,
        tertiary: primaryYellow,
        surface: surfaceWhite,
        onPrimary: textOnYellow,
        onSecondary: textPrimary,
        onTertiary: textOnYellow,
        onSurface: textPrimary,
        error: errorColor,
        outline: secondaryGrayBlue,
      ),
      
      scaffoldBackgroundColor: backgroundGrayBlue, // Gray-blue background
      
      textTheme: GoogleFonts.interTextTheme().copyWith(
        // Clean typography with black text
        headlineLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary, // Black
          letterSpacing: 0.5,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary, // Black
          letterSpacing: 0.25,
          height: 1.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary, // Black
          letterSpacing: 0.15,
          height: 1.5,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary, // Black
          letterSpacing: 0.1,
          height: 1.5,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textSecondary, // Dark gray
          letterSpacing: 0.5,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary, // Dark gray
          letterSpacing: 0.25,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textMuted, // Medium gray
          letterSpacing: 0.4,
          height: 1.6,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 2,
        shadowColor: secondaryGrayBlue.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow, // Yellow buttons
          foregroundColor: textOnYellow, // Black text on yellow
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: primaryYellow, // Yellow app bar
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textOnYellow, // Black text on yellow
          letterSpacing: 0.15,
          height: 1.3,
        ),
        iconTheme: IconThemeData(color: textOnYellow), // Black icons on yellow
      ),
      
      tabBarTheme: TabBarThemeData(
        labelColor: textOnYellow, // Black text for active tabs
        unselectedLabelColor: textOnYellow.withOpacity(0.6), // Faded black for inactive
        indicatorColor: textOnYellow, // Black underline indicator
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      colorScheme: ColorScheme.dark(
        primary: primaryYellow,
        secondary: secondaryGrayBlue,
        tertiary: primaryYellow,
        surface: surfaceDark,
        onPrimary: textOnYellow, // Black text on yellow
        onSecondary: textOnDark, // White text on dark
        onTertiary: textOnYellow, // Black text on yellow
        onSurface: textOnDark, // White text on dark
        error: errorColor,
        outline: secondaryGrayBlue,
      ),
      
      scaffoldBackgroundColor: surfaceDark,
      
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        // Clean typography for dark theme
        headlineLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: primaryYellow, // Yellow headings in dark mode
          letterSpacing: 0.5,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textOnDark, // White text
          letterSpacing: 0.25,
          height: 1.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textOnDark, // White text
          letterSpacing: 0.15,
          height: 1.5,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textOnDark, // White text
          letterSpacing: 0.1,
          height: 1.5,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textOnDark.withOpacity(0.87),
          letterSpacing: 0.5,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textOnDark.withOpacity(0.70),
          letterSpacing: 0.25,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textOnDark.withOpacity(0.60),
          letterSpacing: 0.4,
          height: 1.6,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: Color(0xFF2D2D2D),
        elevation: 2,
        shadowColor: primaryYellow.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow, // Yellow buttons in dark mode
          foregroundColor: textOnYellow, // Black text on yellow
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: primaryYellow, // Yellow app bar in dark mode too
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textOnYellow, // Black text on yellow
          letterSpacing: 0.15,
          height: 1.3,
        ),
        iconTheme: IconThemeData(color: textOnYellow), // Black icons on yellow
      ),
      
      tabBarTheme: TabBarThemeData(
        labelColor: textOnYellow, // Black text for active tabs
        unselectedLabelColor: textOnYellow.withOpacity(0.6), // Faded black for inactive
        indicatorColor: textOnYellow, // Black underline indicator
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),
    );
  }

  // Default theme getter for backwards compatibility
  static ThemeData get theme => lightTheme;
}