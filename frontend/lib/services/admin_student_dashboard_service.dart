import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../env.dart';

class AdminStudentDashboardService {
  AdminStudentDashboardService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  final String baseUrl = '${Env.apiBaseUrl}/api/admin';
  static const Duration _timeout = Duration(seconds: 25);

  Map<String, String> get _headers {
    final token = AuthService.token;

    if (token == null || token.trim().isEmpty) {
      throw Exception('Admin token missing. Please login again.');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(
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
      return body.trim();
    }

    if (statusCode >= 500) {
      return 'Server error. Please try again later.';
    }

    return 'Failed to load student dashboard ($statusCode)';
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

  void _log(String message) {
    debugPrint('AdminStudentDashboardService: $message');
  }

  void _logResponse(http.Response res) {
    _log('GET ${res.request?.url} -> ${res.statusCode}');
  }

  /// Fetches the dashboard data for a specific student.
  /// FIXED: Changed path from '/students/$studentId/dashboard' to '/students/$studentId'
  /// because the previous route resulted in a 404 Exception.
  Future<Map<String, dynamic>> getStudentDashboard(String studentId) async {
    if (studentId.trim().isEmpty) {
      throw Exception('Student id is required');
    }

    // Using the base student detail route which typically contains the dashboard stats
    final uri = _buildUri('/students/$studentId');

    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);

      _logResponse(res);

      final body = _decodeBody(res);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _normalizeMap(body);
      }

      _log('Error body: ${res.body}');
      throw Exception(_extractErrorMessage(body, res.statusCode));
    } on TimeoutException {
      _log('Request timeout for $uri');
      throw Exception(
        'Request timed out while loading student dashboard. Please try again.',
      );
    } catch (e, st) {
      _log('getStudentDashboard error: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}