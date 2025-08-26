import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/retro_theme.dart';
import 'dart:math' as math;

/// Space Command Panel - Mission control styled card with orbital glow effects
class SpaceCommandPanel extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? accentColor;

  const SpaceCommandPanel({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
    this.onTap,
    this.accentColor,
  });

  @override
  State<SpaceCommandPanel> createState() => _SpaceCommandPanelState();
}

class _SpaceCommandPanelState extends State<SpaceCommandPanel>
    with TickerProviderStateMixin {
  late AnimationController _orbitalGlowController;
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    
    _orbitalGlowController = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbitalGlowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? SpaceColors.dustyRed;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_orbitalGlowController, _pulseController]),
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(SpaceSizes.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: SpaceColors.commandGradient,
            ),
            border: Border.all(
              width: SpaceSizes.subtleBorder,
              color: Color.lerp(
                accentColor.withValues(alpha: 0.3),
                SpaceColors.tealBlue.withValues(alpha: 0.4),
                _orbitalGlowController.value,
              )!,
            ),
            boxShadow: [
              // Primary orbital glow
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15 + (_pulseController.value * 0.1)),
                blurRadius: 20 + (_pulseController.value * 8),
                spreadRadius: 2 + (_pulseController.value * 1),
                offset: Offset(0, 4),
              ),
              // Secondary atmospheric glow
              BoxShadow(
                color: SpaceColors.tealBlue.withValues(alpha: 0.08 + (_orbitalGlowController.value * 0.05)),
                blurRadius: 32,
                offset: Offset(0, 8),
              ),
              // Subtle space depth
              BoxShadow(
                color: SpaceColors.spaceShadow,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(SpaceSizes.borderRadius),
              onTap: widget.onTap,
              child: Padding(
                padding: widget.padding ?? EdgeInsets.all(SpaceSpacing.md),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Orbital Control Button - Space mission control button with launch/landing effects
class OrbitButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final Color? color;
  final BorderRadius? borderRadius;
  final bool isCircular;

  const OrbitButton({
    super.key,
    required this.child,
    this.onPressed,
    this.width,
    this.height,
    this.color,
    this.borderRadius,
    this.isCircular = false,
  });

  @override
  State<OrbitButton> createState() => _OrbitButtonState();
}

class _OrbitButtonState extends State<OrbitButton> with TickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      duration: Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SpaceColors.dustyRed;
    final size = widget.width ?? widget.height ?? 56.0;
    
    return AnimatedBuilder(
      animation: _orbitController,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: SpaceAnimations.ultraFast,
            curve: _isPressed ? SpaceAnimations.landingEase : SpaceAnimations.launchEase,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.isCircular 
                  ? BorderRadius.circular(size / 2)
                  : (widget.borderRadius ?? BorderRadius.circular(SpaceSizes.borderRadius)),
              gradient: RadialGradient(
                center: Alignment.center,
                radius: _isPressed ? 0.5 : 1.0,
                colors: [
                  color.withValues(alpha: 0.9),
                  color.withValues(alpha: 0.7),
                  color.withValues(alpha: 0.8),
                ],
                stops: [0.0, 0.7, 1.0],
              ),
              border: Border.all(
                color: SpaceColors.goldenYellow.withValues(alpha: 0.4 + (_orbitController.value * 0.2)),
                width: SpaceSizes.subtleBorder,
              ),
              boxShadow: _isPressed ? [
                // Landing effect - compressed glow
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                  spreadRadius: 1,
                ),
              ] : [
                // Launch effect - expanded orbital glow
                BoxShadow(
                  color: color.withValues(alpha: 0.3 + (_orbitController.value * 0.1)),
                  blurRadius: 16 + (_orbitController.value * 4),
                  offset: Offset(0, 4),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: SpaceColors.goldenYellow.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Center(child: widget.child),
          ),
        );
      },
    );
  }
}

/// Mission Data Panel - Space command interface for technical readouts
class MissionDataPanel extends StatelessWidget {
  final String title;
  final List<MissionDataRow> rows;
  final Color? accentColor;
  final bool isActive;

