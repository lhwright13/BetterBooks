import 'package:flutter/material.dart';
import '../../data/models/book_models.dart';
import '../../data/models/chat_models.dart';

/// Text chat interface similar to ChatGPT/Claude
/// Features:
/// - Message bubbles for user and AI responses
/// - Conversation history sidebar
/// - Persona switching
/// - Auto-scroll to latest messages
/// - Typing indicators
class TextChatScreen extends StatefulWidget {
  final BrowseBook book;
  final String? initialPersonaId;

  const TextChatScreen({
    super.key,
    required this.book,
    this.initialPersonaId,
  });

  @override
  State<TextChatScreen> createState() => _TextChatScreenState();
}

class _TextChatScreenState extends State<TextChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<ChatMessage> _messages = [];
  List<ChatSession> _conversations = [];
  ChatSession? _currentSession;
  BookPersona? _currentPersona;
  List<BookPersona> _availablePersonas = [];
  bool _isLoading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    
    try {
      // Load personas for this book
      await _loadPersonas();
      
      // Create or load conversation session
      await _createNewSession();
      
      // Load conversation history
      await _loadConversationHistory();
      
    } catch (e) {
      _showErrorSnackBar('Failed to initialize chat: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPersonas() async {
    // Mock personas for now - in real implementation this would come from API
    _availablePersonas = [
      BookPersona(
        id: '1',
        personaId: 'gatsby',
        personaName: 'Jay Gatsby',
        personaDisplayName: 'Jay Gatsby',
        personaDescription: 'The enigmatic millionaire with a mysterious past',
        isDefault: true,
        sortOrder: 0,
      ),
      BookPersona(
        id: '2',
        personaId: 'nick',
        personaName: 'Nick Carraway',
        personaDisplayName: 'Nick Carraway',
        personaDescription: 'The observant narrator from West Egg',
        isDefault: false,
        sortOrder: 1,
      ),
      BookPersona(
        id: '3',
        personaId: 'helper',
        personaName: 'Literary Helper',
        personaDisplayName: 'Literary Helper',
        personaDescription: 'Your AI assistant for understanding the book',
        isDefault: false,
        sortOrder: 2,
      ),
    ];

    // Set default persona
    _currentPersona = widget.initialPersonaId != null
        ? _availablePersonas.firstWhere(
            (p) => p.personaId == widget.initialPersonaId,
            orElse: () => _availablePersonas.first,
          )
        : _availablePersonas.firstWhere(
            (p) => p.isDefault,
            orElse: () => _availablePersonas.first,
          );
  }

  Future<void> _createNewSession() async {
    _currentSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: widget.book.id,
      personaId: _currentPersona?.personaId,
      messages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      context: {
        'book_title': widget.book.title,
        'book_author': widget.book.author,
      },
    );

    // Add welcome message
    final welcomeMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: _getWelcomeMessage(),
      type: ChatMessageType.system,
      personaId: _currentPersona?.personaId,
      personaName: _currentPersona?.personaDisplayName,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages = [welcomeMessage];
      _conversations.insert(0, _currentSession!);
    });
  }

  String _getWelcomeMessage() {
    if (_currentPersona?.personaId == 'gatsby') {
      return "Hello, old sport! I'm delighted to chat with you about my story. What would you like to know?";
    } else if (_currentPersona?.personaId == 'nick') {
      return "Greetings! As the narrator of this tale, I can offer you insights into the events I witnessed. What interests you?";
    } else {
      return "Hello! I'm here to help you understand and discuss \"${widget.book.title}\". What questions do you have?";
    }
  }

  Future<void> _loadConversationHistory() async {
    // In a real implementation, this would load from local storage or API
    // For now, we'll keep the current session only
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: messageText,
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Simulate AI response delay
      await Future.delayed(const Duration(milliseconds: 1500));

      // Generate AI response (mock)
      final aiResponse = _generateAIResponse(messageText);
      
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: aiResponse,
        type: ChatMessageType.text,
        personaId: _currentPersona?.personaId,
        personaName: _currentPersona?.personaDisplayName,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isTyping = false;
      });

      _scrollToBottom();

    } catch (e) {
      setState(() => _isTyping = false);
      _showErrorSnackBar('Failed to send message: $e');
    }
  }

  String _generateAIResponse(String userMessage) {
    // Mock AI responses based on persona
    if (_currentPersona?.personaId == 'gatsby') {
      return "My dear friend, that's a fascinating question about my past. You see, I've always believed that the past can be repeated, that we can recapture what we've lost...";
    } else if (_currentPersona?.personaId == 'nick') {
      return "From my perspective as an observer of these events, I can tell you that what you're asking about reveals the complex nature of the American Dream...";
    } else {
      return "That's an excellent question about the themes in \"${widget.book.title}\". Let me help you understand the literary significance of what you're asking...";
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat about ${widget.book.title}',
              style: theme.textTheme.titleMedium,
            ),
            if (_currentPersona != null)
              Text(
                'Talking with ${_currentPersona!.personaDisplayName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
        actions: [
          // Persona selector
          PopupMenuButton<BookPersona>(
            icon: const Icon(Icons.person),
            tooltip: 'Change persona',
            onSelected: _changePersona,
            itemBuilder: (context) => _availablePersonas.map((persona) {
              return PopupMenuItem<BookPersona>(
                value: persona,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      persona.personaDisplayName[0],
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(persona.personaDisplayName),
                  subtitle: Text(persona.personaDescription ?? ''),
                  trailing: _currentPersona?.id == persona.id
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                ),
              );
            }).toList(),
          ),
          
          // Conversation history
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Conversation history',
            onPressed: _showConversationHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
                ),

                // Message input
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);
    final isUser = message.personaId == null;
    final isSystem = message.type == ChatMessageType.system;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                message.personaName?[0] ?? 'AI',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: Icon(
                Icons.person,
                color: theme.colorScheme.onSecondary,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              _currentPersona?.personaDisplayName[0] ?? 'AI',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  AnimatedContainer(
                    duration: Duration(milliseconds: 600 + (i * 200)),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          
          IconButton(
            onPressed: _messageController.text.trim().isEmpty || _isTyping
                ? null
                : _sendMessage,
            icon: Icon(
              Icons.send,
              color: _messageController.text.trim().isEmpty || _isTyping
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  void _changePersona(BookPersona persona) {
    setState(() {
      _currentPersona = persona;
    });
    
    // Add system message about persona change
    final changeMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Now chatting with ${persona.personaDisplayName}',
      type: ChatMessageType.system,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(changeMessage);
    });
    
    _scrollToBottom();
  }

  void _showConversationHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conversation History',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            if (_conversations.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No previous conversations'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final session = _conversations[index];
                    return ListTile(
                      leading: const Icon(Icons.chat),
                      title: Text('Chat ${index + 1}'),
                      subtitle: Text(
                        '${session.messages.length} messages • ${_formatDate(session.updatedAt)}',
                      ),
                      trailing: session.id == _currentSession?.id
                          ? Icon(Icons.circle, color: Theme.of(context).colorScheme.primary, size: 12)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        // In a real implementation, load this conversation
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}