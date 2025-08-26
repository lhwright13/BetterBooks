import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_state.dart';
import '../models/persona.dart';
import '../services/api_service.dart';
import '../theme/echowright_theme.dart';
import 'chat_screen.dart';
import 'voice_mode_screen.dart';

class MVPPlayerScreen extends StatefulWidget {
  const MVPPlayerScreen({super.key});

  @override
  State<MVPPlayerScreen> createState() => _MVPPlayerScreenState();
}

class _MVPPlayerScreenState extends State<MVPPlayerScreen> {
  double _playbackSpeed = 1.0;
  Duration _sleepTimer = Duration.zero;
  bool _sleepTimerActive = false;
  List<Persona> _availablePersonas = [];
  Persona? _selectedPersona;

  @override
  void initState() {
    super.initState();
    _loadPersonas();
  }

  Future<void> _loadPersonas() async {
    final appState = context.read<AppState>();
    try {
      final personas = await ApiService.getPersonas();
      setState(() {
        _availablePersonas = personas;
        _selectedPersona = personas.isNotEmpty ? personas.first : null;
      });
    } catch (e) {
      // If personas fail to load, use the ones from app state as fallback
      setState(() {
        _availablePersonas = appState.personas;
        _selectedPersona = appState.personas.isNotEmpty ? appState.personas.first : null;
      });
    }
  }

  void _skipSeconds(int seconds) {
    final appState = context.read<AppState>();
    final currentPosition = appState.currentPosition;
    final newPosition = Duration(
      milliseconds: currentPosition.inMilliseconds + (seconds * 1000),
    );
    
    if (newPosition.inMilliseconds >= 0) {
      appState.audioPlayer.seek(newPosition);
    }
  }

  void _changePlaybackSpeed() {
    setState(() {
      switch (_playbackSpeed) {
        case 0.5:
          _playbackSpeed = 0.75;
          break;
        case 0.75:
          _playbackSpeed = 1.0;
          break;
        case 1.0:
          _playbackSpeed = 1.25;
          break;
        case 1.25:
          _playbackSpeed = 1.5;
          break;
        case 1.5:
          _playbackSpeed = 2.0;
          break;
        case 2.0:
          _playbackSpeed = 0.5;
          break;
        default:
          _playbackSpeed = 1.0;
      }
    });
    
    context.read<AppState>().audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  void _setSleepTimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EchoWrightTheme.surfaceDark,
        title: Text(
          'Sleep Timer',
          style: TextStyle(color: EchoWrightTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Off', style: TextStyle(color: EchoWrightTheme.textPrimary)),
              onTap: () {
                setState(() {
                  _sleepTimer = Duration.zero;
                  _sleepTimerActive = false;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('15 minutes', style: TextStyle(color: EchoWrightTheme.textPrimary)),
              onTap: () => _startSleepTimer(15),
            ),
            ListTile(
              title: Text('30 minutes', style: TextStyle(color: EchoWrightTheme.textPrimary)),
              onTap: () => _startSleepTimer(30),
            ),
            ListTile(
              title: Text('1 hour', style: TextStyle(color: EchoWrightTheme.textPrimary)),
              onTap: () => _startSleepTimer(60),
            ),
          ],
        ),
      ),
    );
  }

  void _startSleepTimer(int minutes) {
    setState(() {
      _sleepTimer = Duration(minutes: minutes);
      _sleepTimerActive = true;
    });
    
    Future.delayed(_sleepTimer, () {
      if (_sleepTimerActive && mounted) {
        context.read<AppState>().audioPlayer.pause();
        setState(() => _sleepTimerActive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sleep timer finished - playback paused')),
        );
      }
    });
    
    Navigator.of(context).pop();
  }

  void _openPersonaSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EchoWrightTheme.surfaceDark,
        title: Text(
          'Persona Settings',
          style: TextStyle(color: EchoWrightTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select AI Persona:',
              style: TextStyle(
                color: EchoWrightTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            ..._availablePersonas.map((persona) => RadioListTile<Persona>(
              title: Text(
                persona.displayName,
                style: TextStyle(color: EchoWrightTheme.textPrimary),
              ),
              subtitle: Text(
                persona.description,
                style: TextStyle(color: EchoWrightTheme.textSecondary),
              ),
              value: persona,
              groupValue: _selectedPersona,
              activeColor: EchoWrightTheme.primaryTurquoise,
              onChanged: (value) {
                setState(() => _selectedPersona = value);
                Navigator.of(context).pop();
              },
            )).toList(),
            
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Clear chat history
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat history cleared')),
                      );
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: EchoWrightTheme.primaryCoral),
                    ),
                    child: Text(
                      'Clear History',
                      style: TextStyle(color: EchoWrightTheme.primaryCoral),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openVoiceChat() {
    final appState = context.read<AppState>();
    
    // Pause playbook
    if (appState.isPlaying) {
      appState.audioPlayer.pause();
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VoiceModeScreen(),
      ),
    ).then((_) {
      // Auto-resume playback after voice chat
      Future.delayed(const Duration(milliseconds: 500), () {
        appState.audioPlayer.resume();
      });
    });
  }