  const MissionDataPanel({
    super.key,
    required this.title,
    required this.rows,
    this.accentColor,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? SpaceColors.tealBlue;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SpaceSizes.smallRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: SpaceColors.commandGradient,
        ),
        border: Border.all(
          color: isActive 
              ? accent.withValues(alpha: 0.5) 
              : accent.withValues(alpha: 0.2),
          width: isActive ? 2.0 : SpaceSizes.subtleBorder,
        ),
        boxShadow: [
          if (isActive) 
            BoxShadow(
              color: accent.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: Offset(0, 4),
              spreadRadius: 1,
            ),
          BoxShadow(
            color: SpaceColors.spaceShadow,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mission Control Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(SpaceSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(SpaceSizes.smallRadius),
                topRight: Radius.circular(SpaceSizes.smallRadius),
              ),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.15),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: accent.withValues(alpha: 0.3),
                  width: SpaceSizes.subtleBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? SpaceColors.successGreen : accent,
                    boxShadow: [
                      BoxShadow(
                        color: (isActive ? SpaceColors.successGreen : accent).withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Technical Data Readouts
          Padding(
            padding: EdgeInsets.all(SpaceSpacing.sm),
            child: Column(
              children: rows.map((row) => Padding(
                padding: EdgeInsets.symmetric(vertical: SpaceSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: SpaceColors.commandGray,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      row.value,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: row.valueColor ?? SpaceColors.goldenYellow,
                        letterSpacing: 0.3,
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

class MissionDataRow {
  final String label;
  final String value;
  final Color? valueColor;

  MissionDataRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

// Legacy compatibility
class ArchitecturalDataRow extends MissionDataRow {
  ArchitecturalDataRow({
    required String label,
    required String value,
    Color? valueColor,
  }) : super(label: label, value: value, valueColor: valueColor);
}

/// Orbital Floating Action Button - Space satellite control with orbital rotation
class OrbitalFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final double size;

  const OrbitalFAB({
    super.key,
    this.onPressed,
    required this.child,
    this.color,
    this.size = 56.0,
  });

  @override
  State<OrbitalFAB> createState() => _OrbitalFABState();
}

class _OrbitalFABState extends State<OrbitalFAB>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _satellitePulseController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      duration: Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    _satellitePulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _satellitePulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SpaceColors.dustyRed;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_orbitController, _satellitePulseController]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Orbital ring indicator
            Container(
              width: widget.size + 12,
              height: widget.size + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SpaceColors.tealBlue.withValues(alpha: 0.3 + (_orbitController.value * 0.2)),
                  width: 1,
                ),
              ),
            ),
            
            // Main satellite button
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  colors: [
                    color,
                    color.withValues(alpha: 0.8),
                    color.withValues(alpha: 0.9),
                  ],
                  stops: [0.0, 0.7, 1.0],
                ),
                border: Border.all(
                  color: SpaceColors.goldenYellow.withValues(alpha: 0.4),
                  width: SpaceSizes.subtleBorder,
                ),
                boxShadow: [
                  // Primary orbital glow
                  BoxShadow(
                    color: color.withValues(alpha: 0.4 + (_satellitePulseController.value * 0.2)),
                    blurRadius: 20 + (_satellitePulseController.value * 8),
                    spreadRadius: 3 + (_satellitePulseController.value * 2),
                  ),
                  // Secondary space glow
                  BoxShadow(
                    color: SpaceColors.tealBlue.withValues(alpha: 0.2),
                    blurRadius: 32,
                    offset: Offset(0, 4),
                  ),
                  // Depth shadow
                  BoxShadow(
                    color: SpaceColors.spaceShadow,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.size / 2),
                  onTap: widget.onPressed,
                  child: Center(child: widget.child),
                ),
              ),
            ),
            
            // Satellite orbital indicators
            ...List.generate(3, (index) {
              final angle = (_orbitController.value * 2 * math.pi) + (index * 2 * math.pi / 3);
              final radius = (widget.size / 2) + 10;
              return Positioned(
                left: radius * math.cos(angle) + widget.size / 2 - 2,
                top: radius * math.sin(angle) + widget.size / 2 - 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SpaceColors.goldenYellow.withValues(alpha: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: SpaceColors.goldenYellow.withValues(alpha: 0.5),
                        blurRadius: 3,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Mission Progress Indicator - Space-themed progress with orbital energy flow
class MissionProgressIndicator extends StatefulWidget {
  final double value;
  final Color? color;
  final double height;
  final bool showEnergyFlow;

  const MissionProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.height = 10,
    this.showEnergyFlow = true,
  });

  @override
  State<MissionProgressIndicator> createState() => _MissionProgressIndicatorState();
}

class _MissionProgressIndicatorState extends State<MissionProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _energyFlowController;

  @override
  void initState() {
    super.initState();
    _energyFlowController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _energyFlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SpaceColors.tealBlue;
    
    return AnimatedBuilder(
      animation: _energyFlowController,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            color: SpaceColors.warmBeige,
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: SpaceSizes.subtleBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: SpaceColors.spaceShadow,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.height / 2),
            child: Stack(
              children: [
                // Progress fill with gradient
                FractionallySizedBox(
                  widthFactor: widget.value.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          SpaceColors.goldenYellow,
                          color,
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Energy flow effect
                if (widget.showEnergyFlow && widget.value > 0)
                  Positioned(
                    left: (widget.value * 300 * _energyFlowController.value) - 20,
                    child: Container(
                      width: 20,
                      height: widget.height,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            SpaceColors.starWhite.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(widget.height / 2),
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

// Legacy Component Mappings for Backward Compatibility
class ArchitecturalCard extends SpaceCommandPanel {
  const ArchitecturalCard({
    super.key,
    required Widget child,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) : super(
    child: child,
    width: width,
    height: height,
    borderRadius: borderRadius,
    padding: padding,
    onTap: onTap,
  );
}

class TactileButton extends OrbitButton {
  const TactileButton({
    super.key,
    required Widget child,
    VoidCallback? onPressed,
    double? width,
    double? height,
    Color? color,
    BorderRadius? borderRadius,
  }) : super(
    child: child,
    onPressed: onPressed,
    width: width,
    height: height,
    color: color,
    borderRadius: borderRadius,
  );
}

class ArchitecturalPanel extends MissionDataPanel {
  const ArchitecturalPanel({
    super.key,
    required String title,
    required List<ArchitecturalDataRow> rows,
    Color? accentColor,
  }) : super(
    title: title,
    rows: rows,
    accentColor: accentColor,
  );
}

class HolographicFAB extends OrbitalFAB {
  const HolographicFAB({
    super.key,
    VoidCallback? onPressed,
    required Widget child,
    Color? color,
  }) : super(
    onPressed: onPressed,
    child: child,
    color: color,
  );
}

class ArchitecturalProgress extends MissionProgressIndicator {
  const ArchitecturalProgress({
    super.key,
    required double value,
    Color? color,
    double height = 8,
  }) : super(value: value, color: color, height: height);
}

/// Loading State Components for Better UX
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: ArchitecturalAnimations.slow,
      vsync: this,
    )..repeat();
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: ArchitecturalAnimations.smoothEase,
    ));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.5, 1.0],
              colors: [
                ArchitecturalColors.lightGray,
                ArchitecturalColors.cardWhite,
                ArchitecturalColors.lightGray,
              ],
              transform: GradientRotation(_shimmerAnimation.value * 3.14159),
            ),
          ),
        );
      },
    );
  }
}

/// Book Card Skeleton for loading states
class BookCardSkeleton extends StatelessWidget {
  const BookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ArchitecturalSpacing.lg),
      decoration: BoxDecoration(
        color: ArchitecturalColors.pureWhite,
        borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
        border: Border.all(
          color: ArchitecturalColors.lightGray,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ArchitecturalColors.shadowBlack.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Book icon skeleton
          SkeletonLoader(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(8),
          ),
          SizedBox(width: ArchitecturalSpacing.md),
          
          // Book info skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
                SizedBox(height: 6),
                SkeletonLoader(
                  width: 120,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                SizedBox(height: 4),
                SkeletonLoader(
                  width: 80,
                  height: 11,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          
          // Play button skeleton
          SkeletonLoader(
            width: 36,
            height: 36,
            borderRadius: BorderRadius.circular(18),
          ),
        ],
      ),
    );
  }
}

/// Error State Component
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.actionText,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ArchitecturalSpacing.xl),
      decoration: BoxDecoration(
        color: ArchitecturalColors.pureWhite,
        borderRadius: BorderRadius.circular(ArchitecturalSizes.borderRadius),
        border: Border.all(
          color: ArchitecturalColors.errorRed.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ArchitecturalColors.errorRed.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: ArchitecturalColors.errorRed,
            size: 48,
          ),
          SizedBox(height: ArchitecturalSpacing.md),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ArchitecturalColors.deepBlack,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: ArchitecturalColors.mediumGray,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onRetry != null) ...[
            SizedBox(height: ArchitecturalSpacing.lg),
            Semantics(
              label: 'Retry $actionText',
              hint: 'Double tap to retry the failed action',
              button: true,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh, size: 18),
                label: Text(actionText!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ArchitecturalColors.primaryOrange,
                  foregroundColor: ArchitecturalColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}