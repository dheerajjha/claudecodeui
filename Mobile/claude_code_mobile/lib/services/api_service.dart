import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/project.dart';
import '../models/session.dart';
import '../models/message.dart';
import '../models/file_item.dart';

class ApiService {
  static const String _defaultBaseUrl = 'http://localhost:3008';

  String _baseUrl;
  late http.Client _client;

  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl {
    _client = http.Client();
  }

  // Update base URL (useful for connecting to different servers)
  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
  }

  String get baseUrl => _baseUrl;

  // Generic API request method
  Future<http.Response> _request(
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
          return await _client.get(url, headers: finalHeaders);
        case 'POST':
          return await _client.post(
            url,
            headers: finalHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
        case 'PUT':
          return await _client.put(
            url,
            headers: finalHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
        case 'DELETE':
          return await _client.delete(url, headers: finalHeaders);
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // Helper to parse response
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

  // Server configuration
  Future<Map<String, dynamic>> getConfig() async {
    final response = await _request('GET', '/api/config');
    return _parseResponse(response);
  }

  // Project endpoints
  Future<List<Project>> getProjects() async {
    final response = await _request('GET', '/api/projects');
    final data = _parseResponse(response) as List;
    return data.map((json) => Project.fromJson(json)).toList();
  }

  Future<void> createProject(String path) async {
    await _request('POST', '/api/projects/create', body: {'path': path});
  }

  Future<void> deleteProject(String projectName) async {
    await _request('DELETE', '/api/projects/$projectName');
  }

  Future<void> renameProject(String projectName, String displayName) async {
    await _request(
      'PUT',
      '/api/projects/$projectName/rename',
      body: {'displayName': displayName},
    );
  }

  // Session endpoints
  Future<List<Session>> getSessions(
    String projectName, {
    int limit = 5,
    int offset = 0,
  }) async {
    final response = await _request(
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
    final response = await _request(
      'GET',
      '/api/projects/$projectName/sessions/$sessionId/messages',
    );
    final data = _parseResponse(response) as List;
    return data.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<void> deleteSession(String projectName, String sessionId) async {
    await _request('DELETE', '/api/projects/$projectName/sessions/$sessionId');
  }

  // File operations
  Future<List<FileItem>> getFiles(String projectName) async {
    final response = await _request('GET', '/api/projects/$projectName/files');
    final data = _parseResponse(response) as List;
    return data.map((json) => FileItem.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> readFile(
    String projectName,
    String filePath,
  ) async {
    final encodedPath = Uri.encodeComponent(filePath);
    final response = await _request(
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
    await _request(
      'PUT',
      '/api/projects/$projectName/file',
      body: {'filePath': filePath, 'content': content},
    );
  }

  // Git operations
  Future<Map<String, dynamic>> getGitStatus(String projectName) async {
    final encodedProject = Uri.encodeComponent(projectName);
    final response = await _request(
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
    final response = await _request(
      'GET',
      '/api/git/diff?project=$encodedProject&file=$encodedPath',
    );
    return _parseResponse(response);
  }

  Future<void> stageFile(String projectName, String filePath) async {
    await _request(
      'POST',
      '/api/git/stage',
      body: {'project': projectName, 'file': filePath},
    );
  }

  Future<void> unstageFile(String projectName, String filePath) async {
    await _request(
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
    await _request(
      'POST',
      '/api/git/commit',
      body: {'project': projectName, 'message': message, 'files': files},
    );
  }

  Future<List<String>> getBranches(String projectName) async {
    final encodedProject = Uri.encodeComponent(projectName);
    final response = await _request(
      'GET',
      '/api/git/branches?project=$encodedProject',
    );
    final data = _parseResponse(response);
    return List<String>.from(data['branches'] ?? []);
  }

  Future<void> createBranch(String projectName, String branchName) async {
    await _request(
      'POST',
      '/api/git/branch',
      body: {'project': projectName, 'branch': branchName},
    );
  }

  Future<void> switchBranch(String projectName, String branchName) async {
    await _request(
      'POST',
      '/api/git/checkout',
      body: {'project': projectName, 'branch': branchName},
    );
  }

  // Audio transcription
  Future<String> transcribeAudio(File audioFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/transcribe'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    final data = _parseResponse(response);
    return data['text'] ?? '';
  }

  // Image upload
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

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    final data = _parseResponse(response);
    return List<String>.from(data['images'] ?? []);
  }

  void dispose() {
    _client.close();
  }
}

// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message';
}
