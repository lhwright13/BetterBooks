import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/persona.dart';

class UserSettingsScreen extends StatefulWidget {
  @override
  _UserSettingsScreenState createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
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
        title: Text('User Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Persona Section
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.smart_toy,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'AI Persona',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Choose your AI companion for book discussions',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        if (appState.isLoading)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (appState.error != null)
                          Column(
                            children: [
                              Text(
                                'Could not load personas',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => appState.loadPersonas(),
                                child: Text('Retry'),
                              ),
                            ],
                          )
                        else if (appState.personas.isEmpty)
                          Center(
                            child: Text(
                              'No personas available',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        else
                          ...appState.personas.map((persona) => PersonaTile(
                            persona: persona,
                            isSelected: appState.selectedPersona?.name == persona.name,
                            onTap: () => appState.selectPersona(persona),
                          )).toList(),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Audio Settings Section
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.volume_up,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Audio Settings',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        ListTile(
                          title: Text('Default Playback Speed'),
                          subtitle: Text('1.0x'),
                          leading: Icon(Icons.speed),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Playback speed settings coming soon!')),
                            );
                          },
                        ),
                        
                        ListTile(
                          title: Text('Auto-play Next Chapter'),
                          leading: Icon(Icons.skip_next),
                          trailing: Switch(
                            value: true,
                            onChanged: (value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Auto-play setting coming soon!')),
                              );
                            },
                          ),
                        ),
                        
                        ListTile(
                          title: Text('Sleep Timer'),
                          subtitle: Text('Off'),
                          leading: Icon(Icons.bedtime),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Sleep timer coming soon!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Voice Settings Section
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.mic,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Voice Settings',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        ListTile(
                          title: Text('Voice Input Language'),
                          subtitle: Text('English (US)'),
                          leading: Icon(Icons.language),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Language settings coming soon!')),
                            );
                          },
                        ),
                        
                        ListTile(
                          title: Text('Voice Response'),
                          leading: Icon(Icons.record_voice_over),
                          trailing: Switch(
                            value: true,
                            onChanged: (value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Voice response toggle coming soon!')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // App Info Section
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'About',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        ListTile(
                          title: Text('Version'),
                          subtitle: Text('1.0.0'),
                          leading: Icon(Icons.info),
                        ),
                        
                        ListTile(
                          title: Text('EchoWright'),
                          subtitle: Text('AI-powered audiobook experience'),
                          leading: Icon(Icons.book),
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
}

class PersonaTile extends StatelessWidget {
  final Persona persona;
  final bool isSelected;
  final VoidCallback onTap;

  const PersonaTile({
    Key? key,
    required this.persona,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primary.withOpacity(0.3),
          child: Icon(
            Icons.person,
            color: isSelected 
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          persona.displayName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
        subtitle: Text(
          persona.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : Icon(Icons.radio_button_unchecked),
        onTap: onTap,
      ),
    );
  }
}