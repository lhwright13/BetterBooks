import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'slide_transition.dart';
import 'fade_transition.dart';

/// Platform-aware transition factory
/// Automatically selects appropriate transitions based on platform and context
class PlatformTransitions {
  
  /// Creates a platform-appropriate page transition
  static PageRouteBuilder createTransition({
    required Widget child,
    required TransitionType type,
    RouteSettings? settings,
    Duration? duration,
  }) {
    if (Platform.isIOS) {
      return _createIOSTransition(child, type, settings, duration);
    } else {
      return _createAndroidTransition(child, type, settings, duration);
    }
  }
  
  /// Creates iOS-style transitions
  static PageRouteBuilder _createIOSTransition(
    Widget child,
    TransitionType type,
    RouteSettings? settings,
    Duration? duration,
  ) {
    switch (type) {
      case TransitionType.push:
        return SlidePageTransition(
          child: child,
          routeSettings: settings,
          duration: duration ?? const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      case TransitionType.modal:
        return ModalSlidePageTransition(
          child: child,
          routeSettings: settings,
          duration: duration ?? const Duration(milliseconds: 300),
        );
      case TransitionType.dialog:
        return ScaleFadePageTransition(
          child: child,
          routeSettings: settings,
          duration: duration ?? const Duration(milliseconds: 250),
          initialScale: 0.9,
        );
      case TransitionType.fade:
        return FadePageTransition(
          child: child,
          routeSettings: settings,
          duration: duration ?? const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
    }
  }
  
  /// Creates Android-style transitions
  static PageRouteBuilder _createAndroidTransition(
    Widget child,
    TransitionType type,
    RouteSettings? settings,
    Duration? duration,
  ) {
    switch (type) {
      case TransitionType.push:
        return SlidePageTransition(
          child: child,
          routeSettings: settings,
          duration: duration ?? const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      case TransitionType.modal:
        return ModalSlidePageTransition(
          child: child,
          routeSettings: settings,
          duration: duration ?? const Duration(milliseconds: 250),
        );
      case TransitionType.dialog:
        return ScaleFadePageTransition(
          child: child,
          routeSettings: settings,
          duration: duration ?? const Duration(milliseconds: 200),
          initialScale: 0.8,
        );
      case TransitionType.fade:
        return FadePageTransition(
          child: child,
          routeSettings: settings,
          duration: duration ?? const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
    }
  }
  
  /// Creates a Cupertino page route for iOS-specific behavior
  static CupertinoPageRoute createCupertinoRoute({
    required Widget child,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    return CupertinoPageRoute(
      builder: (context) => child,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );
  }
  
  /// Creates a Material page route for Android-specific behavior
  static MaterialPageRoute createMaterialRoute({
    required Widget child,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    return MaterialPageRoute(
      builder: (context) => child,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );
  }
  
  /// Creates platform-appropriate route
  static PageRoute createPlatformRoute({
    required Widget child,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    if (Platform.isIOS) {
      return createCupertinoRoute(
        child: child,
        settings: settings,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      );
    } else {
      return createMaterialRoute(
        child: child,
        settings: settings,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      );
    }
  }
}

/// Enum for different transition types
enum TransitionType {
  push,    // Standard push transition (slide from right)
  modal,   // Modal presentation (slide from bottom)
  dialog,  // Dialog/popup (scale + fade)
  fade,    // Simple fade transition
}

/// Custom page transitions theme data
class AppPageTransitionsTheme extends PageTransitionsTheme {
  const AppPageTransitionsTheme();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final platform = Theme.of(context).platform;
    
    switch (platform) {
      case TargetPlatform.iOS:
        return CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          child: child,
          linearTransition: false,
        );
      case TargetPlatform.android:
      default:
        return FadeUpwardsPageTransitionsBuilder().buildTransitions<T>(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
    }
  }
}

/// Custom Cupertino page transition with enhanced animations
class CupertinoPageTransition extends StatelessWidget {
  final Animation<double> primaryRouteAnimation;
  final Animation<double> secondaryRouteAnimation;
  final Widget child;
  final bool linearTransition;

  const CupertinoPageTransition({
    super.key,
    required this.primaryRouteAnimation,
    required this.secondaryRouteAnimation,
    required this.child,
    this.linearTransition = false,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: primaryRouteAnimation,
        curve: linearTransition ? Curves.linear : Curves.easeOutCubic,
      )),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        ).animate(CurvedAnimation(
          parent: secondaryRouteAnimation,
          curve: linearTransition ? Curves.linear : Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }
}