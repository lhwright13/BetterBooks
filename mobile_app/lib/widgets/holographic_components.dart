import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/retro_theme.dart';
import 'dart:math' as math;

/// Architectural card component with warm, tactile effects
class ArchitecturalCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const ArchitecturalCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
    this.onTap,
  });

  @override
  State<ArchitecturalCard> createState() => _ArchitecturalCardState();
}

class _ArchitecturalCardState extends State<ArchitecturalCard>
    with TickerProviderStateMixin {
  late AnimationController _warmGlowController;
  late AnimationController _tactileController;
  
  @override
  void initState() {
    super.initState();
    
    _warmGlowController = AnimationController(
      duration: Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    _tactileController = AnimationController(
      duration: Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _warmGlowController.dispose();
    _tactileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_warmGlowController, _tactileController]),
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(RetroSizes.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: RetroColors.cardGradient,
            ),
            border: Border.all(
              width: RetroSizes.subtleBorder,
              color: Color.lerp(
                RetroColors.primaryTerracotta.withOpacity(0.15),
                RetroColors.sageGreen.withOpacity(0.25),
                _warmGlowController.value,
              )!,
            ),
            boxShadow: [
              BoxShadow(
                color: RetroColors.primaryTerracotta.withOpacity(0.08 + (_tactileController.value * 0.04)),
                blurRadius: 16 + (_tactileController.value * 4),
                spreadRadius: 1,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: RetroColors.stoneBeige.withOpacity(0.06 + (_warmGlowController.value * 0.02)),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(RetroSizes.borderRadius),
              onTap: widget.onTap,
              child: Padding(
                padding: widget.padding ?? EdgeInsets.all(RetroSpacing.md),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Warm furniture-style button with architectural tactile styling
class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final Color? color;
  final BorderRadius? borderRadius;

  const TactileButton({
    super.key,
    required this.child,
    this.onPressed,
    this.width,
    this.height,
    this.color,
    this.borderRadius,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? RetroColors.primaryTerracotta;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: RetroAnimations.ultraFast,
        curve: RetroAnimations.gentleEase,
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(RetroSizes.borderRadius),
          gradient: LinearGradient(
            begin: _isPressed ? Alignment.bottomRight : Alignment.topLeft,
            end: _isPressed ? Alignment.topLeft : Alignment.bottomRight,
            colors: [
              color,
              color.withOpacity(0.85),
              color.withOpacity(0.95),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: RetroSizes.subtleBorder,
          ),
          boxShadow: _isPressed ? [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ] : [
            BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 12,
              offset: Offset(0, 4),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: RetroColors.stoneBeige.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

/// Architectural information panel with warm material styling
class ArchitecturalPanel extends StatelessWidget {
  final String title;
  final List<ArchitecturalDataRow> rows;
  final Color? accentColor;

  const ArchitecturalPanel({
    super.key,
    required this.title,
    required this.rows,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? RetroColors.primaryTerracotta;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RetroSizes.smallRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: RetroColors.cardGradient,
        ),
        border: Border.all(
          color: accent.withOpacity(0.15),
          width: RetroSizes.subtleBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(RetroSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(RetroSizes.smallRadius),
                topRight: Radius.circular(RetroSizes.smallRadius),
              ),
              color: accent.withOpacity(0.06),
              border: Border(
                bottom: BorderSide(
                  color: accent.withOpacity(0.12),
                  width: RetroSizes.subtleBorder,
                ),
              ),
            ),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: accent,
                letterSpacing: 1.2,
              ),
            ),
          ),
          
          // Data rows
          Padding(
            padding: EdgeInsets.all(RetroSpacing.sm),
            child: Column(
              children: rows.map((row) => Padding(
                padding: EdgeInsets.symmetric(vertical: RetroSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: RetroColors.warmTaupe,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      row.value,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: row.valueColor ?? accent,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ArchitecturalDataRow {
  final String label;
  final String value;
  final Color? valueColor;

  ArchitecturalDataRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

/// Floating action button with holographic styling
class HolographicFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;

  const HolographicFAB({
    super.key,
    this.onPressed,
    required this.child,
    this.color,
  });

  @override
  State<HolographicFAB> createState() => _HolographicFABState();
}

class _HolographicFABState extends State<HolographicFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _warmPulseController;

  @override
  void initState() {
    super.initState();
    _warmPulseController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _warmPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? RetroColors.primaryTerracotta;
    
    return AnimatedBuilder(
      animation: _warmPulseController,
      builder: (context, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withOpacity(0.85),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: RetroSizes.subtleBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.12 + (_warmPulseController.value * 0.08)),
                blurRadius: 16 + (_warmPulseController.value * 4),
                spreadRadius: 1 + (_warmPulseController.value * 0.5),
              ),
              BoxShadow(
                color: RetroColors.stoneBeige.withOpacity(0.15),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: widget.onPressed,
              child: Center(child: widget.child),
            ),
          ),
        );
      },
    );
  }
}

/// Warm architectural progress indicator with tactile styling
class ArchitecturalProgress extends StatefulWidget {
  final double value;
  final Color? color;
  final double height;

  const ArchitecturalProgress({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  @override
  State<ArchitecturalProgress> createState() => _ArchitecturalProgressState();
}

class _ArchitecturalProgressState extends State<ArchitecturalProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _warmShimmerController;

  @override
  void initState() {
    super.initState();
    _warmShimmerController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _warmShimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? RetroColors.primaryTerracotta;
    
    return AnimatedBuilder(
      animation: _warmShimmerController,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            color: RetroColors.warmSurface,
            border: Border.all(
              color: RetroColors.primaryTerracotta.withOpacity(0.15),
              width: RetroSizes.subtleBorder,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.height / 2),
            child: Stack(
              children: [
                // Progress fill
                FractionallySizedBox(
                  widthFactor: widget.value.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withOpacity(0.8),
                          color,
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Subtle shimmer effect
                if (widget.value > 0)
                  Positioned(
                    left: (widget.value * 300 * _warmShimmerController.value) - 30,
                    child: Container(
                      width: 30,
                      height: widget.height,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            RetroColors.ivoryWhite.withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}