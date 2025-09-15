/// Application asset paths
/// Centralized management of all app assets to prevent hardcoded paths
class AppAssets {
  // Private constructor to prevent instantiation
  AppAssets._();
  
  // Base paths
  static const String _imagesPath = 'assets/images';
  
  // Brand assets
  static const String logoMain = '$_imagesPath/EchoWright.svg';
  static const String logoYellow = '$_imagesPath/EchoWrightYellow.svg';
  static const String loginLogo = '$_imagesPath/login_logo.svg';
  static const String appIcon = '$_imagesPath/icon.png';
  
  // Placeholder assets
  static const String placeholderBookCover = '$_imagesPath/placeholder_book_cover.svg';
  
  // Social login icons (placeholders - would need actual files)
  static const String googleIcon = '$_imagesPath/google_icon.svg';
  static const String appleIcon = '$_imagesPath/apple_icon.svg';
  static const String facebookIcon = '$_imagesPath/facebook_icon.svg';
  
  // Onboarding illustrations (placeholders - would need actual files)
  static const String onboarding1 = '$_imagesPath/onboarding_1.svg';
  static const String onboarding2 = '$_imagesPath/onboarding_2.svg';
  static const String onboarding3 = '$_imagesPath/onboarding_3.svg';
  
  // Error and empty state illustrations (placeholders)
  static const String errorIllustration = '$_imagesPath/error_illustration.svg';
  static const String emptyStateIllustration = '$_imagesPath/empty_state.svg';
  static const String noInternetIllustration = '$_imagesPath/no_internet.svg';
  
  // Check if an asset exists in the available assets
  static const Set<String> _availableAssets = {
    logoMain,
    logoYellow,
    loginLogo,
    appIcon,
    placeholderBookCover,
  };
  
  /// Check if an asset is available
  static bool isAssetAvailable(String assetPath) {
    return _availableAssets.contains(assetPath);
  }
  
  /// Get a fallback asset path if the requested one is not available
  static String getAssetOrFallback(String assetPath, String fallbackPath) {
    return isAssetAvailable(assetPath) ? assetPath : fallbackPath;
  }
}