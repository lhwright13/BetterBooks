import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../api_config_prod.dart';

class HomeTabScreen extends StatefulWidget {
  @override
  _HomeTabScreenState createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Muuchi'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to Muuchi',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your AI-powered audiobook experience',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Currently Reading Section
                if (appState.currentBook != null) ...[
                  Text(
                    'Continue Reading',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '$apiBaseUrl/books/cover/${Uri.encodeComponent(appState.currentBook!.title)}',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.book,
                                color: Theme.of(context).colorScheme.primary,
                              );
                            },
                          ),
                        ),
                      ),
                      title: Text(appState.currentBook!.title),
                      subtitle: Text(
                        appState.currentChapter?.title ?? 'Single book',
                      ),
                      trailing: Icon(Icons.play_arrow),
                      onTap: () => Navigator.pushNamed(context, '/player'),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
                
                // Quick Stats
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.library_books,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${appState.books.length}',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              Text(
                                'Books',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.smart_toy,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${appState.personas.length}',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              Text(
                                'AI Personas',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Quick Actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 12),
                
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.library_books),
                        title: Text('Browse Library'),
                        subtitle: Text('Explore your audiobook collection'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          // This will be handled by the parent widget
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Switching to Library tab...')),
                          );
                        },
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.store),
                        title: Text('Visit Bookstore'),
                        subtitle: Text('Discover new audiobooks'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Switching to Bookstore tab...')),
                          );
                        },
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Settings'),
                        subtitle: Text('Manage your preferences'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Switching to Profile tab...')),
                          );
                        },
                      ),
                    ],
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