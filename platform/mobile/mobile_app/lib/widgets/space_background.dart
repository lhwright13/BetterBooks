import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../theme/echowright_theme.dart';

/// Space Background Widget - Animated background matching the web interface
/// Features floating planets, orbital rings, and twinkling stars
class SpaceBackground extends StatefulWidget {
  final Widget child;
  final bool enableAnimations;
  
  const SpaceBackground({
    super.key,
    required this.child,
    this.enableAnimations = true,
  });

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with TickerProviderStateMixin {
  late AnimationController _planetOrbitController;
  late AnimationController _starsController;
  late AnimationController _orbitRingController;
  late List<Star> _stars;
  late List<Planet> _planets;

  @override
  void initState() {
    super.initState();
    
    if (widget.enableAnimations) {
      // Planet orbital motion
      _planetOrbitController = AnimationController(
        duration: Duration(seconds: 30),
        vsync: this,
      )..repeat();
      
      // Twinkling stars
      _starsController = AnimationController(
        duration: Duration(seconds: 4),
        vsync: this,
      )..repeat(reverse: true);
      
      // Orbital rings rotation
      _orbitRingController = AnimationController(
        duration: Duration(seconds: 15),
        vsync: this,
      )..repeat();
    }
    
    _generateStars();
    _generatePlanets();
  }

  @override
  void dispose() {
    if (widget.enableAnimations) {
      _planetOrbitController.dispose();
      _starsController.dispose();
      _orbitRingController.dispose();
    }
    super.dispose();
  }

  void _generateStars() {
    final random = math.Random(42); // Fixed seed for consistent stars
    _stars = List.generate(50, (index) {
      return Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: 1.0 + random.nextDouble() * 2.0,
        twinklePhase: random.nextDouble() * 2 * math.pi,
        color: [
          EchoWrightTheme.textOnPrimary,
          EchoWrightTheme.brandGold.withValues(alpha: 0.8),
          EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.6),
        ][random.nextInt(3)],
      );
    });
  }

  void _generatePlanets() {
    _planets = [
      Planet(
        x: 0.8,
        y: 0.2,
        size: 60,
        color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.3),
        orbitRadius: 120,
        orbitSpeed: 1.0,
      ),
      Planet(
        x: 0.1,
        y: 0.7,
        size: 40,
        color: EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.2),
        orbitRadius: 80,
        orbitSpeed: 1.5,
      ),
      Planet(
        x: 0.6,
        y: 0.8,
        size: 25,
        color: EchoWrightTheme.brandGold.withValues(alpha: 0.25),
        orbitRadius: 50,
        orbitSpeed: 2.0,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            EchoWrightTheme.backgroundDark,
            EchoWrightTheme.backgroundLight,
            EchoWrightTheme.surfaceDark,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background stars
          if (widget.enableAnimations)
            AnimatedBuilder(
              animation: _starsController,
              builder: (context, child) => CustomPaint(
                painter: StarsPainter(
                  stars: _stars,
                  animation: _starsController,
                ),
                size: Size.infinite,
              ),
            ),
          
          // Floating planets
          if (widget.enableAnimations)
            AnimatedBuilder(
              animation: _planetOrbitController,
              builder: (context, child) => CustomPaint(
                painter: PlanetsPainter(
                  planets: _planets,
                  animation: _planetOrbitController,
                ),
                size: Size.infinite,
              ),
            ),
          
          // Orbital rings
          if (widget.enableAnimations)
            AnimatedBuilder(
              animation: _orbitRingController,
              builder: (context, child) => CustomPaint(
                painter: OrbitRingsPainter(
                  animation: _orbitRingController,
                ),
                size: Size.infinite,
              ),
            ),
          
          // Main content
          widget.child,
        ],
      ),
    );
  }
}

class Star {
  final double x;
  final double y;
  final double size;
  final double twinklePhase;
  final Color color;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinklePhase,
    required this.color,
  });
}

class Planet {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double orbitRadius;
  final double orbitSpeed;

  Planet({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.orbitRadius,
    required this.orbitSpeed,
  });
}

class StarsPainter extends CustomPainter {
  final List<Star> stars;
  final Animation<double> animation;

