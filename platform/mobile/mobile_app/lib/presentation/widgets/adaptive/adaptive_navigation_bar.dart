import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

/// Adaptive navigation bar that provides platform-appropriate styling
class AdaptiveNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final bool centerTitle;
  final double? elevation;
  final PreferredSizeWidget? bottom;

  const AdaptiveNavigationBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.centerTitle = true,
    this.elevation,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoNavigationBar(context);
    } else {
      return _buildMaterialAppBar(context);
    }
  }

  Widget _buildCupertinoNavigationBar(BuildContext context) {
    return CupertinoNavigationBar(
      middle: title,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? CupertinoColors.systemBackground,
      trailing: actions != null && actions!.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            )
          : null,
    );
  }

  Widget _buildMaterialAppBar(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor,
      centerTitle: centerTitle,
      elevation: elevation,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => bottom == null
      ? const Size.fromHeight(kToolbarHeight)
      : Size.fromHeight(kToolbarHeight + bottom!.preferredSize.height);
}

/// Adaptive large title navigation bar for iOS-style large titles
class AdaptiveLargeTitleNavigationBar extends StatelessWidget {
  final Widget title;
  final Widget? largeTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;

  const AdaptiveLargeTitleNavigationBar({
    super.key,
    required this.title,
    this.largeTitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return SliverNavigationBar(
        largeTitle: largeTitle ?? title,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: backgroundColor ?? CupertinoColors.systemBackground,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
      );
    } else {
      return SliverAppBar(
        title: title,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: backgroundColor,
        floating: false,
        pinned: true,
        snap: false,
        expandedHeight: 120,
        flexibleSpace: FlexibleSpaceBar(
          title: title,
          centerTitle: false,
          titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        ),
      );
    }
  }
}

/// Adaptive sliver navigation bar that works with scroll views
class SliverNavigationBar extends StatelessWidget {
  final Widget? largeTitle;
  final Widget? leading;
  final Widget? trailing;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final bool stretch;

  const SliverNavigationBar({
    super.key,
    this.largeTitle,
    this.leading,
    this.trailing,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoSliverNavigationBar(
        largeTitle: largeTitle,
        leading: leading,
        trailing: trailing,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: backgroundColor ?? CupertinoColors.systemBackground,
        stretch: stretch,
      );
    } else {
      return SliverAppBar(
        title: largeTitle,
        actions: trailing != null ? [trailing!] : null,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: backgroundColor,
        floating: false,
        pinned: true,
        snap: false,
        expandedHeight: 100,
        flexibleSpace: FlexibleSpaceBar(
          title: largeTitle,
          centerTitle: false,
          titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        ),
      );
    }
  }
}

/// Adaptive tab bar that provides platform-appropriate tab styling
class AdaptiveTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<AdaptiveTab> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;
  final Color? backgroundColor;
  final Color? indicatorColor;

  const AdaptiveTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.onTap,
    this.backgroundColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoSegmentedControl(context);
    } else {
      return _buildMaterialTabBar(context);
    }
  }

  Widget _buildCupertinoSegmentedControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: backgroundColor ?? CupertinoColors.systemBackground,
      child: CupertinoSegmentedControl<int>(
        children: Map.fromIterable(
          List.generate(tabs.length, (index) => index),
          key: (index) => index,
          value: (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: tabs[index].child,
          ),
        ),
        onValueChanged: onTap ?? (int value) {},
        groupValue: controller?.index ?? 0,
      ),
    );
  }

  Widget _buildMaterialTabBar(BuildContext context) {
    return TabBar(
      tabs: tabs.map((tab) => Tab(child: tab.child)).toList(),
      controller: controller,
      onTap: onTap,
      indicatorColor: indicatorColor,
    );
  }

  @override
  Size get preferredSize => Platform.isIOS
      ? const Size.fromHeight(64) // Larger for segmented control
      : const Size.fromHeight(48); // Standard tab bar height
}

/// Tab item for adaptive tab bar
class AdaptiveTab {
  final Widget child;
  final String? text;
  final IconData? icon;

  const AdaptiveTab({
    required this.child,
    this.text,
    this.icon,
  });

  factory AdaptiveTab.withTextAndIcon({
    required String text,
    required IconData icon,
  }) {
    return AdaptiveTab(
      text: text,
      icon: icon,
      child: Platform.isIOS
          ? Text(text)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 12)),
              ],
            ),
    );
  }

  factory AdaptiveTab.withText(String text) {
    return AdaptiveTab(
      text: text,
      child: Text(text),
    );
  }

  factory AdaptiveTab.withIcon(IconData icon) {
    return AdaptiveTab(
      icon: icon,
      child: Icon(icon),
    );
  }
}