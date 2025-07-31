import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/project.dart';
import '../models/session.dart';
import '../models/message.dart';

class AppProvider extends ChangeNotifier {
  // Unified API client
  late ApiClient _apiClient;

  // State
  List<Project> _projects = [];
  Project? _selectedProject;
  Session? _selectedSession;
  List<ChatMessage> _chatMessages = [];
  List<Map<String, dynamic>> _shellMessages = [];
  bool _isLoading = false;
  bool _isChatConnected = false;
  bool _isShellConnected = false;
  String? _error;
  String _serverUrl = 'https://claude.grabr.cc';

  // Constructor
  AppProvider() {
    _initializeServices();
  }

  // Getters
  List<Project> get projects => _projects;
  Project? get selectedProject => _selectedProject;
  Session? get selectedSession => _selectedSession;
  List<ChatMessage> get chatMessages => _chatMessages;
  List<Map<String, dynamic>> get shellMessages => _shellMessages;
  bool get isLoading => _isLoading;
  bool get isChatConnected => _isChatConnected;
  bool get isShellConnected => _isShellConnected;
  String? get error => _error;
  String get serverUrl => _serverUrl;
  ApiClient get apiClient => _apiClient;

  void _initializeServices() {
    _apiClient = ApiClient(baseUrl: _serverUrl);

    // Listen to WebSocket connection status
    _apiClient.chatConnectionStatus.listen((connected) {
      _isChatConnected = connected;
      notifyListeners();
    });

    _apiClient.shellConnectionStatus.listen((connected) {
      _isShellConnected = connected;
      notifyListeners();
    });

    // Listen to chat messages
    _apiClient.chatMessages.listen((message) {
      _handleWebSocketMessage(message);
    });

    // Listen to shell output
    _apiClient.shellOutput.listen((message) {
      _handleShellOutput(message);
    });
  }

  // Update server URL
  Future<void> updateServerUrl(String newUrl) async {
    _serverUrl = newUrl;
    _apiClient.updateBaseUrl(newUrl);

    // Reconnect WebSockets if they were connected
    if (_isChatConnected) {
      await _apiClient.connectChat();
    }
    if (_isShellConnected) {
      await _apiClient.connectShell();
    }

    notifyListeners();
  }

