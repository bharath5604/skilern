import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../env.dart';
import 'auth_service.dart';

class StudentDashboardService {
  StudentDashboardService({http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl = '${Env.apiBaseUrl}/api';
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 20);

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (AuthService.token != null && AuthService.token!.trim().isNotEmpty)
        'Authorization': 'Bearer ${AuthService.token}',
    };
  }

  Future<Map<String, dynamic>> getFeedbackSummary(String studentId) async {
    return _getMap('/students/$studentId/feedback-summary');
  }

  Future<Map<String, dynamic>> getStudentPublicProfile(String studentId) async {
    return _getMap('/students/$studentId/public-profile');
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      final res = await _client
          .get(
            uri,
            headers: _headers(),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        throw Exception(_extractErrorMessage(res));
      }

      if (res.body.trim().isEmpty) {
        throw Exception('Empty response from server');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        throw Exception('Invalid response format');
      }

      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw Exception('Request timed out');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON response: $e');
    } catch (e) {
      throw Exception('Failed request: $e');
    }
  }

  String _extractErrorMessage(http.Response res) {
    try {
      if (res.body.trim().isEmpty) {
        return 'Request failed (${res.statusCode})';
      }

      final decoded = jsonDecode(res.body);

      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        final message = data['message'] ?? data['error'] ?? data['details'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {}

    return 'Request failed (${res.statusCode})';
  }

  void dispose() {
    _client.close();
  }
}