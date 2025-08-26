import 'package:flutter/material.dart';
import 'dart:math' as math;

class CSSRippleWidget extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final double audioLevel;

  const CSSRippleWidget({
    Key? key,
    required this.child,
    this.isActive = false,
    this.audioLevel = 0.0,
  }) : super(key: key);

  @override
  _CSSRippleWidgetState createState() => _CSSRippleWidgetState();
}

class _CSSRippleWidgetState extends State<CSSRippleWidget>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _scaleController;
  late List<AnimationController> _multiRippleControllers;
  
  @override
  void initState() {
    super.initState();
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Create multiple ripple controllers for layered effect
    _multiRippleControllers = List.generate(3, (index) => 
      AnimationController(
        duration: Duration(milliseconds: 1500 + (index * 200)),
        vsync: this,
      )
    );
  }

  @override
  void didUpdateWidget(CSSRippleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startRipples();
      } else {
        _stopRipples();
      }
    }
  }

  void _startRipples() {
    _scaleController.forward();
    _rippleController.repeat();
    for (var controller in _multiRippleControllers) {
      controller.repeat();
    }
  }

  void _stopRipples() {
    _scaleController.reverse();
    _rippleController.stop();
    for (var controller in _multiRippleControllers) {
      controller.stop();
      controller.reset();
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _scaleController.dispose();
    for (var controller in _multiRippleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _rippleController,
        _scaleController,
        ..._multiRippleControllers,
      ]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Base image with scale animation
            Transform.scale(
              scale: 1.0 + (_scaleController.value * 0.05),
              child: widget.child,
            ),
            
            // Multiple ripple layers
            if (widget.isActive) ...[
              for (int i = 0; i < _multiRippleControllers.length; i++)
                _buildRippleLayer(i),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRippleLayer(int index) {
    final controller = _multiRippleControllers[index];
    final intensity = widget.audioLevel;
    final delay = index * 0.3;
    
    return Positioned.fill(
      child: CustomPaint(
        painter: CSSRipplePainter(
          animation: controller,
          audioLevel: intensity,
          rippleIndex: index,
          time: _rippleController.value + delay,
        ),
      ),
    );
  }
}

class CSSRipplePainter extends CustomPainter {
  final Animation<double> animation;
  final double audioLevel;
  final int rippleIndex;
  final double time;

  CSSRipplePainter({
    required this.animation,
    required this.audioLevel,
    required this.rippleIndex,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.7;
    
    // Create multiple concentric ripples
    for (int i = 0; i < 3; i++) {
      final rippleProgress = (animation.value + (i * 0.3)) % 1.0;
      final radius = maxRadius * rippleProgress;
      
      // Vary opacity based on audio level and distance
      final baseOpacity = (1.0 - rippleProgress) * 0.3;
      final audioMultiplier = 0.5 + (audioLevel * 1.5);
      final opacity = (baseOpacity * audioMultiplier).clamp(0.0, 0.8);
      
      if (opacity > 0) {
        final paint = Paint()
          ..color = _getRippleColor(rippleIndex).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 + (audioLevel * 3.0);

        // Add some distortion based on audio level
        final distortion = audioLevel * 10.0;
        final distortedRadius = radius + (math.sin(time * 10 + i) * distortion);
        
        canvas.drawCircle(center, distortedRadius, paint);
        
        // Add inner highlight
        if (rippleProgress > 0.1) {
          final innerPaint = Paint()
            ..color = Colors.white.withValues(alpha: opacity * 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          
          canvas.drawCircle(center, distortedRadius * 0.8, innerPaint);
        }
      }
    }
  }

  Color _getRippleColor(int index) {
    final colors = [
      Colors.blue,
      Colors.cyan,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(CSSRipplePainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
           oldDelegate.audioLevel != audioLevel ||
           oldDelegate.time != time;
  }
}