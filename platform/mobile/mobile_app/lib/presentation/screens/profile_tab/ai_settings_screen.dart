import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/book_models.dart';
import '../../../services/voice_service.dart';
import '../../widgets/common/loading_widget.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  List<AIPersona> _personas = [];
  bool _isLoading = true;
  String? _selectedPersonaId;

  @override
  void initState() {
    super.initState();
    _loadPersonas();
  }

  Future<void> _loadPersonas() async {
    setState(() => _isLoading = true);
    
    try {
      // Load available personas from the voice service
      final voiceService = VoiceService();
      await voiceService.initialize();
      
      // Get global personas (not book-specific)
      _personas = [
        AIPersona(
          id: 'english_teacher',
          name: 'English Teacher',
          description: 'A knowledgeable English teacher who can help analyze literature, explain themes, and discuss writing techniques.',
          bio: 'With years of experience in literature education, I specialize in helping readers understand complex themes, character development, and literary devices. I can provide insights into historical context, author backgrounds, and help you appreciate the deeper meanings in great works of literature.',
          expertise: ['Literary Analysis', 'Writing Techniques', 'Historical Context', 'Character Development'],
          voiceConfig: {'voice': 'teacher', 'speed': 1.0, 'tone': 'educational'},
        ),
        AIPersona(
          id: 'language_tutor',
          name: 'Language Tutor',
          description: 'A friendly language tutor who helps with vocabulary, pronunciation, and language learning.',
          bio: 'I\'m passionate about helping people expand their vocabulary and improve their language skills. Whether you encounter unfamiliar words while reading or want to practice pronunciation, I\'m here to make language learning engaging and accessible.',
          expertise: ['Vocabulary Building', 'Pronunciation', 'Grammar', 'Language Practice'],
          voiceConfig: {'voice': 'tutor', 'speed': 0.9, 'tone': 'encouraging'},
        ),
        AIPersona(
          id: 'storyteller',
          name: 'Master Storyteller',
          description: 'An engaging storyteller who brings narratives to life with dramatic flair and deep understanding.',
          bio: 'I live and breathe stories. With a deep appreciation for narrative structure, character development, and the art of storytelling, I can help you understand what makes a story compelling and discuss the craft behind great literature.',
          expertise: ['Narrative Structure', 'Character Analysis', 'Plot Development', 'Story Craft'],
          voiceConfig: {'voice': 'storyteller', 'speed': 1.1, 'tone': 'dramatic'},
        ),
        AIPersona(
          id: 'book_club_leader',
          name: 'Book Club Leader',
          description: 'A discussion facilitator who loves exploring different perspectives and insights about books.',
          bio: 'I thrive on book discussions and love exploring different interpretations and perspectives. I can help facilitate thoughtful conversations about what you\'re reading, ask thought-provoking questions, and share insights from other readers.',
          expertise: ['Discussion Facilitation', 'Multiple Perspectives', 'Critical Thinking', 'Reading Groups'],
          voiceConfig: {'voice': 'facilitator', 'speed': 1.0, 'tone': 'conversational'},
        ),
      ];
      
      _selectedPersonaId = _personas.first.id;
    } catch (e) {
      // Handle error loading personas
      print('Error loading personas: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: Text(
          'AI Personas',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: LoadingWidget())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.psychology,
                            color: theme.colorScheme.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Choose Your AI Companion',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select an AI persona to enhance your reading experience. Each persona has unique expertise and personality to help you explore books in different ways.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Personas list
                Text(
                  'Available Personas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                
                ..._personas.map((persona) => _buildPersonaCard(persona, theme)),
                
                const SizedBox(height: 32),
                
                // Settings section
                _buildSettingsSection(theme),
              ],
            ),
          ),
    );
  }

  Widget _buildPersonaCard(AIPersona persona, ThemeData theme) {
    final isSelected = _selectedPersonaId == persona.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSelected 
          ? theme.colorScheme.primaryContainer 
          : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: isSelected 
          ? Border.all(color: theme.colorScheme.primary, width: 2)
          : null,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPersonaId = persona.id;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with selection indicator
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getPersonaIcon(persona.id),
                      color: isSelected 
                        ? theme.colorScheme.onPrimary 
                        : theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          persona.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected 
                              ? theme.colorScheme.onPrimaryContainer 
                              : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          persona.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected 
                              ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Bio
              Text(
                'About this persona:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected 
                    ? theme.colorScheme.onPrimaryContainer 
                    : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                persona.bio,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected 
                    ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Expertise tags
              Text(
                'Expertise:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected 
                    ? theme.colorScheme.onPrimaryContainer 
                    : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: persona.expertise.map((skill) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    skill,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected 
                        ? theme.colorScheme.onPrimaryContainer 
                        : theme.colorScheme.primary,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Voice chat toggle
              Row(
                children: [
                  Icon(
                    Icons.mic,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Voice Chat',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Talk to your AI persona using voice',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: true, // TODO: Connect to actual setting
                    onChanged: (value) {
                      // TODO: Implement voice chat toggle
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Text chat toggle
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Text Chat',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Type messages to your AI persona',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: true, // TODO: Connect to actual setting
                    onChanged: (value) {
                      // TODO: Implement text chat toggle
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // TODO: Save persona selection
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Save Settings',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getPersonaIcon(String personaId) {
    switch (personaId) {
      case 'english_teacher':
        return Icons.school;
      case 'language_tutor':
        return Icons.translate;
      case 'storyteller':
        return Icons.auto_stories;
      case 'book_club_leader':
        return Icons.groups;
      default:
        return Icons.psychology;
    }
  }
}

// Model class for AI Persona
class AIPersona {
  final String id;
  final String name;
  final String description;
  final String bio;
  final List<String> expertise;
  final Map<String, dynamic> voiceConfig;

  AIPersona({
    required this.id,
    required this.name,
    required this.description,
    required this.bio,
    required this.expertise,
    required this.voiceConfig,
  });
}