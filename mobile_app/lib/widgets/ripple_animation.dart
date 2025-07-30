import 'package:flutter/material.dart';
import 'dart:math' as math;

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
  late Animation<double> _animation;
  final List<RippleData> _ripples = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        if (widget.isAnimating) {
          _addRipple();
          _controller.forward();
        }
      }
    });
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
    _controller.forward();
  }

  void _stopAnimation() {
    _controller.stop();
    setState(() {
      _ripples.clear();
    });
  }

  void _addRipple() {
    final random = math.Random();
    setState(() {
      // Remove old ripples
      _ripples.removeWhere((ripple) => ripple.progress > 0.8);
      
      // Add new ripple
      _ripples.add(RippleData(
        centerX: 0.3 + random.nextDouble() * 0.4, // Center area
        centerY: 0.3 + random.nextDouble() * 0.4,
        maxRadius: 0.6 + random.nextDouble() * 0.4,
        intensity: widget.intensity * (0.5 + random.nextDouble() * 0.5),
      ));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Update ripple progress
        for (var ripple in _ripples) {
          ripple.progress = _animation.value;
        }

        return Stack(
          children: [
            widget.child,
            if (widget.isAnimating)
              Positioned.fill(
                child: CustomPaint(
                  painter: RipplePainter(
                    ripples: _ripples,
                    color: widget.rippleColor,
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
  double progress = 0.0;

  RippleData({
    required this.centerX,
    required this.centerY,
    required this.maxRadius,
    required this.intensity,
  });
}

class RipplePainter extends CustomPainter {
  final List<RippleData> ripples;
  final Color color;

  RipplePainter({
    required this.ripples,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var ripple in ripples) {
      final center = Offset(
        size.width * ripple.centerX,
        size.height * ripple.centerY,
      );
      
      final radius = size.width * ripple.maxRadius * ripple.progress;
      final opacity = (1.0 - ripple.progress) * ripple.intensity;
      
      if (opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        // Main ripple
        canvas.drawCircle(center, radius, paint);
        
        // Inner ripple with higher opacity
        if (ripple.progress > 0.2) {
          final innerPaint = Paint()
            ..color = color.withOpacity(opacity * 0.6)
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