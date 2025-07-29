import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../models/persona.dart';
import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.loadPersonas();
      
      // Add welcome message if chat is empty
      if (appState.chatMessages.isEmpty) {
        _addWelcomeMessage(appState);
      }
      _scrollToBottom();
    });
  }

  void _addWelcomeMessage(AppState appState) {
    final book = appState.currentBook;
    
    String welcomeText = "Hello! I'm here to discuss the book with you.";
    if (book != null) {
      welcomeText = "Hi! I'm ready to chat about \"${book.title}\". What would you like to discuss?";
    }
    
    appState.addChatMessage(welcomeText, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<AppState>(
            builder: (context, appState, child) {
              if (appState.personas.isEmpty) return SizedBox();
              
              return PopupMenuButton<Persona>(
                icon: Icon(Icons.person),
                tooltip: 'Select AI Persona',
                onSelected: (persona) => appState.selectPersona(persona),
                itemBuilder: (context) => appState.personas.map((persona) {
                  return PopupMenuItem<Persona>(
                    value: persona,
                    child: Row(
                      children: [
                        Icon(
                          appState.selectedPersona?.name == persona.name
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                persona.displayName,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                persona.description,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Current persona indicator
          Consumer<AppState>(
            builder: (context, appState, child) {
              if (appState.selectedPersona == null) return SizedBox();
              
              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Text(
                  'Chatting with: ${appState.selectedPersona!.displayName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
          
          // Messages list
          Expanded(
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                final messages = appState.chatMessages;
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return ChatBubble(message: messages[index]);
                  },
                );
              },
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Thinking...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          
          // Message input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about the book...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: IconButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    final appState = context.read<AppState>();
    if (appState.selectedPersona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a persona first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      await appState.sendTextMessage(message);
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.smart_toy,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: message.isUser ? null : Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: message.isUser ? Colors.white : null,
                    ),
                  ),
                ),
                if (message.isVoiceMessage) ...[
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mic,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Voice message',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          if (message.isUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                message.isVoiceMessage ? Icons.mic : Icons.person,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}