# EchoWright Theme Colors & Typography Reference

## Brand Colors
```dart
// Primary Brand Colors from Logo
static const Color primaryTurquoise = Color(0xFF44C0C1);
static const Color lightTurquoise = Color(0xFF6ED4D0);
static const Color darkTurquoise = Color(0xFF2BB5B0);

// Brand Accent Colors
static const Color primaryOrange = Color(0xFFFD5E4C);
static const Color lightOrange = Color(0xFFFFA666);
static const Color darkOrange = Color(0xFFE6792A);

static const Color primaryCoral = Color(0xFFE43427);
static const Color lightCoral = Color(0xFFEC6B5E);
static const Color darkCoral = Color(0xFFD63021);

// Brand Gold from Logo Text
static const Color brandGold = Color(0xFFF1C40F);
static const Color lightGold = Color(0xFFF7DC6F);
static const Color deepGold = Color(0xFFD4AC0D);
static const Color warmGold = Color(0xFFF39C12);

// Professional Design System
static const Color softTan = Color(0xFFCEB590);
static const Color darkGreen = Color(0xFF3F594F);
static const Color warmCream = Color(0xFFF5F2ED);
static const Color deepForest = Color(0xFF2A3F35);
static const Color softWhite = Color(0xFFFAFAFA);
```

## Typography
```dart
// Heading Font: GoogleFonts.poppins()
// Body Font: GoogleFonts.interTextTheme()
```

## Brand Gradients
```dart
// Wing Gradient (from logo design)
static const LinearGradient wingGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [primaryOrange, primaryCoral],
);

// Primary Gradient
static const LinearGradient primaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [primaryTurquoise, lightTurquoise],
);
```

## Key Design Principles
- Material Design 3 components
- Dark mode optimized for reading
- Turquoise primary background (#44C0C1)
- White cards/surfaces for contrast
- Gold accents for premium feel
- Subtle shadows and minimal decorations