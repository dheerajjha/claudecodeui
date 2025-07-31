import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class ServerConnectionDialog extends StatefulWidget {
  const ServerConnectionDialog({super.key});

  @override
  State<ServerConnectionDialog> createState() => _ServerConnectionDialogState();
}

class _ServerConnectionDialogState extends State<ServerConnectionDialog> {
  late TextEditingController _urlController;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _urlController = TextEditingController(text: provider.serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server Connection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure your Claude Code server connection',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://claude.grabr.cc',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            enabled: !_isConnecting,
          ),
          const SizedBox(height: 16),
          Consumer<AppProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  Icon(
                    provider.isChatConnected ? Icons.check_circle : Icons.error,
                    color: provider.isChatConnected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.isChatConnected
                          ? 'Connected to server'
                          : 'Not connected',
                      style: TextStyle(
                        color: provider.isChatConnected
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isConnecting ? null : _testConnection,
          child: const Text('Test'),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _saveAndConnect,
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter a server URL');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      final provider = context.read<AppProvider>();

      // Test the connection by trying to fetch projects
      final tempClient = provider.apiClient;
      tempClient.updateBaseUrl(url);
      await tempClient.getConfig();

      _showSuccess('Connection successful!');
    } catch (e) {
      _showError('Failed to connect: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _saveAndConnect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter a server URL');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      final provider = context.read<AppProvider>();

      // Update server URL
      await provider.updateServerUrl(url);

      // Connect to chat
      await provider.connectChat();

      // Load projects
      await provider.loadProjects();

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected to server successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to connect: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
