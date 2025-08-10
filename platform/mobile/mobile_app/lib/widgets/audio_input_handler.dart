import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class AudioInputHandler extends StatefulWidget {
  final Widget child;
  final Function(double) onAudioLevel;
  final bool isListening;

  const AudioInputHandler({
    Key? key,
    required this.child,
    required this.onAudioLevel,
    this.isListening = false,
  }) : super(key: key);

  @override
  _AudioInputHandlerState createState() => _AudioInputHandlerState();
}

class _AudioInputHandlerState extends State<AudioInputHandler> {
  Timer? _audioTimer;
  double _currentLevel = 0.0;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _startAudioSimulation();
  }

  @override
  void didUpdateWidget(AudioInputHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _startAudioSimulation();
      } else {
        _stopAudioSimulation();
      }
    }
  }

  void _startAudioSimulation() {
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!widget.isListening) {
        _currentLevel = _currentLevel * 0.95; // Fade out
      } else {
        // Simulate realistic voice frequency patterns
        _frameCount++;
        final time = _frameCount * 0.016; // 60fps
        
        // Combine multiple frequency components to simulate speech
        final lowFreq = math.sin(time * 2.0 * math.pi * 2.0) * 0.3; // 2Hz base
        final midFreq = math.sin(time * 2.0 * math.pi * 8.0) * 0.5; // 8Hz speech
        final highFreq = math.sin(time * 2.0 * math.pi * 25.0) * 0.2; // 25Hz texture
        
        // Add some randomness for natural speech variation  
        final random = math.Random().nextDouble() * 0.4 - 0.2;
        
        // Combine frequencies with speech-like envelope
        final envelope = _speechEnvelope(time);
        _currentLevel = ((lowFreq + midFreq + highFreq + random) * envelope).abs();
        _currentLevel = math.max(0.0, math.min(1.0, _currentLevel));
      }
      
      if (mounted) {
        widget.onAudioLevel(_currentLevel);
      }
    });
  }

  double _speechEnvelope(double time) {
    // Create speech-like patterns with pauses
    final wordCycle = time % 3.0; // 3-second cycle
    if (wordCycle < 0.5) return 0.1; // Pause
    if (wordCycle < 1.5) return 0.8; // Speaking
    if (wordCycle < 2.0) return 0.4; // Transition
    return 0.6; // Speaking continues
  }

  void _stopAudioSimulation() {
    _audioTimer?.cancel();
    _currentLevel = 0.0;
    if (mounted) {
      widget.onAudioLevel(0.0);
    }
  }

  @override
  void dispose() {
    _audioTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}