import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/message.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isLastMessage;

  const MessageBubble({
    super.key,
    required this.message,
    this.isLastMessage = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isError = widget.message.isError;
    final isToolCall = widget.message.isToolCall;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getBackgroundColor(context, isUser, isError, isToolCall),
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: !isUser ? const Radius.circular(4) : null,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message type indicator
                if (isError || isToolCall)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isError ? Icons.error_outline : Icons.build,
                        size: 16,
                        color: isError ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isError ? 'Error' : 'Tool Call',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isError ? Colors.red : Colors.orange,
                        ),
                      ),
                    ],
                  ),

                // Images
                if (widget.message.images != null &&
                    widget.message.images!.isNotEmpty)
                  ...widget.message.images!.map(
                    (imageUrl) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Message content
                if (widget.message.content.isNotEmpty)
                  SelectableText(
                    widget.message.content,
                    style: TextStyle(
                      color: _getTextColor(context, isUser, isError),
                      fontSize: 16,
                    ),
                  ),

                // Metadata
                if (widget.message.metadata != null &&
                    widget.message.metadata!.containsKey('streaming') &&
                    widget.message.metadata!['streaming'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getTextColor(
                                context,
                                isUser,
                                isError,
                              ).withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Thinking...',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getTextColor(
                              context,
                              isUser,
                              isError,
                            ).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(
    BuildContext context,
    bool isUser,
    bool isError,
    bool isToolCall,
  ) {
    if (isError) {
      return Colors.red.withOpacity(0.1);
    }
    if (isToolCall) {
      return Colors.orange.withOpacity(0.1);
    }
    if (isUser) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).colorScheme.surface;
  }

  Color _getTextColor(BuildContext context, bool isUser, bool isError) {
    if (isError) {
      return Colors.red[700]!;
    }
    if (isUser) {
      return Theme.of(context).colorScheme.onPrimary;
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
