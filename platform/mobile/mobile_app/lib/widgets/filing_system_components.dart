import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/retro_theme.dart';

// Index Card Component - Inspired by the filing system image
class IndexCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? metadata;
  final Widget? leading;
  final VoidCallback? onTap;
  final Color? tabColor;
  final bool isSelected;

  const IndexCard({
    super.key,
    required this.title,
    this.subtitle,
    this.metadata,
    this.leading,
    this.onTap,
    this.tabColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFF16213E) : Color(0xFF0F0F23),
              border: Border.all(
                color: isSelected 
                    ? RetroColors.neonCyan 
                    : RetroColors.gridBlue.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: RetroColors.neonCyan.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
            child: Stack(
              children: [
                // Tab indicator (like index card tabs)
                if (tabColor != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 24,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tabColor,
                        border: Border.all(
                          color: RetroColors.gridBlue.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          metadata ?? '',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Main content
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.sourceCodePro(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected 
                                    ? RetroColors.neonCyan 
                                    : RetroColors.orangeGlow,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (subtitle != null) ...[
                              SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: GoogleFonts.sourceCodePro(
                                  fontSize: 10,
                                  color: RetroColors.orangeGlow.withValues(alpha: 0.8),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (tabColor == null && metadata != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: RetroColors.gridBlue.withValues(alpha: 0.2),
                            border: Border.all(
                              color: RetroColors.gridBlue.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            metadata!,
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: RetroColors.phosphorGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// File Drawer Component - Multi-level filing system
class FileDrawer extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Color? tabColor;

  const FileDrawer({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
    this.tabColor,
  });

  @override
  State<FileDrawer> createState() => _FileDrawerState();
}

class _FileDrawerState extends State<FileDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: RetroAnimations.medium,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF0F0F23),
        border: Border.all(
          color: RetroColors.gridBlue.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drawer header/tab
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.tabColor?.withValues(alpha: 0.2) ?? Color(0xFF16213E),
                  border: Border(
                    bottom: BorderSide(
                      color: RetroColors.gridBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: _isExpanded ? 0.25 : 0,
                      duration: RetroAnimations.medium,
                      child: Icon(
                        Icons.chevron_right,
                        color: RetroColors.terminalGreen,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: RetroColors.terminalGreen,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: RetroColors.orangeGlow.withValues(alpha: 0.2),
                        border: Border.all(
                          color: RetroColors.orangeGlow.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${widget.children.length}',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: RetroColors.orangeGlow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: EdgeInsets.only(left: 24, right: 8, bottom: 8),
              child: Column(
                children: widget.children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Terminal Window Component - Like computer interfaces from the 80s
class TerminalWindow extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? titleBarColor;

  const TerminalWindow({
    super.key,
    required this.title,
    required this.child,
    this.titleBarColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF0F0F23),
        border: Border.all(
          color: RetroColors.gridBlue.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: RetroColors.neonCyan.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: titleBarColor ?? Color(0xFF16213E),
              border: Border(
                bottom: BorderSide(
                  color: RetroColors.gridBlue.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Terminal icons
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: RetroColors.vhsRed,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: RetroColors.vhsYellow,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: RetroColors.phosphorGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: RetroColors.orangeGlow,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content area
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

// VHS-style Progress Bar
class VhsProgressBar extends StatelessWidget {
  final double value;
  final Color? color;

  const VhsProgressBar({
    super.key,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Color(0xFF0F0F23),
        border: Border.all(
          color: RetroColors.gridBlue.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color ?? RetroColors.neonCyan,
                (color ?? RetroColors.neonCyan).withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}