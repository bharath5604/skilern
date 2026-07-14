import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../env.dart';
import 'auth_service.dart';

class StudentService {
  StudentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final String baseUrl = '${Env.apiBaseUrl}/api/students';
  static const Duration _timeout = Duration(seconds: 20);

  Map<String, String> _headers() {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (AuthService.token != null && AuthService.token!.trim().isNotEmpty)
        'Authorization': 'Bearer ${AuthService.token}',
    };
  }

  Uri _buildUri(String path, [Map<String, String>? params]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: (params == null || params.isEmpty) ? null : params,
    );
  }

  dynamic _decodeResponse(http.Response res) {
    final trimmed = res.body.trim();
    if (trimmed.isEmpty) return null;

    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }

  String _extractErrorMessage(dynamic body, int statusCode) {
    if (body is Map) {
      final msg =
          body['message'] ??
          body['error'] ??
          body['details'] ??
          'Request failed ($statusCode)';

      if (msg is List) {
        return msg.map((e) => e.toString()).join(', ');
      }

      return msg.toString();
    }

    if (body is String && body.trim().isNotEmpty) {
      return body.trim();
    }

    if (statusCode >= 500) {
      return 'Server error. Please try again later.';
    }

    return 'Request failed ($statusCode)';
  }

  Future<dynamic> _getRequest(Uri uri) async {
    try {
      final res =
          await _client.get(uri, headers: _headers()).timeout(_timeout);

      final data = _decodeResponse(res);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data;
      }

      throw Exception(_extractErrorMessage(data, res.statusCode));
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }

    throw Exception('Unexpected response format');
  }

  Map<String, dynamic> _asMap(dynamic data) {
    return _normalizeMap(data);
  }

  Future<Map<String, dynamic>> getPublicProfile(String studentId) async {
    if (studentId.trim().isEmpty) {
      throw Exception('Student id is required');
    }

    final uri = _buildUri('/$studentId/public-profile');
    final data = await _getRequest(uri);

    if (data == null) {
      throw Exception('Empty response while loading student profile');
    }

    return _asMap(data);
  }

  void dispose() {
    _client.close();
  }
}