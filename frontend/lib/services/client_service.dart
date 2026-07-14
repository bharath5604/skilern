import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../env.dart';

class ClientService {
  ClientService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl = '${Env.apiBaseUrl}/api/clients';
  final String messagesBaseUrl = '${Env.apiBaseUrl}/api/messages';

  static const Duration _timeout = Duration(seconds: 25);

  bool get _shouldLog => kDebugMode;

  void _log(String message) {
    if (_shouldLog) {
      debugPrint('[ClientService] $message');
    }
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = AuthService.token;
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    return headers;
  }

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters:
          (queryParameters == null || queryParameters.isEmpty)
              ? null
              : queryParameters,
    );
  }

  Uri _buildMessagesUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$messagesBaseUrl$path').replace(
      queryParameters:
          (queryParameters == null || queryParameters.isEmpty)
              ? null
              : queryParameters,
    );
  }

  dynamic _decodeBody(http.Response res) {
    final raw = res.body.trim();
    if (raw.isEmpty) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  String _extractErrorMessage(dynamic body, int statusCode) {
    if (body is Map) {
      final message =
          body['message'] ??
          body['error'] ??
          body['details'] ??
          body['msg'];

      if (message is List) {
        final joined = message.map((e) => e.toString()).join(', ').trim();
        if (joined.isNotEmpty) return joined;
      }

      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }

    if (body is String && body.trim().isNotEmpty) {
      if (body.startsWith('<!DOCTYPE html') || body.startsWith('<html')) {
        return statusCode >= 500
            ? 'Server error. Please try again later.'
            : 'Unexpected server response.';
      }
      return body.trim();
    }

    if (statusCode >= 500) {
      return 'Server error. Please try again later.';
    }

    return 'Request failed ($statusCode)';
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }

    throw Exception('Unexpected response format');
  }

  List<Map<String, dynamic>> _normalizeList(dynamic value) {
    if (value == null) return <Map<String, dynamic>>[];

    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => _normalizeMessageMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (value is Map) {
      final possibleList = value['messages'] ?? value['data'] ?? value['items'];
      if (possibleList is List) {
        return possibleList
            .whereType<Map>()
            .map((e) => _normalizeMessageMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    throw Exception('Unexpected list response format');
  }

  Map<String, dynamic> _normalizeMessageMap(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    if ((map['text'] == null || map['text'].toString().trim().isEmpty) &&
        map['message'] != null) {
      map['text'] = map['message'];
    }

    if ((map['message'] == null || map['message'].toString().trim().isEmpty) &&
        map['text'] != null) {
      map['message'] = map['text'];
    }

    if (map['sender'] is Map) {
      map['sender'] = Map<String, dynamic>.from(map['sender'] as Map);
    }

    if (map['receiver'] is Map) {
      map['receiver'] = Map<String, dynamic>.from(map['receiver'] as Map);
    }

    return map;
  }

  Future<dynamic> _get(Uri uri) async {
    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);

      _log('GET $uri -> ${res.statusCode}');
      if (_shouldLog) {
        _log('GET body: ${res.body}');
      }

      final body = _decodeBody(res);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return body;
      }

      throw Exception(_extractErrorMessage(body, res.statusCode));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> _post(Uri uri, {Map<String, dynamic>? body}) async {
    try {
      final encodedBody = body != null ? jsonEncode(body) : null;

      final res = await _client
          .post(
            uri,
            headers: _headers,
            body: encodedBody,
          )
          .timeout(_timeout);

      _log('POST $uri -> ${res.statusCode}');
      if (_shouldLog) {
        _log('POST payload: $encodedBody');
        _log('POST body: ${res.body}');
      }

      final decoded = _decodeBody(res);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return decoded;
      }

      throw Exception(_extractErrorMessage(decoded, res.statusCode));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  void _validateClientId(String clientId) {
    if (clientId.trim().isEmpty) {
      throw Exception('Client id is required');
    }
  }

  void _validateTaskId(String taskId) {
    if (taskId.trim().isEmpty) {
      throw Exception('Task id is required');
    }
  }

  void _validateMessage(String text, {bool fileAttached = false}) {
    if (text.trim().isEmpty && !fileAttached) {
      throw Exception('Message text cannot be empty');
    }
  }

  Map<String, dynamic> _buildTaskMessagePayload({
    required String taskId,
    required String text,
    String targetRole = 'admin',
    String? fileUrl,
    String? fileName,
  }) {
    final payload = <String, dynamic>{
      'taskId': taskId.trim(),
      'text': text.trim(),
      'targetRole': targetRole,
    };

    if (fileUrl != null && fileUrl.trim().isNotEmpty) {
      payload['fileUrl'] = fileUrl.trim();
    }

    if (fileName != null && fileName.trim().isNotEmpty) {
      payload['fileName'] = fileName.trim();
    }

    return payload;
  }

  Future<Map<String, dynamic>> getPublicProfile(String clientId) async {
    _validateClientId(clientId);

    final body = await _get(_buildUri('/${clientId.trim()}/public-profile'));
    return _normalizeMap(body);
  }

  Future<List<Map<String, dynamic>>> getTaskMessages(String taskId) async {
    _validateTaskId(taskId);

    final body = await _get(
      _buildMessagesUri('/task', {
        'taskId': taskId.trim(),
      }),
    );

    return _normalizeList(body);
  }

  Future<Map<String, dynamic>> sendTaskMessage({
    required String taskId,
    required String text,
    String targetRole = 'admin',
    String? fileUrl,
    String? fileName,
  }) async {
    _validateTaskId(taskId);

    final hasFile = fileUrl != null && fileUrl.trim().isNotEmpty;
    _validateMessage(text, fileAttached: hasFile);

    final body = await _post(
      _buildMessagesUri('/task'),
      body: _buildTaskMessagePayload(
        taskId: taskId,
        text: text,
        targetRole: targetRole,
        fileUrl: fileUrl,
        fileName: fileName,
      ),
    );

    return _normalizeMessageMap(_normalizeMap(body));
  }

  Future<List<Map<String, dynamic>>> getClientAdminMessages({
    required String taskId,
  }) async {
    return getTaskMessages(taskId);
  }

  Future<Map<String, dynamic>> sendClientAdminMessage({
    required String taskId,
    required String text,
    String? fileUrl,
    String? fileName,
  }) async {
    return sendTaskMessage(
      taskId: taskId,
      text: text,
      targetRole: 'admin',
      fileUrl: fileUrl,
      fileName: fileName,
    );
  }

  void dispose() {
    _client.close();
  }
}