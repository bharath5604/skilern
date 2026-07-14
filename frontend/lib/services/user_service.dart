import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../env.dart';
import '../models/user.dart';
import 'auth_service.dart';

class UserService {
  UserService({http.Client? client}) : _client = client ?? http.Client();

  // NOTE: no trailing slash
  final String baseUrl = '${Env.apiBaseUrl}/api/users';
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 20);

  // ============================================================
  // ORIGINAL HELPERS (RESTORED 100%)
  // ============================================================

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (AuthService.token != null && AuthService.token!.trim().isNotEmpty)
        'Authorization': 'Bearer ${AuthService.token}',
    };
  }

  Map<String, dynamic> _decodeMap(
    String body, {
    required String fallback,
    bool allowEmpty = false,
  }) {
    if (body.trim().isEmpty) {
      if (allowEmpty) return <String, dynamic>{};
      throw Exception(fallback);
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw Exception(fallback);
    }

    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic> _extractUserMap(Map<String, dynamic> data) {
    final userRaw = data.containsKey('user') ? data['user'] : data;

    if (userRaw is! Map) {
      throw Exception('Invalid user payload');
    }

    return Map<String, dynamic>.from(userRaw);
  }

  String _extractErrorMessage(http.Response res, {String? fallback}) {
    final body = res.body.trim();

    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);

        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
          final message = data['message'];
          final error = data['error'];
          final details = data['details'];

          if (message != null && message.toString().trim().isNotEmpty) {
            return message.toString().trim();
          }
          if (error != null && error.toString().trim().isNotEmpty) {
            return error.toString().trim();
          }
          if (details != null && details.toString().trim().isNotEmpty) {
            return details.toString().trim();
          }
        }
      } catch (_) {
        return fallback ?? 'Request failed (${res.statusCode})';
      }
    }

    if (res.statusCode == 401) {
      return 'Unauthorized: Invalid or missing token';
    }
    if (res.statusCode == 403) {
      return 'Forbidden: You are not allowed to perform this action';
    }
    if (res.statusCode >= 500) {
      return 'Server error. Please try again later.';
    }

    return fallback ?? 'Request failed (${res.statusCode})';
  }

  // ============================================================
  // CORE PROFILE METHODS
  // ============================================================

  Future<User> getMe() async {
    try {
      final uri = Uri.parse('$baseUrl/me');
      final res = await _client.get(uri, headers: _headers()).timeout(_timeout);

      if (res.statusCode != 200) {
        throw Exception(_extractErrorMessage(
          res,
          fallback: 'Failed to load profile (${res.statusCode})',
        ));
      }

      final data = _decodeMap(res.body, fallback: 'Invalid profile response');
      final userJson = _extractUserMap(data);

      return User.fromJson(userJson);
    } on TimeoutException {
      throw Exception('Request timed out while loading profile');
    } on http.ClientException catch (e) {
      throw Exception('Network error while loading profile: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON received while loading profile: $e');
    } catch (e) {
      throw Exception('Failed to load profile: $e');
    }
  }

  Future<User> updateMe(Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl/me');
      final res = await _client
          .put(
            uri,
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final data = _decodeMap(
        res.body,
        fallback: 'Invalid update profile response',
        allowEmpty: false,
      );

      if (res.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ??
              data['error']?.toString() ??
              'Failed to update profile',
        );
      }

      final userJson = _extractUserMap(data);
      return User.fromJson(userJson);
    } on TimeoutException {
      throw Exception('Request timed out while updating profile');
    } on http.ClientException catch (e) {
      throw Exception('Network error while updating profile: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON received while updating profile: $e');
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // ============================================================
  // WITHDRAWAL MODULE (NEW)
  // ============================================================

  /// NEW: Sends a withdrawal request to the SKILEN admin.
  /// Hits POST /api/users/withdraw
  Future<Map<String, dynamic>> requestWithdrawal(double amount) async {
    try {
      final uri = Uri.parse('$baseUrl/withdraw');
      final res = await _client.post(
        uri,
        headers: _headers(),
        body: jsonEncode({'amount': amount}),
      ).timeout(_timeout);

      final data = _decodeMap(res.body, fallback: 'Invalid withdrawal response');

      if (res.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Withdrawal request failed',
        );
      }

      return data;
    } on TimeoutException {
      throw Exception('Request timed out while submitting withdrawal');
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================
  // PAYMENT STATS (RESTORED 100%)
  // ============================================================

  /// Quote-based payment stats for the logged-in student:
  /// - totalAcceptedQuotes
  /// - totalPendingQuotes
  /// - totalReceivedQuotes
  Future<Map<String, dynamic>> getMyPaymentStats() async {
    try {
      final uri = Uri.parse('$baseUrl/me/payment-stats');
      final res = await _client.get(uri, headers: _headers()).timeout(_timeout);

      if (res.statusCode != 200) {
        throw Exception(_extractErrorMessage(
          res,
          fallback: 'Failed to load payment stats',
        ));
      }

      return _decodeMap(res.body, fallback: 'Invalid payment stats response');
    } on TimeoutException {
      throw Exception('Request timed out while loading payment stats');
    } on http.ClientException catch (e) {
      throw Exception('Network error while loading payment stats: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON received while loading payment stats: $e');
    } catch (e) {
      throw Exception('Failed to load payment stats: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}