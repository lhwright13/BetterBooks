import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/ripple_animation.dart';
import '../widgets/audio_visualizer.dart';
import '../api_config_prod.dart';

class VoiceModeScreen extends StatefulWidget {
  @override
  _VoiceModeScreenState createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen>
    with TickerProviderStateMixin {
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isAISpeaking = false;
  double _audioLevel = 0.0;
  String _currentText = '';
  
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _startVoiceInteraction() async {
    final appState = context.read<AppState>();
    
    if (appState.selectedPersona == null) {
      _showError('Please select an AI persona first');
      return;
    }

    // Start listening phase
    setState(() {
      _isListening = true;
      _currentText = 'Listening... Speak your question about the book';
    });
    _scaleController.forward();

    // Simulate voice input collection (3 seconds)
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    // Processing phase
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _currentText = 'Processing your question...';
    });

    try {
      // Simulate getting voice text (in real app, this would be speech-to-text)
      final voiceQuestions = [
        "What are the main themes in this chapter?",
        "Tell me about the symbolism of the green light",
        "What is Gatsby's relationship with Daisy?",
        "Explain the significance of the Valley of Ashes",
        "What does the eyes of Doctor T.J. Eckleburg represent?",
      ];
      
      final questionIndex = DateTime.now().millisecondsSinceEpoch % voiceQuestions.length;
      final voiceText = voiceQuestions[questionIndex];
      
      // Process the voice query
      final response = await appState.processVoiceQuery(voiceText);
      
      if (!mounted) return;

      // AI speaking phase
      setState(() {
        _isProcessing = false;
        _isAISpeaking = true;
        _currentText = 'AI is responding...';
      });

      // Simulate AI speech duration based on response length
      final speechDuration = Duration(milliseconds: (response.length * 50).clamp(2000, 8000));
      await Future.delayed(speechDuration);
      
      if (!mounted) return;

      // Complete
      setState(() {
        _isAISpeaking = false;
        _currentText = 'Voice interaction complete. Check chat for details.';
      });
      _scaleController.reverse();
      
      // Auto-dismiss after showing completion
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
        _isAISpeaking = false;
        _currentText = 'Error: ${e.toString()}';
      });
      _scaleController.reverse();
      
      // Auto-dismiss on error
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _cancelVoiceInteraction() {
    setState(() {
      _isListening = false;
      _isProcessing = false;
      _isAISpeaking = false;
    });
    _scaleController.reverse();
    Navigator.pop(context);
  }

  AudioVisualizationMode get _currentMode {
    if (_isListening) return AudioVisualizationMode.listening;
    if (_isProcessing) return AudioVisualizationMode.processing;
    if (_isAISpeaking) return AudioVisualizationMode.speaking;
    return AudioVisualizationMode.listening;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final book = appState.currentBook;
          
          return Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      Colors.indigo.withOpacity(0.3),
                      Colors.black,
                    ],
                  ),
                ),
              ),
              
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Book cover with ripple effects
                    AnimatedBuilder(
                      animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary
                                      .withOpacity(_glowAnimation.value * 0.5),
                                  blurRadius: 30 + (_glowAnimation.value * 20),
                                  spreadRadius: 5 + (_glowAnimation.value * 10),
                                ),
                              ],
                            ),
                            child: RippleAnimation(
                              isAnimating: _isListening || _isAISpeaking,
                              intensity: _audioLevel * 2,
                              rippleColor: _isListening 
                                  ? Colors.blue 
                                  : Colors.green,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: book != null
                                    ? Image.network(
                                        '$apiBaseUrl/books/cover/${Uri.encodeComponent(book.title)}',
                                        width: 300,
                                        height: 300,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 300,
                                            height: 300,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Icon(
                                              Icons.book,
                                              size: 120,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        width: 300,
                                        height: 300,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Icon(
                                          Icons.book,
                                          size: 120,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Status text
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _currentText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Audio visualizer
                    if (_isListening || _isProcessing || _isAISpeaking)
                      AudioVisualizer(
                        isActive: true,
                        mode: _currentMode,
                        color: _isListening 
                            ? Colors.blue 
                            : _isProcessing
                                ? Colors.orange
                                : Colors.green,
                        onAudioLevel: (level) {
                          setState(() {
                            _audioLevel = level;
                          });
                        },
                      ),
                    
                    const SizedBox(height: 40),
                    
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Cancel button
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: IconButton(
                            onPressed: _cancelVoiceInteraction,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                        ),
                        
                        // Main action button
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isListening 
                                ? Colors.red.withOpacity(0.2)
                                : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: _isListening 
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                          child: IconButton(
                            onPressed: (_isProcessing || _isAISpeaking) 
                                ? null 
                                : _startVoiceInteraction,
                            icon: Icon(
                              _isListening 
                                  ? Icons.mic
                                  : _isProcessing
                                      ? Icons.psychology
                                      : _isAISpeaking
                                          ? Icons.volume_up
                                          : Icons.mic_none,
                              color: _isListening 
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                              size: 40,
                            ),
                          ),
                        ),
                        
                        // Settings button (persona selection)
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: IconButton(
                            onPressed: () {
                              // Show persona selection
                              _showPersonaSelection(appState);
                            },
                            icon: const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Current persona indicator
                    if (appState.selectedPersona != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'AI Persona: ${appState.selectedPersona!.displayName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPersonaSelection(AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select AI Persona',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...appState.personas.map((persona) => ListTile(
              leading: Icon(
                appState.selectedPersona?.name == persona.name
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                persona.displayName,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                persona.description,
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () {
                appState.selectPersona(persona);
                Navigator.pop(context);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }
}