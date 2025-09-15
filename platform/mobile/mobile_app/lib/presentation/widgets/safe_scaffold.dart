import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'dart:math' as math;
import '../../core/utils/responsive_utils.dart';

/// Enhanced Scaffold with built-in SafeArea handling and responsive behavior
class SafeScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool maintainBottomViewPadding;
  final EdgeInsetsGeometry? padding;
  final bool applySafeArea;
  final bool dismissKeyboardOnTap;
  final ScrollPhysics? scrollPhysics;
  
  const SafeScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.maintainBottomViewPadding = false,
    this.padding,
    this.applySafeArea = true,
    this.dismissKeyboardOnTap = true,
    this.scrollPhysics,
  });
  
  @override
  Widget build(BuildContext context) {
    Widget bodyWidget = body;
    
    // Apply iOS-specific scroll physics if needed
    if (scrollPhysics != null || Platform.isIOS) {
      bodyWidget = NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollStartNotification && dismissKeyboardOnTap) {
            _dismissKeyboard(context);
          }
          return false;
        },
        child: bodyWidget,
      );
    }
    
    // Apply responsive padding if specified
    if (padding != null || applySafeArea) {
      bodyWidget = Padding(
        padding: padding ?? ResponsiveUtils.responsiveHorizontalPadding(context),
        child: bodyWidget,
      );
    }
    
    // Apply SafeArea wrapper with iOS-specific handling
    if (applySafeArea) {
      bodyWidget = _buildEnhancedSafeArea(context, bodyWidget);
    }
    
    // Wrap with gesture detector for keyboard dismissal
    if (dismissKeyboardOnTap) {
      bodyWidget = GestureDetector(
        onTap: () => _dismissKeyboard(context),
        behavior: HitTestBehavior.translucent,
        child: bodyWidget,
      );
    }
    
    return Scaffold(
      appBar: appBar as PreferredSizeWidget?,
      body: bodyWidget,
      bottomNavigationBar: _buildBottomNavigationBar(context),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }

  Widget _buildEnhancedSafeArea(BuildContext context, Widget child) {
    if (Platform.isIOS) {
      return SafeArea(
        maintainBottomViewPadding: maintainBottomViewPadding,
        child: child,
      );
    } else {
      // Enhanced safe area handling for Android
      final mediaQuery = MediaQuery.of(context);
      final padding = mediaQuery.padding;
      
      return Padding(
        padding: EdgeInsets.only(
          top: padding.top,
          bottom: maintainBottomViewPadding ? padding.bottom : 0,
        ),
        child: child,
      );
    }
  }

  Widget? _buildBottomNavigationBar(BuildContext context) {
    if (bottomNavigationBar == null) return null;

    // Add proper safe area handling for bottom navigation
    return SafeArea(
      top: false,
      child: bottomNavigationBar!,
    );
  }

  void _dismissKeyboard(BuildContext context) {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.focusedChild!.unfocus();
    }
  }
}

/// Responsive AppBar that adjusts height and title size based on screen size
class ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  
  const ResponsiveAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = true,
    this.bottom,
  });
  
  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titleWidget ?? (title != null ? Text(
        title!,
        style: TextStyle(
          fontSize: ResponsiveUtils.responsiveFontSize(context, 18),
          fontWeight: FontWeight.w600,
        ),
      ) : null),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
      bottom: bottom,
      toolbarHeight: ResponsiveUtils.getAppBarHeight(context),
    );
  }
  
  @override
  Size get preferredSize {
    final defaultHeight = kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(defaultHeight + bottomHeight);
  }
}

/// Keyboard-aware scrollable form wrapper
class KeyboardAwareForm extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  
  const KeyboardAwareForm({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.padding,
    this.shrinkWrap = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding ?? ResponsiveUtils.responsivePadding(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: shrinkWrap ? 0 : constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                mainAxisAlignment: mainAxisAlignment,
                children: [
                  ...children,
                  // Add keyboard padding at bottom
                  SizedBox(
                    height: ResponsiveUtils.getKeyboardPadding(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Responsive container that adapts to screen size
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final Decoration? decoration;
  final BoxConstraints? constraints;
  
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.decoration,
    this.constraints,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? ResponsiveUtils.responsivePadding(context),
      margin: margin,
      color: color,
      decoration: decoration,
      constraints: constraints ?? BoxConstraints(
        maxWidth: ResponsiveUtils.isTablet(context) ? 600 : double.infinity,
      ),
      child: child,
    );
  }
}