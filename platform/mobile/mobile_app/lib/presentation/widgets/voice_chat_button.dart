import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/voice_service.dart';
import '../../data/models/book_models.dart';
import '../screens/voice_chat_screen.dart';
import '../../core/services/connectivity_service.dart';

/// Floating action button for voice chat with visual state indicators
class VoiceChatButton extends StatefulWidget {
  final BrowseBook book;
  final String heroTag;
  final VoidCallback? onPressed;

  const VoiceChatButton({
    super.key,
    required this.book,
    this.heroTag = 'voice_chat',
    this.onPressed,
  });

  @override
  State<VoiceChatButton> createState() => _VoiceChatButtonState();
}

class _VoiceChatButtonState extends State<VoiceChatButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulsing animation for listening state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Scale animation for press feedback
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onPressed() {
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Scale animation
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });

    // Custom onPressed or navigate to voice chat
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      _navigateToVoiceChat();
    }
  }

  void _navigateToVoiceChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VoiceChatScreen(book: widget.book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceService>(
      builder: (context, voiceService, child) {
        final theme = Theme.of(context);
        final isOffline = connectivityService.isOffline;
        
        // Update pulse animation based on voice state
        switch (voiceService.state) {
          case VoiceChatState.listening:
            if (!_pulseController.isAnimating) {
              _pulseController.repeat(reverse: true);
            }
            break;
          case VoiceChatState.speaking:
            if (!_pulseController.isAnimating) {
              _pulseController.repeat(reverse: true);
            }
            break;
          default:
            _pulseController.stop();
            _pulseController.reset();
            break;
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value * _pulseAnimation.value,
              child: FloatingActionButton(
                heroTag: widget.heroTag,
                backgroundColor: isOffline 
                  ? theme.colorScheme.outline.withOpacity(0.3)
                  : _getBackgroundColor(voiceService.state, theme),
                foregroundColor: _getForegroundColor(voiceService.state, theme),
                onPressed: isOffline ? null : _onPressed,
                elevation: isOffline ? 0 : _getElevation(voiceService.state),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _getIcon(voiceService.state, isOffline),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getBackgroundColor(VoiceChatState state, ThemeData theme) {
    switch (state) {
      case VoiceChatState.listening:
        return theme.colorScheme.secondary;
      case VoiceChatState.speaking:
        return theme.colorScheme.primary;
      case VoiceChatState.processing:
        return theme.colorScheme.tertiary;
      case VoiceChatState.error:
        return theme.colorScheme.error;
      case VoiceChatState.idle:
        return theme.colorScheme.secondary;
    }
  }

  Color _getForegroundColor(VoiceChatState state, ThemeData theme) {
    switch (state) {
      case VoiceChatState.listening:
        return theme.colorScheme.onSecondary;
      case VoiceChatState.speaking:
        return theme.colorScheme.onPrimary;
      case VoiceChatState.processing:
        return theme.colorScheme.onTertiary;
      case VoiceChatState.error:
        return theme.colorScheme.onError;
      case VoiceChatState.idle:
        return theme.colorScheme.onSecondary;
    }
  }

  double _getElevation(VoiceChatState state) {
    switch (state) {
      case VoiceChatState.listening:
        return 8.0;
      case VoiceChatState.speaking:
        return 12.0;
      case VoiceChatState.processing:
        return 6.0;
      case VoiceChatState.error:
        return 4.0;
      case VoiceChatState.idle:
        return 6.0;
    }
  }

  Widget _getIcon(VoiceChatState state, bool isOffline) {
    if (isOffline) {
      return Icon(
        Icons.mic_off,
        key: ValueKey('mic_off'),
      );
    }

    switch (state) {
      case VoiceChatState.listening:
        return Icon(
          Icons.mic,
          key: ValueKey('mic_listening'),
        );
      case VoiceChatState.speaking:
        return Icon(
          Icons.volume_up,
          key: ValueKey('volume_up'),
        );
      case VoiceChatState.processing:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            key: ValueKey('processing'),
          ),
        );
      case VoiceChatState.error:
        return Icon(
          Icons.error_outline,
          key: ValueKey('error'),
        );
      case VoiceChatState.idle:
        return Icon(
          Icons.mic,
          key: ValueKey('mic_idle'),
        );
    }
  }
}

/// Simple microphone button for mini player or other compact locations
class MicrophoneButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;
  final bool isActive;

  const MicrophoneButton({
    super.key,
    this.onPressed,
    this.size = 24.0,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        Icons.mic,
        size: size,
        color: isActive 
          ? theme.colorScheme.secondary
          : theme.colorScheme.onSurface.withOpacity(0.7),
      ),
      tooltip: 'Voice Chat',
    );
  }
}

/// Voice chat status indicator widget
class VoiceChatStatusIndicator extends StatelessWidget {
  final VoiceChatState state;
  final double? confidenceLevel;

  const VoiceChatStatusIndicator({
    super.key,
    required this.state,
    this.confidenceLevel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(state, theme).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(state, theme).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(state),
            size: 16,
            color: _getStatusColor(state, theme),
          ),
          const SizedBox(width: 6),
          Text(
            state.displayName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _getStatusColor(state, theme),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (confidenceLevel != null && state == VoiceChatState.listening) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              height: 4,
              child: LinearProgressIndicator(
                value: confidenceLevel,
                backgroundColor: _getStatusColor(state, theme).withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation(_getStatusColor(state, theme)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(VoiceChatState state, ThemeData theme) {
    switch (state) {
      case VoiceChatState.listening:
        return theme.colorScheme.secondary;
      case VoiceChatState.speaking:
        return theme.colorScheme.primary;
      case VoiceChatState.processing:
        return theme.colorScheme.tertiary;
      case VoiceChatState.error:
        return theme.colorScheme.error;
      case VoiceChatState.idle:
        return theme.colorScheme.outline;
    }
  }

  IconData _getStatusIcon(VoiceChatState state) {
    switch (state) {
      case VoiceChatState.listening:
        return Icons.mic;
      case VoiceChatState.speaking:
        return Icons.volume_up;
      case VoiceChatState.processing:
        return Icons.hourglass_empty;
      case VoiceChatState.error:
        return Icons.error_outline;
      case VoiceChatState.idle:
        return Icons.mic_none;
    }
  }
}