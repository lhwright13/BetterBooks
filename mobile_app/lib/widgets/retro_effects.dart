import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/retro_theme.dart';

// Scanline overlay effect for CRT monitor aesthetics
class ScanlineOverlay extends StatefulWidget {
  final Widget child;
  final double opacity;
  final double lineSpacing;

  const ScanlineOverlay({
    super.key,
    required this.child,
    this.opacity = 0.1,
    this.lineSpacing = 4.0,
  });

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: ScanlinePainter(
                  opacity: widget.opacity,
                  lineSpacing: widget.lineSpacing,
                  animationValue: _controller.value,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ScanlinePainter extends CustomPainter {
  final double opacity;
  final double lineSpacing;
  final double animationValue;

  ScanlinePainter({
    required this.opacity,
    required this.lineSpacing,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1.0;

    final offset = animationValue * lineSpacing * 2;
    
    for (double y = -lineSpacing + offset; y < size.height + lineSpacing; y += lineSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ScanlinePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// Glitch effect for retro computer aesthetics
class GlitchText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration glitchDuration;

  const GlitchText({
    super.key,
    required this.text,
    this.style,
    this.glitchDuration = const Duration(seconds: 3),
  });

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glitchAnimation;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.glitchDuration,
      vsync: this,
    );
    
    _glitchAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);

    _startGlitchCycle();
  }

  void _startGlitchCycle() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 5 + _random.nextInt(10)));
      if (mounted) {
        _controller.forward().then((_) {
          _controller.reset();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glitchAnimation,
      builder: (context, child) {
        if (_glitchAnimation.value < 0.1) {
          return Text(widget.text, style: widget.style);
        }

        return Stack(
          children: [
            // Original text
            Text(widget.text, style: widget.style),
            
            // Red channel offset
            if (_glitchAnimation.value > 0.3)
              Transform.translate(
                offset: Offset(2 * _glitchAnimation.value, 0),
                child: Text(
                  widget.text,
                  style: widget.style?.copyWith(
                    color: RetroColors.vhsRed.withOpacity(0.7),
                  ),
                ),
              ),
            
            // Cyan channel offset
            if (_glitchAnimation.value > 0.5)
              Transform.translate(
                offset: Offset(-1 * _glitchAnimation.value, 0),
                child: Text(
                  widget.text,
                  style: widget.style?.copyWith(
                    color: RetroColors.neonCyan.withOpacity(0.7),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Flickering effect for terminal-style text
class FlickeringText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration flickerSpeed;

  const FlickeringText({
    super.key,
    required this.text,
    this.style,
    this.flickerSpeed = const Duration(milliseconds: 200),
  });

  @override
  State<FlickeringText> createState() => _FlickeringTextState();
}

class _FlickeringTextState extends State<FlickeringText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.flickerSpeed,
      vsync: this,
    );
    _startFlickering();
  }

  void _startFlickering() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(500)));
      if (mounted && _random.nextBool()) {
        _controller.forward().then((_) {
          _controller.reverse();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.8 + (0.2 * (1 - _controller.value)),
          child: Text(
            widget.text,
            style: widget.style,
          ),
        );
      },
    );
  }
}

// Typing animation effect
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final bool repeat;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 50),
    this.repeat = false,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(
        milliseconds: widget.text.length * widget.duration.inMilliseconds,
      ),
      vsync: this,
    );

    _characterCount = IntTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _startTyping();
  }

  void _startTyping() async {
    _controller.forward();
    if (widget.repeat) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) {
              _controller.reset();
              _controller.forward();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        String visibleText = widget.text.substring(0, _characterCount.value);
        
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: visibleText,
                style: widget.style,
              ),
              // Cursor effect
              if (_characterCount.value < widget.text.length)
                TextSpan(
                  text: '█',
                  style: widget.style?.copyWith(
                    color: RetroColors.phosphorGreen,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Neon glow effect
class NeonGlow extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowRadius;

  const NeonGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.glowRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: glowRadius,
            spreadRadius: glowRadius / 2,
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.1),
            blurRadius: glowRadius * 2,
            spreadRadius: glowRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

// Matrix-style background effect
class MatrixBackground extends StatefulWidget {
  final double opacity;

  const MatrixBackground({
    super.key,
    this.opacity = 0.1,
  });

  @override
  State<MatrixBackground> createState() => _MatrixBackgroundState();
}

class _MatrixBackgroundState extends State<MatrixBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<MatrixColumn> _columns = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_columns.isEmpty) {
          _initializeColumns(constraints);
        }
        
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            _updateColumns(constraints);
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: MatrixPainter(
                columns: _columns,
                opacity: widget.opacity,
              ),
            );
          },
        );
      },
    );
  }

  void _initializeColumns(BoxConstraints constraints) {
    final columnWidth = 20.0;
    final columnCount = (constraints.maxWidth / columnWidth).floor();
    
    for (int i = 0; i < columnCount; i++) {
      _columns.add(MatrixColumn(
        x: i * columnWidth,
        characters: [],
        speed: 1 + _random.nextDouble() * 3,
      ));
    }
  }

  void _updateColumns(BoxConstraints constraints) {
    for (final column in _columns) {
      // Add new characters occasionally
      if (_random.nextDouble() < 0.02) {
        column.characters.add(MatrixCharacter(
          y: 0,
          char: _getRandomChar(),
          opacity: 1.0,
        ));
      }

      // Update existing characters
      column.characters = column.characters.map((char) {
        return MatrixCharacter(
          y: char.y + column.speed,
          char: char.char,
          opacity: math.max(0, char.opacity - 0.02),
        );
      }).where((char) => char.y < constraints.maxHeight && char.opacity > 0).toList();
    }
  }

  String _getRandomChar() {
    const chars = '01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン';
    return chars[_random.nextInt(chars.length)];
  }
}

class MatrixColumn {
  final double x;
  List<MatrixCharacter> characters;
  final double speed;

  MatrixColumn({
    required this.x,
    required this.characters,
    required this.speed,
  });
}

class MatrixCharacter {
  final double y;
  final String char;
  final double opacity;

  MatrixCharacter({
    required this.y,
    required this.char,
    required this.opacity,
  });
}

class MatrixPainter extends CustomPainter {
  final List<MatrixColumn> columns;
  final double opacity;

  MatrixPainter({
    required this.columns,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = RetroColors.phosphorGreen;

    for (final column in columns) {
      for (final char in column.characters) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: char.char,
            style: TextStyle(
              color: RetroColors.phosphorGreen.withOpacity(char.opacity * opacity),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(canvas, Offset(column.x, char.y));
      }
    }
  }

  @override
  bool shouldRepaint(MatrixPainter oldDelegate) => true;
}