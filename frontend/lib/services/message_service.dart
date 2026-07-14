import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../env.dart';
import 'auth_service.dart';

/// Service for handling task-related messaging across three conversation types:
/// 1. Admin ↔ Client (task-level discussions)
/// 2. Admin ↔ Student (student-specific guidance)
/// 3. Legacy /api/messages/task (backward compatibility)
class MessageService {
  MessageService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  final String messagesBaseUrl = '${Env.apiBaseUrl}/api/messages';
  final String adminBaseUrl = '${Env.apiBaseUrl}/api/admin/tasks';

  static const Duration _timeout = Duration(seconds: 20);

  bool get _shouldLog => kDebugMode;

  void _log(String message) {
    if (_shouldLog) {
      debugPrint('[MessageService] $message');
    }
  }

  // ---------------------------------------------------------------------------
  // URI BUILDERS
  // ---------------------------------------------------------------------------

  Uri _buildMessagesUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$messagesBaseUrl$path').replace(
      queryParameters:
          (queryParameters == null || queryParameters.isEmpty)
              ? null
              : queryParameters,
    );
  }

  Uri _buildAdminUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$adminBaseUrl$path').replace(
      queryParameters:
          (queryParameters == null || queryParameters.isEmpty)
              ? null
              : queryParameters,
    );
  }

  Uri _legacyTaskMessagesUri({
    required String taskId,
    String? studentId,
  }) {
    final queryParams = <String, String>{
      'taskId': taskId.trim(),
      if (studentId != null && studentId.trim().isNotEmpty)
        'studentId': studentId.trim(),
    };
    return _buildMessagesUri('/task', queryParams);
  }

  Uri _adminClientMessagesUri(String taskId) {
    return _buildAdminUri('/${taskId.trim()}/chat/client/messages');
  }

  Uri _adminStudentMessagesUri({
    required String taskId,
    required String studentId,
  }) {
    return _buildAdminUri('/${taskId.trim()}/chat/student/messages', {
      'studentId': studentId.trim(),
    });
  }

  Uri _adminClientSendUri(String taskId) {
    return _buildAdminUri('/${taskId.trim()}/chat/client/messages');
  }

  Uri _adminStudentSendUri({
    required String taskId,
  }) {
    return _buildAdminUri('/${taskId.trim()}/chat/student/messages');
  }

  // ---------------------------------------------------------------------------
  // HEADERS & UTILITIES
  // ---------------------------------------------------------------------------

  Map<String, String> _headers() {
    final token = AuthService.token;
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.trim().isNotEmpty)
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
    };
  }

  dynamic _decodeJsonBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }

  String _extractErrorMessage(http.Response res) {
    final decoded = _decodeJsonBody(res.body);
    if (decoded is Map) {
      final message = decoded['message'] ?? decoded['error'] ?? decoded['details'] ?? decoded['msg'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
      if (message is List && message.isNotEmpty) return message.map((e) => e.toString()).join(', ');
    }
    return 'Request failed (${res.statusCode}).';
  }

  List<Map<String, dynamic>> _parseMessageList(dynamic decoded) {
    if (decoded == null) return <Map<String, dynamic>>[];
    if (decoded is List) {
      final messages = decoded
          .whereType<Map>()
          .map((e) => _normalizeMessageMap(Map<String, dynamic>.from(e)))
          .toList();
      messages.sort(_sortMessagesByTimeAscending);
      return messages;
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeMessageMap(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    if (map['text'] == null && map['message'] != null) map['text'] = map['message'];
    if (map['sender'] is Map) map['sender'] = Map<String, dynamic>.from(map['sender'] as Map);
    if (map['receiver'] is Map) map['receiver'] = Map<String, dynamic>.from(map['receiver'] as Map);
    return map;
  }

  int _sortMessagesByTimeAscending(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aTime = _tryParseDate(a['createdAt'] ?? a['timestamp']);
    final bTime = _tryParseDate(b['createdAt'] ?? b['timestamp']);
    return aTime.compareTo(bTime);
  }

  DateTime _tryParseDate(dynamic value) {
    if (value == null) return DateTime(1970);
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime(1970);
  }

  void _ensureSuccess(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractErrorMessage(res));
    }
  }

  // ---------------------------------------------------------------------------
  // HTTP METHODS
  // ---------------------------------------------------------------------------

  Future<http.Response> _get(Uri uri) async {
    try {
      final res = await _client.get(uri, headers: _headers()).timeout(_timeout);
      _log('GET ${res.statusCode} $uri');
      return res;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<http.Response> _post(Uri uri, Map<String, dynamic> payload) async {
    try {
      final res = await _client.post(uri, headers: _headers(), body: jsonEncode(payload)).timeout(_timeout);
      _log('POST ${res.statusCode} $uri');
      return res;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  // --- ADMIN ↔ CLIENT ---

  Future<List<Map<String, dynamic>>> getAdminClientMessages({required String taskId}) async {
    final res = await _get(_adminClientMessagesUri(taskId));
    _ensureSuccess(res);
    return _parseMessageList(_decodeJsonBody(res.body));
  }

  Future<Map<String, dynamic>> sendAdminClientMessage({
    required String taskId,
    required String text,
    String? fileUrl,
    String? fileName,
  }) async {
    final payload = {
      'text': text.trim(),
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
    };
    final res = await _post(_adminClientSendUri(taskId), payload);
    _ensureSuccess(res);
    return _normalizeMessageMap(Map<String, dynamic>.from(jsonDecode(res.body)));
  }

  // --- ADMIN ↔ STUDENT ---

  Future<List<Map<String, dynamic>>> getAdminStudentMessages({
    required String taskId,
    required String studentId,
  }) async {
    final res = await _get(_adminStudentMessagesUri(taskId: taskId, studentId: studentId));
    _ensureSuccess(res);
    return _parseMessageList(_decodeJsonBody(res.body));
  }

  Future<Map<String, dynamic>> sendAdminStudentMessage({
    required String taskId,
    required String studentId,
    required String text,
    String? fileUrl,
    String? fileName,
  }) async {
    final payload = {
      'text': text.trim(),
      'studentId': studentId.trim(),
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
    };
    final res = await _post(_adminStudentSendUri(taskId: taskId), payload);
    _ensureSuccess(res);
    return _normalizeMessageMap(Map<String, dynamic>.from(jsonDecode(res.body)));
  }

  // --- STANDARD / LEGACY ---

  Future<List<Map<String, dynamic>>> getTaskMessages(String taskId, {String? studentId}) async {
    final res = await _get(_legacyTaskMessagesUri(taskId: taskId, studentId: studentId));
    _ensureSuccess(res);
    return _parseMessageList(_decodeJsonBody(res.body));
  }

  Future<Map<String, dynamic>> sendTaskMessage(
    String taskId,
    String text, {
    String? fileUrl,
    String? fileName,
    String? targetRole,
    String? studentId,
  }) async {
    final payload = {
      'taskId': taskId.trim(),
      'text': text.trim(),
      'targetRole': targetRole ?? 'admin',
      if (studentId != null) 'studentId': studentId,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
    };
    final res = await _post(_buildMessagesUri('/task'), payload);
    _ensureSuccess(res);
    return _normalizeMessageMap(Map<String, dynamic>.from(jsonDecode(res.body)));
  }

  void dispose() {
    _client.close();
  }
}