import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../env.dart';

/// Landing stats service for public landing page.
///
/// Backend route: GET /api/stats
/// Expected response:
/// {
///   "students": number,
///   "clients": number,
///   "tasks": number
/// }
class StatsService {
  StatsService({http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl = '${Env.apiBaseUrl}/api/stats';
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, int>> getStats() async {
    try {
      final uri = Uri.parse(baseUrl);

      final res = await _client.get(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (res.statusCode != 200) {
        throw Exception(_extractErrorMessage(res));
      }

      if (res.body.trim().isEmpty) {
        throw Exception('Stats response was empty');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        throw Exception('Invalid stats response format');
      }

      final data = Map<String, dynamic>.from(decoded);

      return {
        'students': _toInt(data['students']),
        'clients': _toInt(data['clients']),
        'tasks': _toInt(data['tasks']),
      };
    } on TimeoutException {
      throw Exception('Request timed out while loading stats');
    } on http.ClientException catch (e) {
      throw Exception('Network error while loading stats: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON received for stats: $e');
    } catch (e) {
      throw Exception('Failed to load stats: $e');
    }
  }

  String _extractErrorMessage(http.Response res) {
    try {
      if (res.body.trim().isEmpty) {
        return 'Failed to load stats (${res.statusCode})';
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

    return 'Failed to load stats (${res.statusCode})';
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  void dispose() {
    _client.close();
  }
}