import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../env.dart';

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static String? token;
  static User? currentUser;

  /// Common getters used across UI/services.
  static String? get userId => currentUser?.id;
  static String? get role => currentUser?.role;
  static String? get userEmail => currentUser?.email;
  static String? get userName => currentUser?.name;

  /// Storage keys.
  static const _keyToken = 'auth_token';
  static const _keyUser = 'auth_user';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 25);

  /// API base.
  final String baseUrl = '${Env.apiBaseUrl}/api/auth';

  // =========================================================
  // SESSION MANAGEMENT
  // =========================================================

  static Future<void> saveSession(
    String newToken,
    User user,
  ) async {
    token = newToken;
    currentUser = user;

    await _storage.write(key: _keyToken, value: newToken);
    await _storage.write(key: _keyUser, value: jsonEncode(user.toJson()));
  }

  static Future<bool> loadSession() async {
    try {
      final storedToken = await _storage.read(key: _keyToken);
      final storedUser = await _storage.read(key: _keyUser);

      if (storedToken == null || storedUser == null || storedUser == "null") {
        token = null;
        currentUser = null;
        return false;
      }

      final decodedUser = jsonDecode(storedUser);
      if (decodedUser is! Map<String, dynamic>) return false;

      final user = User.fromJson(decodedUser);

      token = storedToken;
      currentUser = user;
      return true;
    } catch (e) {
      debugPrint("AuthService: Session recovery failed - $e");
      await clearSession();
      return false;
    }
  }

  static Future<void> clearSession() async {
    token = null;
    currentUser = null;

    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUser);
  }

  static Future<void> logout() async {
    await clearSession();
  }

  static bool get isLoggedIn => token != null && currentUser != null;

  static Map<String, String> authHeaders() {
    return {
      'Content-Type': 'application/json',
      if (token != null && token!.trim().isNotEmpty)
        'Authorization': 'Bearer ${token!.trim()}',
    };
  }

  // =========================================================
  // NETWORK HELPERS
  // =========================================================

  Uri _buildUri(String path) => Uri.parse('$baseUrl$path');

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('AuthService: $message');
    }
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

  String _extractMessage(dynamic body, {String fallback = 'Request failed'}) {
    if (body is Map) {
      final message =
          body['message'] ?? body['error'] ?? body['details'] ?? body['msg'];

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

    return fallback;
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final encodedBody = jsonEncode(body);

      final res = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: encodedBody,
          )
          .timeout(_timeout);

      _log('POST ${res.request?.url} -> ${res.statusCode}');
      
      final decoded = _decodeBody(res);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {'success': true, 'data': decoded};
      }

      return {
        'success': false,
        'message': _extractMessage(decoded, fallback: 'Error (${res.statusCode})'),
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Server Error', 'error': e.toString()};
    }
  }

  // =========================================================
  // AUTHENTICATION FLOWS
  // =========================================================

  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final uri = _buildUri('/login');

    final data = await _postJson(
      uri,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    final receivedToken = data['token'];
    final receivedUser = data['user'];

    if (receivedToken != null && receivedUser != null) {
      try {
        final user = User.fromJson(
          receivedUser is Map<String, dynamic>
              ? receivedUser
              : Map<String, dynamic>.from(receivedUser as Map),
        );
        await saveSession(receivedToken.toString(), user);
      } catch (e) {
        return {
          'success': false,
          'message': 'Login succeeded but profile was malformed.',
        };
      }
    }

    return data;
  }

  /// Signup Phase 1: Validates data and triggers Gmail OTP.
  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
    String role, {
    String? mobile,
    String? company,
    String? location, 
    String? domain,
    String? idCardUrl, 
    List<String>? skills,
    String? accountHolder,
    String? accountNumber,
    String? ifsc,
    String? bankName,
  }) async {
    final normalizedRole = role.trim().toLowerCase();

    final Map<String, dynamic> body = {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'role': normalizedRole,
      'mobile': (mobile ?? '').trim(),
      'location': (location ?? '').trim(), 
    };

    if (normalizedRole == 'client') {
      body['company'] = (company ?? '').trim();
      if ((domain ?? '').trim().isNotEmpty) {
        body['domain'] = domain!.trim();
      }
    }

    if (normalizedRole == 'student') {
      body['skills'] = (skills ?? [])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      body['idCardUrl'] = (idCardUrl ?? '').trim(); 
      body['bankAccountHolderName'] = (accountHolder ?? '').trim();
      body['bankAccountNumber'] = (accountNumber ?? '').trim();
      body['ifscCode'] = (ifsc ?? '').trim();
      body['bankName'] = (bankName ?? '').trim();
    }

    final uri = _buildUri('/signup');
    return await _postJson(uri, body: body);
  }

  // =========================================================
  // MODIFICATION: SIGNUP OTP VERIFICATION
  // =========================================================

  /// Signup Phase 2: Verifies the Gmail OTP and finalizes user creation.
  Future<Map<String, dynamic>> verifySignupOTP(String email, String otp) async {
    final uri = _buildUri('/verify-signup');
    final data = await _postJson(uri, body: {
      'email': email.trim(),
      'otp': otp.trim(),
    });

    // Logic: If the backend creates the user and returns a token immediately
    final receivedToken = data['token'];
    final receivedUser = data['user'];

    if (data['success'] == true && receivedToken != null && receivedUser != null) {
      try {
        final user = User.fromJson(
          receivedUser is Map<String, dynamic>
              ? receivedUser
              : Map<String, dynamic>.from(receivedUser as Map),
        );
        await saveSession(receivedToken.toString(), user);
      } catch (_) {
        // Fallback: If session save fails, user can manually login
      }
    }

    return data;
  }

  // =========================================================
  // PASSWORD RESET
  // =========================================================

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final uri = _buildUri('/forgot-password');
    return await _postJson(uri, body: {'email': email.trim()});
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    final uri = _buildUri('/reset-password');
    return await _postJson(uri, body: {
      'email': email.trim(),
      'otp': otp.trim(),
      'newPassword': newPassword.trim(),
    });
  }

  // =========================================================
  // USER UPDATES
  // =========================================================

  static Future<void> updateCurrentUser(User user) async {
    currentUser = user;
    await _storage.write(key: _keyUser, value: jsonEncode(user.toJson()));
  }

  void dispose() {
    _client.close();
  }
}