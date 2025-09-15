import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/book_models.dart';
import '../../services/voice_service.dart';
import '../../services/player_state_service.dart';
import '../widgets/enhanced_book_cover.dart';
import '../widgets/voice_chat_button.dart';

/// Full-screen voice chat interface with book cover animation
class VoiceChatScreen extends StatefulWidget {
  final BrowseBook book;

  const VoiceChatScreen({
    super.key,
    required this.book,
  });

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  late AnimationController _morphController;
  late AnimationController _waveformController;
  late Animation<double> _morphAnimation;
  late Animation<double> _waveformAnimation;
  
  VoiceService? _voiceService;
  bool _isInitialized = false;
  String _currentPersona = "Loading...";
  
  // Auto-resume state
  bool _wasPlayingBeforeVoiceChat = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOutCubic,
    );

    _waveformAnimation = CurvedAnimation(
      parent: _waveformController,
      curve: Curves.easeInOut,
    );

    _pausePlaybackForVoiceChat();
    _initializeVoiceService();
  }

  @override
  void dispose() {
    _resumePlaybackAfterVoiceChat();
    _morphController.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  void _pausePlaybackForVoiceChat() {
    final playerService = PlayerStateService.instance;
    _wasPlayingBeforeVoiceChat = playerService.isPlaying;
    if (_wasPlayingBeforeVoiceChat) {
      playerService.pause();
    }
  }

  void _resumePlaybackAfterVoiceChat() {
    if (_wasPlayingBeforeVoiceChat) {
      PlayerStateService.instance.play();
    }
  }

  Future<void> _initializeVoiceService() async {
    _voiceService = VoiceService();
    final success = await _voiceService!.initialize();
    
    if (mounted) {
      setState(() {
        _isInitialized = success;
      });
      
      if (success) {
        // Start morph animation when initialized
        _morphController.forward();
      }
    }
  }

  void _onVoiceStateChanged(VoiceChatState state) {
    switch (state) {
      case VoiceChatState.listening:
      case VoiceChatState.speaking:
        if (!_waveformController.isAnimating) {
          _waveformController.repeat(reverse: true);
        }
        break;
      default:
        _waveformController.stop();
        _waveformController.reset();
        break;
    }
  }

  void _toggleVoiceChat() async {
    if (_voiceService == null || !_isInitialized) return;

    switch (_voiceService!.state) {
      case VoiceChatState.idle:
        await _voiceService!.startListening();
        break;
      case VoiceChatState.listening:
        await _voiceService!.stopListening();
        break;
      case VoiceChatState.speaking:
        await _voiceService!.stopSpeaking();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Voice Chat',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ChangeNotifierProvider.value(
        value: _voiceService,
        child: Consumer<VoiceService>(
          builder: (context, voiceService, child) {
            // Update waveform animation based on voice state
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onVoiceStateChanged(voiceService.state);
            });

            return SafeArea(
              child: Column(
                children: [
                  // Book info header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          widget.book.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By ${widget.book.author}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Book cover / orb
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _morphAnimation,
                        builder: (context, child) {
                          return AnimatedBuilder(
                            animation: _waveformAnimation,
                            builder: (context, child) {
                              final waveformScale = 1.0 + (_waveformAnimation.value * 0.05);
                              final morphRadius = _morphAnimation.value * 200.0;
                              final blur = _morphAnimation.value * 0.7;

                              return Transform.scale(
                                scale: waveformScale,
                                child: Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      140 - (morphRadius * 0.5), // Square to circle
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                        blurRadius: 20.0 + (blur * 10),
                                        spreadRadius: 2.0,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      140 - (morphRadius * 0.5),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        EnhancedBookCover(
                                          coverImageUrl: widget.book.coverImageUrl,
                                          bookTitle: widget.book.title,
                                          bookAuthor: widget.book.author,
                                          width: 280,
                                          height: 280,
                                          enableZoom: false, // Disable zoom in voice chat
                                        ),
                                        // Blur overlay
                                        if (blur > 0)
                                          Container(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: blur * 0.2),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Voice status and persona info
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Voice status indicator
                        VoiceChatStatusIndicator(
                          state: voiceService.state,
                          confidenceLevel: voiceService.confidenceLevel,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Current persona
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentPersona,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Transcription display
                        if (voiceService.wordsSpoken.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You said:',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  voiceService.wordsSpoken,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Voice chat controls
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Reset button
                        IconButton(
                          onPressed: () {
                            voiceService.reset();
                            _morphController.reset();
                          },
                          icon: const Icon(Icons.refresh),
                          iconSize: 32,
                          tooltip: 'Reset',
                        ),

                        // Main voice chat button
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: VoiceChatButton(
                            book: widget.book,
                            heroTag: 'voice_chat_main',
                            onPressed: _toggleVoiceChat,
                          ),
                        ),

                        // Settings button (placeholder)
                        IconButton(
                          onPressed: () {
                            // TODO: Open voice chat settings
                          },
                          icon: const Icon(Icons.settings),
                          iconSize: 32,
                          tooltip: 'Settings',
                        ),
                      ],
                    ),
                  ),

                  // Initialization status
                  if (!_isInitialized)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(
                            'Initializing voice chat...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}