  void _openTextChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(),
      ),
    );
  }

  void _shareBook() {
    final appState = context.read<AppState>();
    final book = appState.currentBook;
    
    if (book != null) {
      Share.share(
        'I\'m listening to "${book.title}" by ${book.author ?? 'Unknown Author'} on EchoWright! Great book with amazing AI personas to chat with.',
        subject: 'Check out this audiobook!',
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EchoWrightTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: EchoWrightTheme.backgroundDark,
        foregroundColor: EchoWrightTheme.textPrimary,
        title: const Text('Now Playing'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _shareBook,
            icon: const Icon(Icons.share),
            tooltip: 'Share Book',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final book = appState.currentBook;
          final chapter = appState.currentChapter;

          if (book == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off, 
                    size: 64, 
                    color: EchoWrightTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No book selected',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: EchoWrightTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EchoWrightTheme.primaryCoral,
                    ),
                    child: const Text('Go to Library', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Book cover
                          Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: book.coverUrl != null
                                  ? Image.network(
                                      book.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _buildPlaceholderCover(),
                                    )
                                  : _buildPlaceholderCover(),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Book title
                          Text(
                            book.title,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: EchoWrightTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          if (book.author != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'by ${book.author}',
                              style: TextStyle(
                                fontSize: 16,
                                color: EchoWrightTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          
                          if (chapter != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              chapter.title,
                              style: TextStyle(
                                fontSize: 14,
                                color: EchoWrightTheme.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Progress bar
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(appState.currentPosition),
                            style: TextStyle(
                              fontSize: 14,
                              color: EchoWrightTheme.textSecondary,
                            ),
                          ),
                          if (_sleepTimerActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Sleep: ${_sleepTimer.inMinutes}m',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: EchoWrightTheme.primaryCoral,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Text(
                            _formatDuration(appState.totalDuration),
                            style: TextStyle(
                              fontSize: 14,
                              color: EchoWrightTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: EchoWrightTheme.primaryCoral,
                          inactiveTrackColor: EchoWrightTheme.surfaceDark,
                          thumbColor: EchoWrightTheme.primaryCoral,
                          overlayColor: EchoWrightTheme.primaryCoral.withValues(alpha: 0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: appState.totalDuration.inMilliseconds > 0
                              ? appState.currentPosition.inMilliseconds.toDouble()
                              : 0.0,
                          max: appState.totalDuration.inMilliseconds.toDouble(),
                          onChanged: (value) {
                            final position = Duration(milliseconds: value.toInt());
                            appState.audioPlayer.seek(position);
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Main playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // -15 seconds
                      IconButton(
                        onPressed: () => _skipSeconds(-15),
                        icon: Icon(Icons.replay_10),
                        iconSize: 32,
                        color: EchoWrightTheme.textSecondary,
                      ),
                      
                      // Play/Pause
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EchoWrightTheme.primaryCoral,
                          boxShadow: [
                            BoxShadow(
                              color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (appState.isPlaying) {
                              appState.audioPlayer.pause();
                            } else {
                              appState.audioPlayer.resume();
                            }
                          },
                          icon: Icon(
                            appState.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      
                      // +15 seconds
                      IconButton(
                        onPressed: () => _skipSeconds(15),
                        icon: Icon(Icons.forward_10),
                        iconSize: 32,
                        color: EchoWrightTheme.textSecondary,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Secondary controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Playback speed
                      TextButton(
                        onPressed: _changePlaybackSpeed,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: EchoWrightTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: EchoWrightTheme.primaryTurquoise,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Speed',
                              style: TextStyle(
                                fontSize: 12,
                                color: EchoWrightTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Sleep timer
                      TextButton(
                        onPressed: _setSleepTimer,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bedtime,
                              color: _sleepTimerActive 
                                  ? EchoWrightTheme.primaryCoral 
                                  : EchoWrightTheme.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sleep',
                              style: TextStyle(
                                fontSize: 12,
                                color: EchoWrightTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Persona settings
                      TextButton(
                        onPressed: _openPersonaSettings,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              color: EchoWrightTheme.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Persona',
                              style: TextStyle(
                                fontSize: 12,
                                color: EchoWrightTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Chat controls
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openVoiceChat,
                          icon: const Icon(Icons.mic, color: Colors.white),
                          label: const Text('Voice Chat', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EchoWrightTheme.primaryTurquoise,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openTextChat,
                          icon: Icon(
                            Icons.chat,
                            color: EchoWrightTheme.primaryTurquoise,
                          ),
                          label: Text(
                            'Text Chat',
                            style: TextStyle(color: EchoWrightTheme.primaryTurquoise),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: EchoWrightTheme.primaryTurquoise),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: EchoWrightTheme.surfaceDark,
      child: Icon(
        Icons.library_music,
        size: 80,
        color: EchoWrightTheme.textMuted,
      ),
    );
  }
}