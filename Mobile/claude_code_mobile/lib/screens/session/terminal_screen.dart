import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<TerminalMessage> _messages = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeTerminal();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeTerminal() {
    final provider = context.read<AppProvider>();
    if (provider.selectedProject == null) return;

    setState(() {
      _isConnected = true;
      _messages.add(
        TerminalMessage(
          type: 'system',
          content: 'Terminal initialized for ${provider.selectedProject!.name}',
          timestamp: DateTime.now(),
        ),
      );
      _messages.add(
        TerminalMessage(
          type: 'system',
          content: 'Type commands to execute in your project directory',
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _executeCommand() {
    final command = _inputController.text.trim();
    if (command.isEmpty) return;

    // Add command to display
    setState(() {
      _messages.add(
        TerminalMessage(
          type: 'input',
          content: command,
          timestamp: DateTime.now(),
        ),
      );
    });

    // Execute command (this is a basic terminal simulation)
    _processCommand(command);
    _inputController.clear();

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

  void _processCommand(String command) {
    final provider = context.read<AppProvider>();

    // Basic command processing (this is a simplified terminal)
    setState(() {
      switch (command.toLowerCase()) {
        case 'clear':
          _messages.clear();
          _messages.add(
            TerminalMessage(
              type: 'system',
              content: 'Terminal cleared',
              timestamp: DateTime.now(),
            ),
          );
          break;
        case 'help':
          _messages.add(
            TerminalMessage(
              type: 'output',
              content: '''Available commands:
- help: Show this help message
- clear: Clear terminal
- pwd: Show current directory
- ls: List files (basic simulation)
- echo [text]: Echo text
- exit: Close terminal

For advanced shell operations, use the Shell tab.''',
              timestamp: DateTime.now(),
            ),
          );
          break;
        case 'pwd':
          _messages.add(
            TerminalMessage(
              type: 'output',
              content: provider.selectedProject?.fullPath ?? '/unknown',
              timestamp: DateTime.now(),
            ),
          );
          break;
        case 'ls':
          _messages.add(
            TerminalMessage(
              type: 'output',
              content: 'src/\nlib/\ntest/\nREADME.md\npackage.json\n.gitignore',
              timestamp: DateTime.now(),
            ),
          );
          break;
        case 'exit':
          setState(() {
            _isConnected = false;
            _messages.add(
              TerminalMessage(
                type: 'system',
                content: 'Terminal session ended',
                timestamp: DateTime.now(),
              ),
            );
          });
          break;
        default:
          if (command.startsWith('echo ')) {
            final text = command.substring(5);
            _messages.add(
              TerminalMessage(
                type: 'output',
                content: text,
                timestamp: DateTime.now(),
              ),
            );
          } else {
            _messages.add(
              TerminalMessage(
                type: 'error',
                content:
                    'Command not found: $command\nType "help" for available commands.',
                timestamp: DateTime.now(),
              ),
            );
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.selectedProject == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.computer, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Select a project to use the terminal'),
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
                  const Icon(Icons.computer),
                  const SizedBox(width: 8),
                  Text(
                    'Terminal: ${provider.selectedProject!.name}',
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
                      _isConnected ? 'Active' : 'Inactive',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => _processCommand('help'),
                    tooltip: 'Show help',
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: () => _processCommand('clear'),
                    tooltip: 'Clear terminal',
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
                          'Terminal ready. Type a command below.',
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
                  Text(
                    '${provider.selectedProject?.name ?? "terminal"}\$ ',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: _isConnected,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'Enter command...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _executeCommand(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isConnected ? _executeCommand : null,
                    child: const Text('Run'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessage(TerminalMessage message) {
    Color textColor;
    String prefix;

    switch (message.type) {
      case 'input':
        textColor = Colors.cyan;
        prefix = '> ';
        break;
      case 'output':
        textColor = Colors.white;
        prefix = '';
        break;
      case 'error':
        textColor = Colors.red;
        prefix = '✗ ';
        break;
      case 'system':
        textColor = Colors.green;
        prefix = '■ ';
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

class TerminalMessage {
  final String type; // 'input', 'output', 'error', 'system'
  final String content;
  final DateTime timestamp;

  TerminalMessage({
    required this.type,
    required this.content,
    required this.timestamp,
  });
}
