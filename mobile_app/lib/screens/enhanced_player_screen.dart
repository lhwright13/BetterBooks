import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/app_state.dart';
import '../services/api_service.dart';

class EnhancedPlayerScreen extends StatefulWidget {
  @override
  _EnhancedPlayerScreenState createState() => _EnhancedPlayerScreenState();
}

class _EnhancedPlayerScreenState extends State<EnhancedPlayerScreen> {
  double _playbackSpeed = 1.0;
  bool _isProcessingVoice = false;
  bool _wasPlayingBeforeVoice = false;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.personas.isEmpty) {
        appState.loadPersonas();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Now Playing'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.chat),
            onPressed: () => Navigator.pushNamed(context, '/chat'),
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
                  Icon(Icons.music_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No book selected',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Go to Library'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Book cover
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            'http://localhost:8000/books/cover/${Uri.encodeComponent(book.title)}',
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.book,
                                  size: 80,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Book title
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      if (chapter != null) ...[
                        SizedBox(height: 8),
                        Text(
                          chapter.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      
                      if (book.author != null) ...[
                        SizedBox(height: 8),
                        Text(
                          book.author!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      
                      SizedBox(height: 32),
                      
                      // Playback Controls Card
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Current Chapter and Speed Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Current Chapter
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Chapter',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Text(
                                        chapter?.title ?? 'Single Book',
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                  
                                  // Playback Speed
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Speed',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      DropdownButton<double>(
                                        value: _playbackSpeed,
                                        items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                                            .map((speed) => DropdownMenuItem(
                                                  value: speed,
                                                  child: Text('${speed}x'),
                                                ))
                                            .toList(),
                                        onChanged: (speed) {
                                          setState(() {
                                            _playbackSpeed = speed ?? 1.0;
                                          });
                                          // TODO: Apply playback speed to audio player
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Playback speed: ${speed}x')),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 16),
                              
                              // AI Persona Dropdown
                              Row(
                                children: [
                                  Icon(Icons.smart_toy, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI Persona:',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: appState.selectedPersona?.name,
                                      hint: Text('Select Persona'),
                                      items: appState.personas
                                          .map((persona) => DropdownMenuItem(
                                                value: persona.name,
                                                child: Text(persona.displayName),
                                              ))
                                          .toList(),
                                      onChanged: (personaName) {
                                        if (personaName != null) {
                                          final persona = appState.personas
                                              .firstWhere((p) => p.name == personaName);
                                          appState.selectPersona(persona);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Voice AI Button
                      Container(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessingVoice ? null : _startVoiceQuery,
                          icon: _isProcessingVoice
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.mic_none, size: 24),
                          label: Text(
                            _isProcessingVoice
                                ? 'Processing...'
                                : 'Ask AI with voice',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Audio controls at bottom
              Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Progress bar
                    Row(
                      children: [
                        Text(
                          _formatDuration(appState.currentPosition),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Expanded(
                          child: Slider(
                            value: appState.totalDuration.inSeconds > 0
                                ? appState.currentPosition.inSeconds.toDouble()
                                : 0.0,
                            max: appState.totalDuration.inSeconds.toDouble(),
                            onChanged: (value) {
                              appState.seekTo(Duration(seconds: value.toInt()));
                            },
                          ),
                        ),
                        Text(
                          _formatDuration(appState.totalDuration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            final newPosition = appState.currentPosition - Duration(seconds: 30);
                            appState.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
                          },
                          icon: Icon(Icons.replay_30),
                          iconSize: 36,
                        ),
                        
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: appState.playPause,
                            icon: Icon(
                              appState.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            iconSize: 48,
                          ),
                        ),
                        
                        IconButton(
                          onPressed: () {
                            final newPosition = appState.currentPosition + Duration(seconds: 30);
                            appState.seekTo(newPosition < appState.totalDuration ? newPosition : appState.totalDuration);
                          },
                          icon: Icon(Icons.forward_30),
                          iconSize: 36,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  void _startVoiceQuery() async {
    final appState = context.read<AppState>();
    
    if (appState.selectedPersona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an AI persona first')),
      );
      return;
    }

    // Pause audio if playing
    _wasPlayingBeforeVoice = appState.isPlaying;
    if (_wasPlayingBeforeVoice) {
      appState.playPause();
    }

    // Show voice input dialog (simulating speech-to-text for demonstration)
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mic, color: Colors.red),
            SizedBox(width: 8),
            Text('Voice Query'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Simulating voice input (speech-to-text not available in demo)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type your voice question here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Resume audio if it was playing
              if (_wasPlayingBeforeVoice) {
                context.read<AppState>().playPause();
              }
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                _processVoiceQuery(text);
              }
            },
            child: Text('Send Voice Query'),
          ),
        ],
      ),
    );
  }

  void _processVoiceQuery(String voiceText) async {
    if (voiceText.trim().isEmpty) {
      // Resume audio if it was playing
      if (_wasPlayingBeforeVoice) {
        context.read<AppState>().playPause();
      }
      return;
    }

    setState(() {
      _isProcessingVoice = true;
    });

    try {
      final appState = context.read<AppState>();
      
      // Process voice query through app state (this will log it to chat)
      final response = await appState.processVoiceQuery(voiceText);
      
      // Synthesize speech response
      final audioData = await ApiService.synthesizeSpeech(
        response,
        appState.selectedPersona!.name,
      );

      // Play the audio response (base64 encoded)
      if (audioData.isNotEmpty) {
        // TODO: Implement audio playback from base64 data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice response ready (audio playback not yet implemented)'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice query processed! Check chat for details.'),
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing voice: $e')),
      );
    } finally {
      setState(() {
        _isProcessingVoice = false;
      });
      
      // Resume audio if it was playing
      if (_wasPlayingBeforeVoice) {
        context.read<AppState>().playPause();
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${minutes}:${twoDigits(seconds)}';
    }
  }
}