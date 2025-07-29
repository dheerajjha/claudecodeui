import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ShellMessage> _messages = [];
  bool _isConnected = false;
  int _lastShellMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _connectShell();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _connectShell() async {
    final provider = context.read<AppProvider>();
    if (provider.selectedProject == null) return;

    try {
      await provider.connectShell();
      setState(() {
        _isConnected = true;
        _messages.add(
          ShellMessage(
            type: 'system',
            content: 'Connected to shell for ${provider.selectedProject!.name}',
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ShellMessage(
            type: 'error',
            content: 'Failed to connect to shell: $e',
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  void _sendCommand() {
    final command = _inputController.text.trim();
    if (command.isEmpty) return;

    final provider = context.read<AppProvider>();

    // Add command to display
    setState(() {
      _messages.add(
        ShellMessage(
          type: 'input',
          content: command,
          timestamp: DateTime.now(),
        ),
      );
    });

    // Send command
    try {
      provider.sendShellInput(command);
      _inputController.clear();
    } catch (e) {
      setState(() {
        _messages.add(
          ShellMessage(
            type: 'error',
            content: 'Failed to send command: $e',
            timestamp: DateTime.now(),
          ),
        );
      });
    }

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _cleanAnsiCodes(String text) {
    // Remove ANSI escape sequences (colors, cursor movements, etc.)
    return text
        .replaceAll(RegExp(r'\x1B\[[0-9;]*[mGKHfJ]'), '') // Most common ANSI codes
        .replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '') // Other ANSI codes
        .replaceAll(RegExp(r'\x1B\]0;.*?\x07'), '') // Terminal title sequences
        .replaceAll(RegExp(r'\r\n|\r|\n'), '\n') // Normalize line endings
        .trim();
  }

  void _checkForNewShellMessages(AppProvider provider) {
    if (provider.shellMessages.length > _lastShellMessageCount) {
      // Add new shell messages
      for (int i = _lastShellMessageCount; i < provider.shellMessages.length; i++) {
        final shellMsg = provider.shellMessages[i];
        final rawContent = shellMsg['data']?.toString() ?? shellMsg.toString();
        final cleanContent = _cleanAnsiCodes(rawContent);
        
        if (cleanContent.trim().isNotEmpty) {
          // Check if this should be appended to the last message or create a new one
          if (_messages.isNotEmpty && 
              _messages.last.type == 'output' && 
              DateTime.now().difference(_messages.last.timestamp).inMilliseconds < 500) {
            // Append to last message if it's recent output
            final lastMessage = _messages.removeLast();
            _messages.add(ShellMessage(
              type: 'output',
              content: '${lastMessage.content}$cleanContent',
              timestamp: lastMessage.timestamp,
            ));
          } else {
            // Create new message
            _messages.add(ShellMessage(
              type: 'output',
              content: cleanContent,
              timestamp: DateTime.now(),
            ));
          }
        }
      }
      _lastShellMessageCount = provider.shellMessages.length;
      
      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        // Check for new shell messages from the provider
        _checkForNewShellMessages(provider);
        
        if (provider.selectedProject == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.terminal, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Select a project to use the shell'),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header with connection status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal),
                  const SizedBox(width: 8),
                  Text(
                    'Shell: ${provider.selectedProject!.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Terminal output
            Expanded(
              child: Container(
                color: Colors.black,
                child: _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Type a command below to get started',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'monospace',
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessage(message);
                        },
                      ),
              ),
            ),

            // Command input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '\$ ',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: _isConnected,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'Enter shell command...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendCommand(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isConnected ? _sendCommand : null,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessage(ShellMessage message) {
    Color textColor;
    String prefix;

    switch (message.type) {
      case 'input':
        textColor = Colors.green;
        prefix = '\$ ';
        break;
      case 'output':
        textColor = Colors.white;
        prefix = '';
        break;
      case 'error':
        textColor = Colors.red;
        prefix = '! ';
        break;
      case 'system':
        textColor = Colors.yellow;
        prefix = '# ';
        break;
      default:
        textColor = Colors.grey;
        prefix = '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SelectableText.rich(
        TextSpan(
          children: [
            if (prefix.isNotEmpty)
              TextSpan(
                text: prefix,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            TextSpan(
              text: message.content,
              style: TextStyle(color: textColor, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}

class ShellMessage {
  final String type; // 'input', 'output', 'error', 'system'
  final String content;
  final DateTime timestamp;

  ShellMessage({
    required this.type,
    required this.content,
    required this.timestamp,
  });
}
