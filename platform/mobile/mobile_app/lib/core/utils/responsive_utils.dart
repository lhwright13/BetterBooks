import 'package:flutter/material.dart';

/// Responsive utility class for handling different screen sizes and orientations
class ResponsiveUtils {
  ResponsiveUtils._();
  
  /// Screen size breakpoints
  static const double mobileBreakpoint = 375.0;   // iPhone SE
  static const double tabletBreakpoint = 768.0;   // iPad Mini
  static const double desktopBreakpoint = 1024.0; // iPad Pro
  
  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  /// Get safe area padding
  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
  
  /// Get keyboard insets
  static EdgeInsets viewInsets(BuildContext context) {
    return MediaQuery.of(context).viewInsets;
  }
  
  /// Check if device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
  
  /// Check if device is small (iPhone SE size)
  static bool isSmallScreen(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }
  
  /// Check if device is mobile size
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < tabletBreakpoint;
  }
  
  /// Check if device is tablet size
  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }
  
  /// Check if device is desktop size
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= desktopBreakpoint;
  }
  
  /// Get responsive font size based on screen size
  static double responsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = ResponsiveUtils.screenWidth(context);
    
    if (screenWidth < mobileBreakpoint) {
      return baseSize * 0.9; // Smaller on small screens
    } else if (screenWidth > tabletBreakpoint) {
      return baseSize * 1.1; // Larger on tablets
    }
    return baseSize;
  }
  
  /// Get responsive padding based on screen size
  static EdgeInsets responsivePadding(BuildContext context, {
    double small = 8.0,
    double medium = 16.0,
    double large = 24.0,
  }) {
    if (isSmallScreen(context)) {
      return EdgeInsets.all(small);
    } else if (isTablet(context)) {
      return EdgeInsets.all(large);
    }
    return EdgeInsets.all(medium);
  }
  
  /// Get responsive horizontal padding
  static EdgeInsets responsiveHorizontalPadding(BuildContext context) {
    final width = screenWidth(context);
    
    if (width < mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 12.0);
    } else if (width > tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32.0);
    }
    return const EdgeInsets.symmetric(horizontal: 16.0);
  }
  
  /// Get responsive grid crossAxisCount based on screen size
  static int getGridCrossAxisCount(BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }
  
  /// Get responsive aspect ratio for grid items
  static double getGridAspectRatio(BuildContext context, {
    double mobile = 0.7,
    double tablet = 0.8,
  }) {
    return isTablet(context) ? tablet : mobile;
  }
  
  /// Get responsive height as percentage of screen height
  static double getHeightPercent(BuildContext context, double percent) {
    return screenHeight(context) * percent;
  }
  
  /// Get responsive width as percentage of screen width
  static double getWidthPercent(BuildContext context, double percent) {
    return screenWidth(context) * percent;
  }
  
  /// Get bottom padding to avoid keyboard overlap
  static double getKeyboardPadding(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }
  
  /// Get appropriate app bar height based on screen size
  static double getAppBarHeight(BuildContext context) {
    if (isSmallScreen(context)) {
      return kToolbarHeight * 0.9;
    }
    return kToolbarHeight;
  }
  
  /// Get responsive icon size
  static double getIconSize(BuildContext context, {
    double small = 20.0,
    double medium = 24.0,
    double large = 28.0,
  }) {
    if (isSmallScreen(context)) return small;
    if (isTablet(context)) return large;
    return medium;
  }
}