  StarsPainter({required this.stars, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final paint = Paint()
        ..color = star.color.withValues(alpha: 
          0.3 + 0.7 * (math.sin(animation.value * 2 * math.pi + star.twinklePhase) * 0.5 + 0.5),
        )
        ..style = PaintingStyle.fill;

      final center = Offset(
        star.x * size.width,
        star.y * size.height,
      );

      // Draw twinkling star
      canvas.drawCircle(center, star.size, paint);
      
      // Add subtle glow
      paint.color = star.color.withValues(alpha: 0.1);
      canvas.drawCircle(center, star.size * 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PlanetsPainter extends CustomPainter {
  final List<Planet> planets;
  final Animation<double> animation;

  PlanetsPainter({required this.planets, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    for (final planet in planets) {
      // Calculate orbital position
      final angle = animation.value * 2 * math.pi * planet.orbitSpeed;
      final orbitCenterX = planet.x * size.width;
      final orbitCenterY = planet.y * size.height;
      
      final planetX = orbitCenterX + planet.orbitRadius * math.cos(angle);
      final planetY = orbitCenterY + planet.orbitRadius * math.sin(angle);
      
      // Draw planet with gradient effect
      final paint = Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [
            planet.color.withValues(alpha: 0.8),
            planet.color.withValues(alpha: 0.3),
            planet.color.withValues(alpha: 0.1),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(planetX, planetY),
          radius: planet.size / 2,
        ));

      canvas.drawCircle(
        Offset(planetX, planetY),
        planet.size / 2,
        paint,
      );
      
      // Draw subtle orbital path
      final pathPaint = Paint()
        ..color = EchoWrightTheme.textMuted.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      
      canvas.drawCircle(
        Offset(orbitCenterX, orbitCenterY),
        planet.orbitRadius,
        pathPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OrbitRingsPainter extends CustomPainter {
  final Animation<double> animation;

  OrbitRingsPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Main orbital ring
    paint.color = EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.2 + 0.1 * math.sin(animation.value * 2 * math.pi));
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.4),
      150 + 20 * math.sin(animation.value * 2 * math.pi),
      paint,
    );

    // Secondary orbital ring
    paint.color = EchoWrightTheme.primaryCoral.withValues(alpha: 0.15 + 0.1 * math.cos(animation.value * 2 * math.pi * 1.3));
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.6),
      100 + 15 * math.cos(animation.value * 2 * math.pi * 1.3),
      paint,
    );

    // Tertiary orbital ring
    paint.color = EchoWrightTheme.brandGold.withValues(alpha: 0.1 + 0.05 * math.sin(animation.value * 2 * math.pi * 0.8));
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.2),
      80 + 10 * math.sin(animation.value * 2 * math.pi * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// EchoWright Logo Widget - Orbital logo matching web interface
class EchoWrightLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const EchoWrightLogo({
    super.key,
    this.size = 120,
    this.animate = true,
  });

  @override
  State<EchoWrightLogo> createState() => _EchoWrightLogoState();
}

class _EchoWrightLogoState extends State<EchoWrightLogo>
    with TickerProviderStateMixin {
  late AnimationController _satelliteController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    if (widget.animate) {
      _satelliteController = AnimationController(
        duration: Duration(seconds: 8),
        vsync: this,
      )..repeat();
      
      _pulseController = AnimationController(
        duration: Duration(seconds: 3),
        vsync: this,
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      _satelliteController.dispose();
      _pulseController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return _buildSvgWithFallback(context);
    }
    
    return _buildSvgWithFallback(context);
  }

  Widget _buildSvgWithFallback(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/EchoWright.svg',
      width: widget.size,
      height: widget.size * 0.6, // Maintain aspect ratio
      placeholderBuilder: (BuildContext context) => Container(
        width: widget.size,
        height: widget.size * 0.6,
        decoration: BoxDecoration(
          color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.spatial_audio_off,
          size: widget.size * 0.3,
          color: EchoWrightTheme.primaryCoral,
        ),
      ),
    );
  }
}

class LogoPainter extends CustomPainter {
  final double satelliteAnimation;
  final double pulseAnimation;

  LogoPainter(this.satelliteAnimation, this.pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Central core (planetary body)
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          EchoWrightTheme.primaryCoral,
          EchoWrightTheme.primaryOrange,
          EchoWrightTheme.primaryCoral.withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.3));

    canvas.drawCircle(center, radius * 0.3 + pulseAnimation * 3, corePaint);

    // Orbital rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Inner ring
    ringPaint.color = EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.6);
    canvas.drawCircle(center, radius * 0.6, ringPaint);

    // Outer ring
    ringPaint.color = EchoWrightTheme.brandGold.withValues(alpha: 0.4);
    canvas.drawCircle(center, radius * 0.8, ringPaint);

    // Rotating satellite
    final satelliteAngle = satelliteAnimation * 2 * math.pi;
    final satelliteRadius = radius * 0.7;
    final satelliteX = center.dx + satelliteRadius * math.cos(satelliteAngle);
    final satelliteY = center.dy + satelliteRadius * math.sin(satelliteAngle);

    final satellitePaint = Paint()
      ..color = EchoWrightTheme.brandGold
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(satelliteX, satelliteY),
      6 + pulseAnimation * 2,
      satellitePaint,
    );

    // Satellite glow
    satellitePaint.color = EchoWrightTheme.brandGold.withValues(alpha: 0.3);
    canvas.drawCircle(
      Offset(satelliteX, satelliteY),
      12 + pulseAnimation * 4,
      satellitePaint,
    );

    // Connection beam (optional visual effect)
    final beamPaint = Paint()
      ..color = EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.2)
      ..strokeWidth = 2;

    canvas.drawLine(
      center,
      Offset(satelliteX, satelliteY),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Space Mission Status Indicator
class MissionStatusIndicator extends StatelessWidget {
  final String status;
  final Color color;
  final bool isActive;

  const MissionStatusIndicator({
    super.key,
    required this.status,
    required this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: color.withValues(alpha: 0.1),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isActive ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
          SizedBox(width: 8.0),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}