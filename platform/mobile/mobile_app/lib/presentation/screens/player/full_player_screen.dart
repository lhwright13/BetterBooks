import 'package:flutter/material.dart';
import '../../../data/models/book_models.dart';
import '../../../data/models/chat_models.dart';
import '../../widgets/enhanced_book_cover.dart';
import '../../widgets/chapter_selector_sheet.dart';
import '../text_chat_screen.dart';
import '../../controllers/purchase_controller.dart';
import 'package:provider/provider.dart';

class FullPlayerScreen extends StatefulWidget {
  final BrowseBook book;
  
  const FullPlayerScreen({
    super.key,
    required this.book,
  });

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  bool _isPlaying = false;
  double _progress = 0.67;
  double _playbackSpeed = 1.0;
  int _currentChapterIndex = 0;
  bool _isPreviewMode = false;
  
  // Persona state
  List<BookPersona> _availablePersonas = [];
  BookPersona? _currentPersona;
  
  @override
  void initState() {
    super.initState();
    _initializePersonas();
    _checkPreviewMode();
  }
  
  void _checkPreviewMode() {
    // Enable preview mode if book is not purchased
    _isPreviewMode = !widget.book.isPurchased;
    
    // If in preview mode, ensure we start at chapter 0
    if (_isPreviewMode) {
      _currentChapterIndex = 0;
    }
  }
  
  void _initializePersonas() {
    // Mock personas for demo - in real implementation this would come from API
    _availablePersonas = [
      BookPersona(
        id: '1',
        personaId: 'gatsby',
        personaName: 'Jay Gatsby',
        personaDisplayName: 'Jay Gatsby',
        personaDescription: 'The enigmatic millionaire',
        isDefault: true,
        sortOrder: 0,
      ),
      BookPersona(
        id: '2',
        personaId: 'nick',
        personaName: 'Nick Carraway',
        personaDisplayName: 'Nick Carraway',
        personaDescription: 'The observant narrator',
        isDefault: false,
        sortOrder: 1,
      ),
      BookPersona(
        id: '3',
        personaId: 'helper',
        personaName: 'Literary Helper',
        personaDisplayName: 'Literary Helper',
        personaDescription: 'Your AI reading assistant',
        isDefault: false,
        sortOrder: 2,
      ),
    ];
    
    // Set default persona
    _currentPersona = _availablePersonas.firstWhere(
      (p) => p.isDefault,
      orElse: () => _availablePersonas.first,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.book.chapters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: _showChapterSelector,
              tooltip: 'Chapters',
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Enhanced Book cover
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: EnhancedBookCover(
                        coverImageUrl: widget.book.coverImageUrl,
                        bookTitle: widget.book.title,
                        bookAuthor: widget.book.author,
                        width: 280,
                        height: 360,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Book info with chapter indicator
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.book.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'By ${widget.book.author}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      _buildChapterIndicator(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Player controls section
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Progress slider
                Column(
                  children: [
                    Slider(
                      value: _progress,
                      onChanged: (value) {
                        setState(() {
                          _progress = value;
                        });
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '12:34',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '36:52',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Main controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10),
                      onPressed: _rewind10Seconds,
                      iconSize: 32,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: _isPreviewMode ? null : _skipToPrevious,
                      iconSize: 40,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: _togglePlayback,
                        iconSize: 48,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: _isPreviewMode ? null : _skipToNext,
                      iconSize: 40,
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10),
                      onPressed: _forward10Seconds,
                      iconSize: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Speed and options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: _showSpeedMenu,
                      child: Text('${_playbackSpeed}x'),
                    ),
                    TextButton(
                      onPressed: _showPersonaMenu,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 16),
                          SizedBox(width: 4),
                          Text(_currentPersona?.personaDisplayName.split(' ').first ?? 'AI'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.timer),
                      onPressed: _showSleepTimer,
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border),
                      onPressed: _addBookmark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'voice_ai',
        backgroundColor: Theme.of(context).colorScheme.secondary,
        onPressed: _openVoiceAI,
        child: const Icon(Icons.mic),
      ),
    );
  }

  Widget _buildChapterIndicator() {
    if (widget.book.chapters.isEmpty) {
      return Text(
        _isPreviewMode ? 'Preview Mode' : 'Ready to play',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: _isPreviewMode ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
        ),
        textAlign: TextAlign.center,
      );
    }

