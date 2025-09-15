import 'package:flutter/material.dart';
import '../../../data/models/chat_models.dart';

class BookPersonasSection extends StatelessWidget {
  final List<dynamic> personas;
  final Function(dynamic) onPersonaTap;

  const BookPersonasSection({
    super.key,
    required this.personas,
    required this.onPersonaTap,
  });

  @override
  Widget build(BuildContext context) {
    if (personas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No AI Personas Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'AI personas will be added for enhanced book discussions',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: personas.length,
      itemBuilder: (context, index) {
        final persona = personas[index];
        return PersonaCard(
          persona: persona,
          onTap: () => onPersonaTap(persona),
        );
      },
    );
  }
}

class PersonaCard extends StatelessWidget {
  final dynamic persona;
  final VoidCallback onTap;

  const PersonaCard({
    super.key,
    required this.persona,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Persona avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      _getPersonaInitials(persona['display_name'] ?? persona['name'] ?? 'AI'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Persona info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          persona['display_name'] ?? persona['name'] ?? 'AI Persona',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (persona['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            persona['description'],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Chat icon
                  Icon(
                    Icons.chat_bubble_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              
              // Persona type badge
              if (persona['is_global'] == true || persona['is_global'] == false) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: persona['is_global'] == true
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    persona['is_global'] == true ? 'Global Helper' : 'Book Character',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: persona['is_global'] == true
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getPersonaInitials(String name) {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0].length >= 2 
        ? words[0].substring(0, 2).toUpperCase()
        : words[0][0].toUpperCase();
    }
    return 'AI';
  }
}