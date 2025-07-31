import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/project.dart';
import '../models/session.dart';
import '../models/message.dart';
import '../models/file_item.dart';

/// Unified API client that handles both HTTP REST API and WebSocket connections
/// for the Claude Code Mobile app. This consolidates all backend communication
/// into a single, easy-to-use service.
class ApiClient {
  static const String _defaultBaseUrl = 'https://claude.grabr.cc';

  String _baseUrl;
  late http.Client _httpClient;

  // WebSocket connections
  WebSocketChannel? _chatChannel;
  WebSocketChannel? _shellChannel;

  // Stream controllers for real-time events
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _shellOutputController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _chatConnectionController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _shellConnectionController =
      StreamController<bool>.broadcast();

  ApiClient({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl {
    _httpClient = http.Client();
  }

  // Getters for streams
  Stream<Map<String, dynamic>> get chatMessages =>
      _chatMessageController.stream;
  Stream<Map<String, dynamic>> get shellOutput => _shellOutputController.stream;
  Stream<bool> get chatConnectionStatus => _chatConnectionController.stream;
  Stream<bool> get shellConnectionStatus => _shellConnectionController.stream;

  // Connection status
  bool get isChatConnected => _chatChannel != null;
  bool get isShellConnected => _shellChannel != null;
  String get baseUrl => _baseUrl;

  /// Update the base URL for both HTTP and WebSocket connections
  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
  }

  // =============================================================================
  // HTTP API METHODS
  // =============================================================================

  /// Generic HTTP request method
  Future<http.Response> _httpRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final finalHeaders = {...defaultHeaders, ...?headers};

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          return await _httpClient.get(url, headers: finalHeaders);
        case 'POST':
          return await _httpClient.post(
            url,
            headers: finalHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
        case 'PUT':
          return await _httpClient.put(
            url,
            headers: finalHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
        case 'DELETE':
          return await _httpClient.delete(url, headers: finalHeaders);
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Parse HTTP response and handle errors
  dynamic _parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw ApiException('Failed to parse response: $e');
      }
    } else {
      throw ApiException(
        'API error: ${response.statusCode} - ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  // Project API methods
  Future<Map<String, dynamic>> getConfig() async {
    final response = await _httpRequest('GET', '/api/config');
    return _parseResponse(response);
  }

  Future<List<Project>> getProjects() async {
    final response = await _httpRequest('GET', '/api/projects');
    final data = _parseResponse(response) as List;
    return data.map((json) => Project.fromJson(json)).toList();
  }

  Future<void> createProject(String path) async {
    await _httpRequest('POST', '/api/projects/create', body: {'path': path});
  }

  Future<void> deleteProject(String projectName) async {
    await _httpRequest('DELETE', '/api/projects/$projectName');
  }

  Future<void> renameProject(String projectName, String displayName) async {
    await _httpRequest(
      'PUT',
      '/api/projects/$projectName/rename',
      body: {'displayName': displayName},
    );
  }

  // Session API methods
  Future<List<Session>> getSessions(
    String projectName, {
    int limit = 5,
    int offset = 0,
  }) async {
    final response = await _httpRequest(
      'GET',
      '/api/projects/$projectName/sessions?limit=$limit&offset=$offset',
    );
    final data = _parseResponse(response) as List;
    return data.map((json) => Session.fromJson(json)).toList();
  }

  Future<List<ChatMessage>> getSessionMessages(
    String projectName,
    String sessionId,
  ) async {
    final response = await _httpRequest(
      'GET',
      '/api/projects/$projectName/sessions/$sessionId/messages',
    );
    final data = _parseResponse(response) as List;
    return data.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<void> deleteSession(String projectName, String sessionId) async {
    await _httpRequest(
      'DELETE',
      '/api/projects/$projectName/sessions/$sessionId',
    );
  }

  // File API methods
  Future<List<FileItem>> getFiles(String projectName) async {
    final response = await _httpRequest(
      'GET',
      '/api/projects/$projectName/files',
    );
    final data = _parseResponse(response) as List;
    return data.map((json) => FileItem.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> readFile(
    String projectName,
    String filePath,
  ) async {
    final encodedPath = Uri.encodeComponent(filePath);
    final response = await _httpRequest(
      'GET',
      '/api/projects/$projectName/file?filePath=$encodedPath',
    );
    return _parseResponse(response);
  }

  Future<void> saveFile(
    String projectName,
    String filePath,
    String content,
  ) async {
    await _httpRequest(
      'PUT',
      '/api/projects/$projectName/file',
      body: {'filePath': filePath, 'content': content},
    );
  }

  // Git API methods
  Future<Map<String, dynamic>> getGitStatus(String projectName) async {
    final encodedProject = Uri.encodeComponent(projectName);
    final response = await _httpRequest(
      'GET',
      '/api/git/status?project=$encodedProject',
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getGitDiff(
    String projectName,
    String filePath,
  ) async {
    final encodedProject = Uri.encodeComponent(projectName);
    final encodedPath = Uri.encodeComponent(filePath);
    final response = await _httpRequest(
      'GET',
      '/api/git/diff?project=$encodedProject&file=$encodedPath',
    );
    return _parseResponse(response);
  }

  Future<void> stageFile(String projectName, String filePath) async {
    await _httpRequest(
      'POST',
      '/api/git/stage',
      body: {'project': projectName, 'file': filePath},
    );
  }

  Future<void> unstageFile(String projectName, String filePath) async {
    await _httpRequest(
      'POST',
      '/api/git/unstage',
      body: {'project': projectName, 'file': filePath},
    );
  }

  Future<void> commitChanges(
    String projectName,
    String message,
    List<String> files,
  ) async {
    await _httpRequest(
      'POST',
      '/api/git/commit',
      body: {'project': projectName, 'message': message, 'files': files},
    );
  }

  Future<List<String>> getBranches(String projectName) async {
    final encodedProject = Uri.encodeComponent(projectName);
    final response = await _httpRequest(
      'GET',
      '/api/git/branches?project=$encodedProject',
    );
    final data = _parseResponse(response);
    return List<String>.from(data['branches'] ?? []);
  }

  Future<void> createBranch(String projectName, String branchName) async {
    await _httpRequest(
      'POST',
      '/api/git/branch',
      body: {'project': projectName, 'branch': branchName},
    );
  }

  Future<void> switchBranch(String projectName, String branchName) async {
    await _httpRequest(
      'POST',
      '/api/git/checkout',
      body: {'project': projectName, 'branch': branchName},
    );
  }

  // Media API methods
  Future<String> transcribeAudio(File audioFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/transcribe'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final data = _parseResponse(response);
    return data['text'] ?? '';
  }

  Future<List<String>> uploadImages(
    String projectName,
    List<File> images,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/projects/$projectName/upload-images'),
    );

    for (final image in images) {
      request.files.add(
        await http.MultipartFile.fromPath('images', image.path),
      );
    }

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final data = _parseResponse(response);
    return List<String>.from(data['images'] ?? []);
  }

  // =============================================================================
  // WEBSOCKET METHODS
  // =============================================================================

  /// Connect to chat WebSocket
  Future<void> connectChat() async {
    if (_chatChannel != null) {
      await disconnectChat();
    }

    try {
      final wsUrl = _baseUrl
          .replaceFirst('https', 'wss')
          .replaceFirst('http', 'ws');
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
      throw ApiException('Failed to connect to chat: $e');
    }
  }

  /// Connect to shell WebSocket
  Future<void> connectShell() async {
    if (_shellChannel != null) {
      await disconnectShell();
    }

    try {
      final wsUrl = _baseUrl
          .replaceFirst('https', 'wss')
          .replaceFirst('http', 'ws');
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
      throw ApiException('Failed to connect to shell: $e');
    }
  }

  /// Send message to chat WebSocket
  void sendChatMessage(Map<String, dynamic> message) {
    if (_chatChannel == null) {
      throw ApiException('Chat WebSocket not connected');
    }
    try {
      _chatChannel!.sink.add(jsonEncode(message));
    } catch (e) {
      throw ApiException('Failed to send chat message: $e');
    }
  }

  /// Send command to shell WebSocket
  void sendShellCommand(Map<String, dynamic> command) {
    if (_shellChannel == null) {
      throw ApiException('Shell WebSocket not connected');
    }
    try {
      _shellChannel!.sink.add(jsonEncode(command));
    } catch (e) {
      throw ApiException('Failed to send shell command: $e');
    }
  }

  /// Send Claude command via chat WebSocket
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

  /// Abort current session
  void abortSession(String sessionId) {
    sendChatMessage({'type': 'abort-session', 'sessionId': sessionId});
  }

  /// Initialize shell session
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

  /// Send input to shell
  void sendShellInput(String input) {
    sendShellCommand({'type': 'input', 'data': input});
  }

  /// Resize shell terminal
  void resizeShell(int cols, int rows) {
    sendShellCommand({'type': 'resize', 'cols': cols, 'rows': rows});
  }

  /// Disconnect chat WebSocket
  Future<void> disconnectChat() async {
    if (_chatChannel != null) {
      await _chatChannel!.sink.close();
      _chatChannel = null;
      _chatConnectionController.add(false);
    }
  }

  /// Disconnect shell WebSocket
  Future<void> disconnectShell() async {
    if (_shellChannel != null) {
      await _shellChannel!.sink.close();
      _shellChannel = null;
      _shellConnectionController.add(false);
    }
  }

  /// Disconnect all WebSockets
  Future<void> disconnectAll() async {
    await Future.wait([disconnectChat(), disconnectShell()]);
  }

  /// Dispose all resources
  void dispose() {
    disconnectAll();
    _httpClient.close();
    _chatMessageController.close();
    _shellOutputController.close();
    _chatConnectionController.close();
    _shellConnectionController.close();
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message';
}
