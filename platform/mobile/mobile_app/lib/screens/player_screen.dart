import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/retro_theme.dart';

class PlayerScreen extends StatelessWidget {
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
                child: Container(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Book cover placeholder
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.book,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 32),
                      
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      
                      if (book.author != null) ...[
                        SizedBox(height: 8),
                        Text(
                          book.author!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Audio controls
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
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: ArchitecturalColors.primaryOrange,
                              inactiveTrackColor: ArchitecturalColors.lightGray,
                              thumbColor: ArchitecturalColors.primaryOrange,
                              overlayColor: ArchitecturalColors.primaryOrange.withValues(alpha: 0.2),
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: appState.totalDuration.inSeconds > 0
                                  ? appState.currentPosition.inSeconds.toDouble()
                                  : 0.0,
                              max: appState.totalDuration.inSeconds > 0 
                                  ? appState.totalDuration.inSeconds.toDouble()
                                  : 1.0,
                              onChanged: (value) {
                                appState.seekTo(Duration(seconds: value.toInt()));
                              },
                              onChangeEnd: (value) {
                                appState.seekTo(Duration(seconds: value.toInt()));
                              },
                            ),
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