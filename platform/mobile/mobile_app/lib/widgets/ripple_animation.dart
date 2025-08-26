import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

class RippleAnimation extends StatefulWidget {
  final Widget child;
  final bool isAnimating;
  final double intensity;
  final Color rippleColor;
  final Duration duration;

  const RippleAnimation({
    Key? key,
    required this.child,
    this.isAnimating = false,
    this.intensity = 0.5,
    this.rippleColor = Colors.white,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  _RippleAnimationState createState() => _RippleAnimationState();
}

class _RippleAnimationState extends State<RippleAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _rippleTimer;
  final List<RippleData> _ripples = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(RippleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _startAnimation();
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    _addRipple();
    _controller.repeat();
    _rippleTimer = Timer.periodic(
      Duration(milliseconds: widget.duration.inMilliseconds ~/ 3),
      (_) => _addRipple(),
    );
  }

  void _stopAnimation() {
    _controller.stop();
    _rippleTimer?.cancel();
    setState(() {
      _ripples.clear();
    });
  }

  void _addRipple() {
    final random = math.Random();
    setState(() {
      // Remove completed ripples
      _ripples.removeWhere((ripple) {
        final progress = _progressFor(
          ripple,
          DateTime.now(),
          widget.duration,
        );
        return progress > 1.0;
      });

      // Add new ripple
      _ripples.add(RippleData(
        centerX: 0.3 + random.nextDouble() * 0.4, // Center area
        centerY: 0.3 + random.nextDouble() * 0.4,
        maxRadius: 0.6 + random.nextDouble() * 0.4,
        intensity: widget.intensity * (0.5 + random.nextDouble() * 0.5),
        startTime: DateTime.now(),
      ));
    });
  }

  @override
  void dispose() {
    _rippleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final now = DateTime.now();
        return Stack(
          children: [
            widget.child,
            if (widget.isAnimating)
              Positioned.fill(
                child: CustomPaint(
                  painter: RipplePainter(
                    ripples: _ripples,
                    color: widget.rippleColor,
                    now: now,
                    duration: widget.duration,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class RippleData {
  final double centerX;
  final double centerY;
  final double maxRadius;
  final double intensity;
  final DateTime startTime;

  RippleData({
    required this.centerX,
    required this.centerY,
    required this.maxRadius,
    required this.intensity,
    required this.startTime,
  });
}

class RipplePainter extends CustomPainter {
  final List<RippleData> ripples;
  final Color color;
  final DateTime now;
  final Duration duration;

  RipplePainter({
    required this.ripples,
    required this.color,
    required this.now,
    required this.duration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var ripple in ripples) {
      final progress = _progressFor(ripple, now, duration).clamp(0.0, 1.0);
      final curved = Curves.easeOut.transform(progress);
      final center = Offset(
        size.width * ripple.centerX,
        size.height * ripple.centerY,
      );

      final radius = size.width * ripple.maxRadius * curved;
      final opacity = (1.0 - curved) * ripple.intensity;

      if (opacity > 0) {
        final paint = Paint()
          ..color = color.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        // Main ripple
        canvas.drawCircle(center, radius, paint);

        // Inner ripple with higher opacity
        if (curved > 0.2) {
          final innerPaint = Paint()
            ..color = color.withValues(alpha: opacity * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;

          canvas.drawCircle(center, radius * 0.7, innerPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) => true;
}

double _progressFor(
  RippleData ripple,
  DateTime now,
  Duration duration,
) {
  final elapsed = now.difference(ripple.startTime).inMilliseconds;
  return elapsed / duration.inMilliseconds;
}