    final currentChapter = widget.book.chapters.length > _currentChapterIndex
        ? widget.book.chapters[_currentChapterIndex]
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isPreviewMode 
          ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
          : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isPreviewMode 
            ? Theme.of(context).colorScheme.secondary.withOpacity(0.3)
            : Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isPreviewMode) ...[
            Text(
              'PREVIEW MODE',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            _isPreviewMode 
              ? 'Chapter ${_currentChapterIndex + 1} (First Chapter Free)'
              : 'Chapter ${_currentChapterIndex + 1} of ${widget.book.chapters.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isPreviewMode ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (currentChapter != null) ...[
            const SizedBox(height: 4),
            Text(
              currentChapter.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _showChapterSelector() {
    if (widget.book.chapters.isEmpty) return;
    
    // In preview mode, only show first chapter
    if (_isPreviewMode) {
      _showPurchaseDialog();
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ChapterSelectorSheet(
        chapters: widget.book.chapters,
        currentChapterIndex: _currentChapterIndex,
        onChapterSelected: _selectChapter,
        bookTitle: widget.book.title,
      ),
    );
  }

  void _selectChapter(int chapterIndex) {
    // In preview mode, only allow first chapter
    if (_isPreviewMode && chapterIndex > 0) {
      _showPurchaseDialog();
      return;
    }
    
    setState(() {
      _currentChapterIndex = chapterIndex.clamp(0, widget.book.chapters.length - 1);
    });
    // TODO: Implement actual chapter playback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to Chapter ${_currentChapterIndex + 1}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openVoiceAI() {
    // TODO: Navigate to voice AI chat screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Voice AI chat coming soon!'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Learn More',
          onPressed: () {
            // TODO: Show voice AI info dialog
          },
        ),
      ),
    );
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Playback Speed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...['0.5', '0.75', '1.0', '1.25', '1.5', '2.0'].map(
              (speed) => ListTile(
                title: Text('${speed}x'),
                trailing: _playbackSpeed.toString() == speed
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _playbackSpeed = double.parse(speed);
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSleepTimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sleep Timer'),
        content: const Text('Sleep timer functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addBookmark() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark added')),
    );
  }

  void _showPersonaMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose AI Persona',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._availablePersonas.map(
              (persona) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    persona.personaDisplayName[0],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(persona.personaDisplayName),
                subtitle: Text(persona.personaDescription ?? ''),
                trailing: _currentPersona?.id == persona.id
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _currentPersona = persona;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Now chatting with ${persona.personaDisplayName}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Text Chat'),
              subtitle: Text('Chat with ${_currentPersona?.personaDisplayName ?? "AI"}'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TextChatScreen(
                      book: widget.book,
                      initialPersonaId: _currentPersona?.personaId,
                    ),
                  ),
                );
              },
            ),
            if (!_isPreviewMode) ...[
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('Add Note'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Add note functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Share functionality
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Purchase Full Book'),
                subtitle: Text('${widget.book.creditPrice} credit${widget.book.creditPrice == 1 ? '' : 's'}'),
                onTap: () {
                  Navigator.pop(context);
                  _showPurchaseDialog();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _rewind10Seconds() {
    // TODO: Implement actual rewind functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rewound 10 seconds'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _forward10Seconds() {
    // In preview mode, check if we're near the end of first chapter
    if (_isPreviewMode && _progress > 0.9) {
      _showPurchaseDialog();
      return;
    }
    
    // TODO: Implement actual forward functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fast forwarded 10 seconds'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _skipToPrevious() {
    if (_currentChapterIndex > 0) {
      _selectChapter(_currentChapterIndex - 1);
    }
  }

  void _skipToNext() {
    if (_currentChapterIndex < widget.book.chapters.length - 1) {
      _selectChapter(_currentChapterIndex + 1);
    }
  }

  void _showPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You\'re currently in preview mode. To access the full book including all chapters, please purchase it.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.auto_stories, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Full book: ${widget.book.creditPrice} credit${widget.book.creditPrice == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('• Access to all ${widget.book.chapters.length} chapters'),
            Text('• Download for offline listening'),
            Text('• Create bookmarks and notes'),
            Text('• Full AI chat experience'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Preview'),
          ),
          Consumer<PurchaseController>(
            builder: (context, purchaseController, child) {
              return ElevatedButton(
                onPressed: purchaseController.hasEnoughCredits(widget.book.creditPrice)
                    ? () => _purchaseBook(purchaseController)
                    : null,
                child: purchaseController.hasEnoughCredits(widget.book.creditPrice)
                    ? const Text('Purchase Now')
                    : const Text('Insufficient Credits'),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseBook(PurchaseController purchaseController) async {
    Navigator.pop(context); // Close dialog
    
    final success = await purchaseController.purchaseBook(widget.book.id);
    
    if (success) {
      setState(() {
        _isPreviewMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.book.title} purchased successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase failed. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}