import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

class AudioVisualizer extends StatefulWidget {
  final bool isActive;
  final AudioVisualizationMode mode;
  final Color color;
  final Function(double)? onAudioLevel;

  const AudioVisualizer({
    Key? key,
    this.isActive = false,
    this.mode = AudioVisualizationMode.listening,
    this.color = Colors.blue,
    this.onAudioLevel,
  }) : super(key: key);

  @override
  _AudioVisualizerState createState() => _AudioVisualizerState();
}

enum AudioVisualizationMode {
  listening,    // User speaking
  processing,   // AI thinking
  speaking,     // AI responding
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _audioLevelTimer;
  double _currentLevel = 0.0;
  final List<double> _audioLevels = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat();

    _startAudioLevelSimulation();
  }

  void _startAudioLevelSimulation() {
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!widget.isActive) {
        setState(() {
          _currentLevel = 0.0;
        });
        return;
      }

      // Simulate different audio patterns based on mode
      double newLevel;
      switch (widget.mode) {
        case AudioVisualizationMode.listening:
          // Simulate microphone input with random spikes
          newLevel = _simulateListeningLevel();
          break;
        case AudioVisualizationMode.processing:
          // Gentle pulsing while AI thinks
          newLevel = _simulateProcessingLevel();
          break;
        case AudioVisualizationMode.speaking:
          // Simulate AI speech pattern
          newLevel = _simulateSpeakingLevel();
          break;
      }

      setState(() {
        _currentLevel = newLevel;
        _audioLevels.add(newLevel);
        if (_audioLevels.length > 20) {
          _audioLevels.removeAt(0);
        }
      });

      // Notify parent of audio level changes
      widget.onAudioLevel?.call(_currentLevel);
    });
  }

  double _simulateListeningLevel() {
    final random = math.Random();
    // Simulate speech pattern with pauses
    if (random.nextDouble() < 0.3) {
      return 0.1 + random.nextDouble() * 0.9; // Speaking
    } else {
      return random.nextDouble() * 0.2; // Background noise
    }
  }

  double _simulateProcessingLevel() {
    // Gentle sine wave for processing indication
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    return 0.3 + 0.2 * math.sin(time * 2);
  }

  double _simulateSpeakingLevel() {
    final random = math.Random();
    // Simulate AI speech with more consistent patterns
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final baseLevel = 0.4 + 0.3 * math.sin(time * 3);
    return baseLevel + random.nextDouble() * 0.3;
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioLevelTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 60),
          painter: AudioVisualizerPainter(
            audioLevels: _audioLevels,
            currentLevel: _currentLevel,
            color: widget.color,
            mode: widget.mode,
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class AudioVisualizerPainter extends CustomPainter {
  final List<double> audioLevels;
  final double currentLevel;
  final Color color;
  final AudioVisualizationMode mode;
  final double animationValue;

  AudioVisualizerPainter({
    required this.audioLevels,
    required this.currentLevel,
    required this.color,
    required this.mode,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioLevels.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    switch (mode) {
      case AudioVisualizationMode.listening:
        _drawWaveform(canvas, size, paint, fillPaint);
        break;
      case AudioVisualizationMode.processing:
        _drawPulsingCircles(canvas, size, paint);
        break;
      case AudioVisualizationMode.speaking:
        _drawSpeechBars(canvas, size, paint, fillPaint);
        break;
    }
  }

  void _drawWaveform(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    final path = Path();
    final centerY = size.height / 2;
    
    for (int i = 0; i < audioLevels.length; i++) {
      final x = (i / audioLevels.length) * size.width;
      final y = centerY - (audioLevels[i] * centerY);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    // Create filled area
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, centerY);
    fillPath.lineTo(0, centerY);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  void _drawPulsingCircles(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 3;
    
    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + i * 0.3) % 1.0;
      final radius = maxRadius * progress;
      final opacity = (1.0 - progress) * currentLevel;
      
      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _drawSpeechBars(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    final barCount = 12;
    final barWidth = size.width / (barCount * 2);
    final spacing = barWidth;
    
    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing) + spacing;
      final levelIndex = (i * audioLevels.length / barCount).floor();
      final level = levelIndex < audioLevels.length ? audioLevels[levelIndex] : 0.0;
      final barHeight = level * size.height;
      
      final rect = Rect.fromLTWH(
        x,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(AudioVisualizerPainter oldDelegate) => true;
}