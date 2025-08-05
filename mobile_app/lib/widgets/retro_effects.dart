import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/retro_theme.dart';

// Subtle texture overlay for warm architectural aesthetics
class TextureOverlay extends StatefulWidget {
  final Widget child;
  final double opacity;
  final double lineSpacing;

  const TextureOverlay({
    super.key,
    required this.child,
    this.opacity = 0.1,
    this.lineSpacing = 4.0,
  });

  @override
  State<TextureOverlay> createState() => _TextureOverlayState();
}

class _TextureOverlayState extends State<TextureOverlay>
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
                painter: TexturePainter(
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

class TexturePainter extends CustomPainter {
  final double opacity;
  final double lineSpacing;
  final double animationValue;

  TexturePainter({
    required this.opacity,
    required this.lineSpacing,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RetroColors.stoneBeige.withOpacity(opacity * 0.3)
      ..strokeWidth = 0.5;

    final offset = animationValue * lineSpacing * 3;
    
    // Create subtle horizontal texture lines for architectural feel
    for (double y = -lineSpacing + offset; y < size.height + lineSpacing; y += lineSpacing * 2) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TexturePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// Subtle shift effect for warm architectural aesthetics
class ShiftText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration glitchDuration;

  const ShiftText({
    super.key,
    required this.text,
    this.style,
    this.glitchDuration = const Duration(seconds: 3),
  });

  @override
  State<ShiftText> createState() => _ShiftTextState();
}

class _ShiftTextState extends State<ShiftText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shiftAnimation;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.glitchDuration,
      vsync: this,
    );
    
    _shiftAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);

    _startShiftCycle();
  }

  void _startShiftCycle() async {
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
      animation: _shiftAnimation,
      builder: (context, child) {
        if (_shiftAnimation.value < 0.1) {
          return Text(widget.text, style: widget.style);
        }

        return Stack(
          children: [
            // Original text
            Text(widget.text, style: widget.style),
            
            // Terracotta shadow offset
            if (_shiftAnimation.value > 0.3)
              Transform.translate(
                offset: Offset(1 * _shiftAnimation.value, 0.5 * _shiftAnimation.value),
                child: Text(
                  widget.text,
                  style: widget.style?.copyWith(
                    color: RetroColors.primaryTerracotta.withOpacity(0.3),
                  ),
                ),
              ),
            
            // Sage green shadow offset
            if (_shiftAnimation.value > 0.5)
              Transform.translate(
                offset: Offset(-0.5 * _shiftAnimation.value, 0.3 * _shiftAnimation.value),
                child: Text(
                  widget.text,
                  style: widget.style?.copyWith(
                    color: RetroColors.sageGreen.withOpacity(0.4),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Gentle breathing effect for warm architectural text
class BreathingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration flickerSpeed;

  const BreathingText({
    super.key,
    required this.text,
    this.style,
    this.flickerSpeed = const Duration(milliseconds: 200),
  });

  @override
  State<BreathingText> createState() => _BreathingTextState();
}

class _BreathingTextState extends State<BreathingText>
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
    _startBreathing();
  }

  void _startBreathing() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 2000 + _random.nextInt(1000)));
      if (mounted) {
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
          opacity: 0.92 + (0.08 * (1 - _controller.value)),
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
                    color: RetroColors.primaryTerracotta,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Warm architectural glow effect
class WarmGlow extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowRadius;

  const WarmGlow({
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
            color: glowColor.withOpacity(0.15),
            blurRadius: glowRadius,
            spreadRadius: glowRadius / 3,
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.06),
            blurRadius: glowRadius * 1.5,
            spreadRadius: glowRadius / 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

// Subtle architectural pattern background
class ArchitecturalBackground extends StatefulWidget {
  final double opacity;

  const ArchitecturalBackground({
    super.key,
    this.opacity = 0.1,
  });

  @override
  State<ArchitecturalBackground> createState() => _ArchitecturalBackgroundState();
}

class _ArchitecturalBackgroundState extends State<ArchitecturalBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ArchitecturalColumn> _columns = [];
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
              painter: ArchitecturalPainter(
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
      _columns.add(ArchitecturalColumn(
        x: i * columnWidth,
        elements: [],
        speed: 0.5 + _random.nextDouble() * 1,
      ));
    }
  }

  void _updateColumns(BoxConstraints constraints) {
    for (final column in _columns) {
      // Add new elements occasionally
      if (_random.nextDouble() < 0.005) {
        column.elements.add(ArchitecturalElement(
          y: 0,
          symbol: _getRandomSymbol(),
          opacity: 1.0,
        ));
      }

      // Update existing elements
      column.elements = column.elements.map((element) {
        return ArchitecturalElement(
          y: element.y + column.speed,
          symbol: element.symbol,
          opacity: math.max(0, element.opacity - 0.005),
        );
      }).where((element) => element.y < constraints.maxHeight && element.opacity > 0).toList();
    }
  }

  String _getRandomSymbol() {
    const symbols = '◆◇□■▫▪▬▭▮▯○●◉◎';
    return symbols[_random.nextInt(symbols.length)];
  }
}

class ArchitecturalColumn {
  final double x;
  List<ArchitecturalElement> elements;
  final double speed;

  ArchitecturalColumn({
    required this.x,
    required this.elements,
    required this.speed,
  });
}

class ArchitecturalElement {
  final double y;
  final String symbol;
  final double opacity;

  ArchitecturalElement({
    required this.y,
    required this.symbol,
    required this.opacity,
  });
}

class ArchitecturalPainter extends CustomPainter {
  final List<ArchitecturalColumn> columns;
  final double opacity;

  ArchitecturalPainter({
    required this.columns,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = RetroColors.primaryTerracotta;

    for (final column in columns) {
      for (final element in column.elements) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: element.symbol,
            style: TextStyle(
              color: RetroColors.primaryTerracotta.withOpacity(element.opacity * opacity * 0.3),
              fontSize: 16,
              fontFamily: 'serif',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(canvas, Offset(column.x, element.y));
      }
    }
  }

  @override
  bool shouldRepaint(ArchitecturalPainter oldDelegate) => true;
}