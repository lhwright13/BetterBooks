import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class RippleShaderWidget extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final double audioLevel;
  final Duration duration;

  const RippleShaderWidget({
    Key? key,
    required this.child,
    this.isActive = false,
    this.audioLevel = 0.0,
    this.duration = const Duration(milliseconds: 16), // 60fps
  }) : super(key: key);

  @override
  _RippleShaderWidgetState createState() => _RippleShaderWidgetState();
}

class _RippleShaderWidgetState extends State<RippleShaderWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  double _time = 0.0;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    
    _controller.addListener(() {
      setState(() {
        _time += 0.016; // Increment time for shader animation
      });
    });
    
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/ripple.frag');
      _shader = program.fragmentShader();
      setState(() {});
    } catch (e) {
      print('Failed to load shader: $e');
      // Fallback to non-shader implementation
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RippleShaderPainter(
        shader: _shader,
        time: _time,
        audioLevel: widget.isActive ? widget.audioLevel : 0.0,
        isActive: widget.isActive,
      ),
      child: widget.child,
    );
  }
}

class RippleShaderPainter extends CustomPainter {
  final ui.FragmentShader? shader;
  final double time;
  final double audioLevel;
  final bool isActive;

  RippleShaderPainter({
    required this.shader,
    required this.time,
    required this.audioLevel,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shader == null || !isActive) {
      return; // Don't apply shader if not loaded or not active
    }

    // Set shader uniforms
    shader!.setFloat(0, size.width);   // u_resolution.x
    shader!.setFloat(1, size.height);  // u_resolution.y
    shader!.setFloat(2, time);         // u_time
    shader!.setFloat(3, audioLevel);   // u_audioLevel
    
    // Center point for ripple effect
    shader!.setFloat(4, size.width * 0.5);  // u_center.x
    shader!.setFloat(5, size.height * 0.5); // u_center.y

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(RippleShaderPainter oldDelegate) {
    return oldDelegate.time != time ||
           oldDelegate.audioLevel != audioLevel ||
           oldDelegate.isActive != isActive;
  }
}