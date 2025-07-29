import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/chat/message_list.dart';
import '../../widgets/chat/chat_input.dart';
import '../../widgets/chat/session_list_drawer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Connect to chat WebSocket when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      if (!provider.isChatConnected) {
        provider.connectChat();
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
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Select a project to start chatting'),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Connection status indicator
            if (!provider.isChatConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.orange,
                child: const Text(
                  'Connecting to chat server...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),

            // Main chat area
            const Expanded(child: MessageList()),

            // Chat input at bottom
            const ChatInput(),
          ],
        );
      },
    );
  }
}
