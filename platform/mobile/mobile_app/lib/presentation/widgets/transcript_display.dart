import 'package:flutter/material.dart';
import '../../data/models/chat_models.dart';

/// Widget for displaying conversation transcripts with persona labels
class TranscriptDisplay extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool showConfidence;
  final bool enableCollapse;
  final EdgeInsets? padding;

  const TranscriptDisplay({
    super.key,
    required this.messages,
    this.showConfidence = false,
    this.enableCollapse = true,
    this.padding,
  });

  @override
  State<TranscriptDisplay> createState() => _TranscriptDisplayState();
}

class _TranscriptDisplayState extends State<TranscriptDisplay> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final effectivePadding = widget.padding ?? const EdgeInsets.all(16);

    return Container(
      padding: effectivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with collapse button
          if (widget.enableCollapse)
            Row(
              children: [
                Text(
                  'Conversation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isCollapsed = !_isCollapsed;
                    });
                  },
                  icon: Icon(
                    _isCollapsed ? Icons.expand_more : Icons.expand_less,
                  ),
                  tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                ),
              ],
            ),

          // Messages list
          if (!_isCollapsed) ...[
            const SizedBox(height: 8),
            ...widget.messages.map((message) => _buildMessageTile(message, theme)),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageTile(ChatMessage message, ThemeData theme) {
    final isUser = message.type == ChatMessageType.voice || 
                   (message.personaId == null && message.type == ChatMessageType.text);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar/Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getMessageColor(message.type, theme).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getMessageIcon(message.type, isUser),
              size: 16,
              color: _getMessageColor(message.type, theme),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with persona name and timestamp
                Row(
                  children: [
                    Text(
                      _getMessageLabel(message, isUser),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _getMessageColor(message.type, theme),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.showConfidence && message.confidenceLevel != null) ...[
                      const SizedBox(width: 8),
                      _buildConfidenceBadge(message.confidenceLevel!, theme),
                    ],
                    const Spacer(),
                    Text(
                      _formatTimestamp(message.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Message content
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(message.type, isUser, theme),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getMessageColor(message.type, theme).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _getTextColor(message.type, isUser, theme),
                    ),
                  ),
                ),
                
                // Error indicator
                if (message.type == ChatMessageType.error) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 14,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Message failed to send',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence, ThemeData theme) {
    final percentage = (confidence * 100).round();
    final color = confidence >= 0.8 
        ? theme.colorScheme.primary
        : confidence >= 0.6 
            ? theme.colorScheme.tertiary
            : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        '$percentage%',
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getMessageLabel(ChatMessage message, bool isUser) {
    if (isUser) {
      return 'You';
    }
    
    if (message.type == ChatMessageType.system) {
      return 'System';
    }
    
    if (message.personaName != null && message.personaName!.isNotEmpty) {
      return message.personaName!;
    }
    
    return 'AI';
  }

  Color _getMessageColor(ChatMessageType type, ThemeData theme) {
    switch (type) {
      case ChatMessageType.voice:
        return theme.colorScheme.secondary;
      case ChatMessageType.text:
        return theme.colorScheme.primary;
      case ChatMessageType.system:
        return theme.colorScheme.outline;
      case ChatMessageType.error:
        return theme.colorScheme.error;
    }
  }

  Color _getBackgroundColor(ChatMessageType type, bool isUser, ThemeData theme) {
    if (type == ChatMessageType.error) {
      return theme.colorScheme.error.withValues(alpha: 0.05);
    }
    
    if (isUser) {
      return theme.colorScheme.primary.withValues(alpha: 0.05);
    }
    
    return theme.colorScheme.surfaceContainerHighest;
  }

  Color _getTextColor(ChatMessageType type, bool isUser, ThemeData theme) {
    if (type == ChatMessageType.error) {
      return theme.colorScheme.error;
    }
    
    return theme.colorScheme.onSurface;
  }

  IconData _getMessageIcon(ChatMessageType type, bool isUser) {
    switch (type) {
      case ChatMessageType.voice:
        return isUser ? Icons.mic : Icons.volume_up;
      case ChatMessageType.text:
        return isUser ? Icons.person : Icons.smart_toy;
      case ChatMessageType.system:
        return Icons.info_outline;
      case ChatMessageType.error:
        return Icons.error_outline;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

/// Simple message bubble for individual messages
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final bool showTimestamp;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.showTimestamp = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isUser 
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser 
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (showTimestamp) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(message.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isUser 
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}