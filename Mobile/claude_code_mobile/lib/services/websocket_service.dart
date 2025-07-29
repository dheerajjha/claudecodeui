import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WebSocketType { chat, shell }

class WebSocketService {
  static const String _defaultBaseUrl = 'ws://localhost:3008';

  String _baseUrl;
  WebSocketChannel? _chatChannel;
  WebSocketChannel? _shellChannel;

  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _shellOutputController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _chatConnectionController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _shellConnectionController =
      StreamController<bool>.broadcast();

  WebSocketService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl;

  // Update base URL
  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
  }

  String get baseUrl => _baseUrl;

  // Chat WebSocket streams
  Stream<Map<String, dynamic>> get chatMessages =>
      _chatMessageController.stream;
  Stream<bool> get chatConnectionStatus => _chatConnectionController.stream;

  // Shell WebSocket streams
  Stream<Map<String, dynamic>> get shellOutput => _shellOutputController.stream;
  Stream<bool> get shellConnectionStatus => _shellConnectionController.stream;

  // Connection status getters
  bool get isChatConnected => _chatChannel != null;
  bool get isShellConnected => _shellChannel != null;

  // Connect to chat WebSocket
  Future<void> connectChat() async {
    if (_chatChannel != null) {
      await disconnectChat();
    }

    try {
      final wsUrl = _baseUrl.replaceFirst('http', 'ws');
      _chatChannel = IOWebSocketChannel.connect('$wsUrl/ws');

      _chatConnectionController.add(true);

      _chatChannel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data);
            _chatMessageController.add(message);
          } catch (e) {
            print('Error parsing chat message: $e');
          }
        },
        onError: (error) {
          print('Chat WebSocket error: $error');
          _chatConnectionController.add(false);
          _chatChannel = null;
        },
        onDone: () {
          print('Chat WebSocket connection closed');
          _chatConnectionController.add(false);
          _chatChannel = null;
        },
      );
    } catch (e) {
      print('Failed to connect chat WebSocket: $e');
      _chatConnectionController.add(false);
      throw WebSocketException('Failed to connect to chat: $e');
    }
  }

  // Connect to shell WebSocket
  Future<void> connectShell() async {
    if (_shellChannel != null) {
      await disconnectShell();
    }

    try {
      final wsUrl = _baseUrl.replaceFirst('http', 'ws');
      _shellChannel = IOWebSocketChannel.connect('$wsUrl/shell');

      _shellConnectionController.add(true);

      _shellChannel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data);
            _shellOutputController.add(message);
          } catch (e) {
            print('Error parsing shell output: $e');
          }
        },
        onError: (error) {
          print('Shell WebSocket error: $error');
          _shellConnectionController.add(false);
          _shellChannel = null;
        },
        onDone: () {
          print('Shell WebSocket connection closed');
          _shellConnectionController.add(false);
          _shellChannel = null;
        },
      );
    } catch (e) {
      print('Failed to connect shell WebSocket: $e');
      _shellConnectionController.add(false);
      throw WebSocketException('Failed to connect to shell: $e');
    }
  }

  // Send chat message
  void sendChatMessage(Map<String, dynamic> message) {
    if (_chatChannel == null) {
      throw WebSocketException('Chat WebSocket not connected');
    }

    try {
      _chatChannel!.sink.add(jsonEncode(message));
    } catch (e) {
      throw WebSocketException('Failed to send chat message: $e');
    }
  }

  // Send shell command
  void sendShellCommand(Map<String, dynamic> command) {
    if (_shellChannel == null) {
      throw WebSocketException('Shell WebSocket not connected');
    }

    try {
      _shellChannel!.sink.add(jsonEncode(command));
    } catch (e) {
      throw WebSocketException('Failed to send shell command: $e');
    }
  }

  // Send Claude command (chat WebSocket)
  void sendClaudeCommand(
    String command, {
    String? projectPath,
    String? sessionId,
    List<String>? images,
  }) {
    final message = {
      'type': 'claude-command',
      'command': command,
      'options': {
        if (projectPath != null) 'projectPath': projectPath,
        if (sessionId != null) 'sessionId': sessionId,
        if (images != null && images.isNotEmpty) 'images': images,
      },
    };

    sendChatMessage(message);
  }

  // Abort session
  void abortSession(String sessionId) {
    final message = {'type': 'abort-session', 'sessionId': sessionId};

    sendChatMessage(message);
  }

  // Initialize shell session
  void initializeShell({
    String? projectPath,
    String? sessionId,
    bool hasSession = false,
  }) {
    final message = {
      'type': 'init',
      if (projectPath != null) 'projectPath': projectPath,
      if (sessionId != null) 'sessionId': sessionId,
      'hasSession': hasSession,
    };

    sendShellCommand(message);
  }

  // Send shell input
  void sendShellInput(String input) {
    final message = {'type': 'input', 'data': input};

    sendShellCommand(message);
  }

  // Resize shell terminal
  void resizeShell(int cols, int rows) {
    final message = {'type': 'resize', 'cols': cols, 'rows': rows};

    sendShellCommand(message);
  }

  // Disconnect chat WebSocket
  Future<void> disconnectChat() async {
    if (_chatChannel != null) {
      await _chatChannel!.sink.close();
      _chatChannel = null;
      _chatConnectionController.add(false);
    }
  }

  // Disconnect shell WebSocket
  Future<void> disconnectShell() async {
    if (_shellChannel != null) {
      await _shellChannel!.sink.close();
      _shellChannel = null;
      _shellConnectionController.add(false);
    }
  }

  // Disconnect all WebSockets
  Future<void> disconnectAll() async {
    await Future.wait([disconnectChat(), disconnectShell()]);
  }

  // Dispose resources
  void dispose() {
    disconnectAll();
    _chatMessageController.close();
    _shellOutputController.close();
    _chatConnectionController.close();
    _shellConnectionController.close();
  }
}

// Custom exception for WebSocket errors
class WebSocketException implements Exception {
  final String message;

  WebSocketException(this.message);

  @override
  String toString() => 'WebSocketException: $message';
}