  // Handle incoming WebSocket messages
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    try {
      final type = message['type'] as String?;

      switch (type) {
        case 'projects_updated':
          _handleProjectsUpdate(message);
          break;
        case 'claude-response':
          _handleClaudeResponse(message);
          break;
        case 'session-created':
          _handleSessionCreated(message);
          break;
        case 'session-aborted':
          _handleSessionAborted(message);
          break;
        case 'error':
          _handleError(message['error']);
          break;
      }
    } catch (e) {
      _handleError('Error processing WebSocket message: $e');
    }
  }

  void _handleProjectsUpdate(Map<String, dynamic> message) {
    try {
      final projectsData = message['projects'] as List;
      _projects = projectsData.map((json) => Project.fromJson(json)).toList();

      // Update selected project if it still exists
      if (_selectedProject != null) {
        _selectedProject = _projects.firstWhere(
          (p) => p.name == _selectedProject!.name,
          orElse: () => _selectedProject!,
        );
      }

      notifyListeners();
    } catch (e) {
      _handleError('Error updating projects: $e');
    }
  }

  void _handleClaudeResponse(Map<String, dynamic> message) {
    try {
      final content = message['content'] as String? ?? '';
      final sessionId = message['sessionId'] as String?;

      // Create new message
      final chatMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'assistant',
        content: content,
        timestamp: DateTime.now(),
        metadata: {
          'sessionId': sessionId,
          'streaming': message['streaming'] ?? false,
        },
      );

      _addChatMessage(chatMessage);
    } catch (e) {
      _handleError('Error processing Claude response: $e');
    }
  }

  void _handleSessionCreated(Map<String, dynamic> message) {
    final sessionId = message['sessionId'] as String?;
    if (sessionId != null && _selectedProject != null) {
      // Refresh project sessions
      loadProjectSessions(_selectedProject!.name);
    }
  }

  void _handleSessionAborted(Map<String, dynamic> message) {
    final sessionId = message['sessionId'] as String?;
    // Handle session abortion if needed
    _clearError();
    notifyListeners();
  }

  void _handleShellOutput(Map<String, dynamic> message) {
    try {
      _shellMessages.add(message);
      notifyListeners();
    } catch (e) {
      _handleError('Error processing shell output: $e');
    }
  }

  void _addChatMessage(ChatMessage message) {
    _chatMessages.add(message);
    notifyListeners();
  }

  void _handleError(String errorMessage) {
    _error = errorMessage;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Project operations
  Future<void> loadProjects() async {
    try {
      _setLoading(true);
      _clearError();

      _projects = await _apiClient.getProjects();
      notifyListeners();
    } catch (e) {
      _handleError('Failed to load projects: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectProject(Project project) async {
    _selectedProject = project;
    _selectedSession = null;
    _chatMessages.clear();
    notifyListeners();

    // Load project sessions
    await loadProjectSessions(project.name);
  }

  Future<void> loadProjectSessions(String projectName) async {
    try {
      _clearError();

      final sessions = await _apiClient.getSessions(projectName);

      // Update the selected project with loaded sessions
      if (_selectedProject?.name == projectName) {
        _selectedProject = _selectedProject!.copyWith(sessions: sessions);
        notifyListeners();
      }
    } catch (e) {
      _handleError('Failed to load sessions: $e');
    }
  }

  Future<void> selectSession(Session session) async {
    try {
      _selectedSession = session;
      _chatMessages.clear();
      notifyListeners();

      if (_selectedProject != null) {
        _setLoading(true);
        final messages = await _apiClient.getSessionMessages(
          _selectedProject!.name,
          session.id,
        );
        _chatMessages = messages;
        notifyListeners();
      }
    } catch (e) {
      _handleError('Failed to load session messages: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createProject(String path) async {
    try {
      _setLoading(true);
      _clearError();

      await _apiClient.createProject(path);
      await loadProjects();
    } catch (e) {
      _handleError('Failed to create project: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteProject(String projectName) async {
    try {
      _setLoading(true);
      _clearError();

      await _apiClient.deleteProject(projectName);

      // Clear selection if deleted project was selected
      if (_selectedProject?.name == projectName) {
        _selectedProject = null;
        _selectedSession = null;
        _chatMessages.clear();
      }

      await loadProjects();
    } catch (e) {
      _handleError('Failed to delete project: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> renameProject(String projectName, String newDisplayName) async {
    try {
      _clearError();

      await _apiClient.renameProject(projectName, newDisplayName);
      await loadProjects();
    } catch (e) {
      _handleError('Failed to rename project: $e');
    }
  }

  // Chat operations
  Future<void> connectChat() async {
    try {
      await _apiClient.connectChat();
    } catch (e) {
      _handleError('Failed to connect to chat: $e');
    }
  }

  Future<void> disconnectChat() async {
    await _apiClient.disconnectChat();
  }

  void sendMessage(String content, {List<String>? images}) {
    if (_selectedProject == null) {
      _handleError('No project selected');
      return;
    }

    // Add user message to chat
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'user',
      content: content,
      images: images,
      timestamp: DateTime.now(),
    );

    _addChatMessage(userMessage);

    // Send to WebSocket
    _apiClient.sendClaudeCommand(
      content,
      projectPath: _selectedProject!.path,
      sessionId: _selectedSession?.id,
      images: images,
    );
  }

  void abortCurrentSession() {
    if (_selectedSession != null) {
      _apiClient.abortSession(_selectedSession!.id);
    }
  }

  // Shell operations
  Future<void> connectShell() async {
    try {
      await _apiClient.connectShell();

      // Initialize shell with current project/session
      if (_selectedProject != null) {
        _apiClient.initializeShell(
          projectPath: _selectedProject!.path,
          sessionId: _selectedSession?.id,
          hasSession: _selectedSession != null,
        );
      }
    } catch (e) {
      _handleError('Failed to connect to shell: $e');
    }
  }

  Future<void> disconnectShell() async {
    await _apiClient.disconnectShell();
  }

  void sendShellInput(String input) {
    _apiClient.sendShellInput(input);
  }

  void resizeShell(int cols, int rows) {
    _apiClient.resizeShell(cols, rows);
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }
}
