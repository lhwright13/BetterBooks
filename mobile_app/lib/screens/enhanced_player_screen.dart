import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../api_config.dart';
import '../widgets/css_ripple_widget.dart';
import '../widgets/audio_input_handler.dart';
import '../services/web_speech_service.dart';
import '../services/api_service.dart';
import '../services/audio_player_service.dart';

class EnhancedPlayerScreen extends StatefulWidget {
  @override
  _EnhancedPlayerScreenState createState() => _EnhancedPlayerScreenState();
}

// Global question counter to persist across widget rebuilds
int _globalQuestionIndex = 0;

class _EnhancedPlayerScreenState extends State<EnhancedPlayerScreen> {
  double _playbackSpeed = 1.0;
  bool _wasPlayingBeforeVoice = false;
  bool _isVoiceModeActive = false;
  double _audioLevel = 0.0;
  String _voiceStatus = 'Listening...';

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

          return AudioInputHandler(
            isListening: _isVoiceModeActive,
            onAudioLevel: (level) {
              setState(() {
                _audioLevel = level;
              });
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Book cover with shader ripple effect
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
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
                                child: CSSRippleWidget(
                                  isActive: _isVoiceModeActive,
                                  audioLevel: _audioLevel,
                                  child: Image.network(
                                    '$apiBaseUrl/books/cover/${Uri.encodeComponent(book.title)}',
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
                          onPressed: _startVoiceQuery,
                          icon: Icon(Icons.mic_none, size: 24),
                          label: Text(
                            'Ask AI with voice',
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
          ),
          
          // Voice mode overlay - dims everything except the book cover
          if (_isVoiceModeActive)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Book cover with ripples (larger in voice mode)
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CSSRippleWidget(
                          isActive: true,
                          audioLevel: _audioLevel,
                          child: Consumer<AppState>(
                            builder: (context, appState, child) {
                              final book = appState.currentBook;
                              return Image.network(
                                '$apiBaseUrl/books/cover/${Uri.encodeComponent(book!.title)}',
                                width: 280,
                                height: 280,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 280,
                                    height: 280,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      Icons.book,
                                      size: 120,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Status text
                    Text(
                      _voiceStatus,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Audio level indicator
                    Container(
                      width: 200,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 200 * _audioLevel,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Type question button
                        ElevatedButton(
                          onPressed: _showQuickTextInput,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.keyboard, size: 20),
                              SizedBox(width: 4),
                              Text('Type'),
                            ],
                          ),
                        ),
                        
                        // Stop button
                        ElevatedButton(
                          onPressed: _stopVoiceMode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: CircleBorder(),
                            padding: EdgeInsets.all(20),
                          ),
                          child: Icon(Icons.stop, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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

    // Activate voice mode with dim screen and ripples
    setState(() {
      _isVoiceModeActive = true;
      _voiceStatus = 'Listening... Speak now!';
    });

    try {
      String voiceText;
      
      // Try Web Speech Recognition, but use fallback if it fails
      try {
        if (WebSpeechService.isSupported) {
          setState(() {
            _voiceStatus = 'Listening... Speak now! (or wait 5s for demo)';
          });
          
          // Create a timeout to provide demo question if speech fails
          voiceText = await Future.any([
            WebSpeechService.startListening(),
            Future.delayed(Duration(seconds: 5)).then((_) => 
              throw Exception('Speech timeout - using demo question')),
          ]);
          
          setState(() {
            _voiceStatus = 'Processing: "$voiceText"';
          });
        } else {
          throw Exception('Speech not supported');
        }
      } catch (speechError) {
        print('DEBUG: Speech recognition failed: $speechError');
        
        // Fallback to demo questions with variety
        final demoQuestions = [
          "What are the main themes in this chapter?",
          "Tell me about the symbolism of the green light",
          "What is Gatsby's relationship with Daisy?",
          "Explain the significance of the Valley of Ashes",
          "What does the narrator think about the characters?",
        ];
        
        voiceText = demoQuestions[_globalQuestionIndex % demoQuestions.length];
        _globalQuestionIndex++; // Increment for next time
        
        print('DEBUG: Selected question #${_globalQuestionIndex-1}: "$voiceText"');
        
        setState(() {
          _voiceStatus = 'Processing: "$voiceText" (demo question)';
        });
        
        // Brief pause to show the demo question
        await Future.delayed(Duration(seconds: 1));
      }
      
      if (mounted && _isVoiceModeActive) {
        // Get AI response
        setState(() {
          _voiceStatus = 'Getting AI response...';
        });
        
        final response = await appState.processVoiceQuery(voiceText);
        
        setState(() {
          _voiceStatus = 'Speaking response...';
        });
        
        // Use backend TTS service to synthesize speech
        try {
          final audioBase64 = await ApiService.synthesizeSpeech(
            response,
            appState.selectedPersona!.name,
          );
          
          if (audioBase64.isNotEmpty) {
            // Play the base64 audio from backend TTS
            await AudioPlayerService.playBase64Audio(audioBase64);
          } else {
            throw Exception('No audio data received from TTS service');
          }
        } catch (ttsError) {
          // Fallback to Web Speech Synthesis if backend TTS fails
          if (WebSpeechSynthesis.isSupported) {
            await WebSpeechSynthesis.speak(response);
          } else {
            // Show text fallback if both TTS methods fail
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Voice response: $response'),
                duration: Duration(seconds: 5),
              ),
            );
            await Future.delayed(Duration(seconds: 3));
          }
        }
        
        setState(() {
          _voiceStatus = 'Voice interaction complete!';
        });
        
        await Future.delayed(Duration(seconds: 1));
        _stopVoiceMode();
      }
    } catch (e) {
      setState(() {
        _voiceStatus = 'Error: ${e.toString()}';
      });
      
      await Future.delayed(Duration(seconds: 2));
      _stopVoiceMode();
    }
  }

  void _stopVoiceMode() {
    // Stop any ongoing speech recognition
    WebSpeechService.stop();
    
    // Stop any TTS audio playback
    AudioPlayerService.stop();
    
    setState(() {
      _isVoiceModeActive = false;
      _audioLevel = 0.0;
    });

    // Resume audio if it was playing
    if (_wasPlayingBeforeVoice) {
      final appState = context.read<AppState>();
      if (!appState.isPlaying) {
        appState.playPause();
      }
    }
  }

  void _showQuickTextInput() async {
    final TextEditingController controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ask AI About The Book'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'What would you like to know?',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onSubmitted: (text) {
            if (text.trim().isNotEmpty) {
              Navigator.pop(context, text.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context, text);
              }
            },
            child: Text('Ask AI'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Stop current voice mode and process the typed question
      _stopVoiceMode();
      _processTypedQuestion(result);
    }
  }

  void _processTypedQuestion(String question) async {
    final appState = context.read<AppState>();
    
    if (appState.selectedPersona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an AI persona first')),
      );
      return;
    }

    // Start voice mode for visual effects
    setState(() {
      _isVoiceModeActive = true;
      _voiceStatus = 'Processing: "$question"';
    });

    try {
      // Get AI response
      final response = await appState.processVoiceQuery(question);
      
      setState(() {
        _voiceStatus = 'Speaking response...';
      });
      
      // Use backend TTS to speak the response
      final audioBase64 = await ApiService.synthesizeSpeech(
        response,
        appState.selectedPersona!.name,
      );
      
      if (audioBase64.isNotEmpty) {
        await AudioPlayerService.playBase64Audio(audioBase64);
      }
      
      setState(() {
        _voiceStatus = 'Voice interaction complete!';
      });
      
      await Future.delayed(Duration(seconds: 1));
      _stopVoiceMode();
      
    } catch (e) {
      setState(() {
        _voiceStatus = 'Error: ${e.toString()}';
      });
      
      await Future.delayed(Duration(seconds: 2));
      _stopVoiceMode();
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