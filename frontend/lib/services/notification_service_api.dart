// lib/services/notification_service_api.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../env.dart';
import 'auth_service.dart';

/// Service for interacting with the MongoDB Notification System on the VPS.
class NotificationServiceApi {
  NotificationServiceApi._internal();

  static final NotificationServiceApi instance =
      NotificationServiceApi._internal();

  // Logic: Points to your VPS API endpoint
  final String baseUrl = '${Env.apiBaseUrl}/api/notifications';
  final http.Client _client = http.Client();

  static const Duration _timeout = Duration(seconds: 20);

  /// Generates authenticated headers for VPS Security
  Map<String, String> _headers() {
    final token = AuthService.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.trim().isNotEmpty)
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
    };
  }

  Uri _buildUri([String? path, Map<String, String>? queryParameters]) {
    final uri = Uri.parse(path == null ? baseUrl : '$baseUrl$path');
    return uri.replace(
      queryParameters:
          queryParameters == null || queryParameters.isEmpty
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

  String _extractErrorMessage(http.Response res) {
    try {
      final body = _decodeBody(res);

      if (body is Map<String, dynamic>) {
        final message =
            body['message'] ?? body['error'] ?? body['details'] ?? body['msg'];

        if (message is List) {
          return message.map((e) => e.toString()).join(', ').trim();
        }

        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
      
      // Fallback for HTML error pages (crashes)
      if (res.body.contains('<!DOCTYPE html')) {
        return 'Server Error (${res.statusCode})';
      }
    } catch (_) {}

    return 'Request failed with status ${res.statusCode}';
  }

  void _ensureSuccess(http.Response res, {List<int> expectedStatuses = const [200]}) {
    if (!expectedStatuses.contains(res.statusCode)) {
      throw Exception(_extractErrorMessage(res));
    }
  }

  // ---------------------------------------------------------------------------
  // CORE API METHODS
  // ---------------------------------------------------------------------------

  /// Fetch notifications stored in MongoDB.
  /// Optional [since] lets you perform a delta-refresh (only new alerts).
  Future<List<Map<String, dynamic>>> getNotifications({
    DateTime? since,
  }) async {
    try {
      final params = <String, String>{};
      if (since != null) {
        params['since'] = since.toUtc().toIso8601String();
      }

      final res = await _client.get(
        _buildUri(null, params),
        headers: _headers(),
      ).timeout(_timeout);

      _ensureSuccess(res);

      final decoded = _decodeBody(res);
      
      // Logic: The backend returns an object with { notifications: [], unreadCount: X }
      if (decoded is Map && decoded.containsKey('notifications')) {
        return List<Map<String, dynamic>>.from(decoded['notifications']);
      }
      
      return [];
    } catch (e) {
      throw Exception('Failed to load notifications: $e');
    }
  }

  /// NEW: Fetches only the unread count from MongoDB
  Future<int> getUnreadCount() async {
    try {
      final res = await _client.get(
        _buildUri('/unread-count'),
        headers: _headers(),
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['unreadCount'] ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Mark specific notification IDs as read in MongoDB.
  Future<void> markAsRead(List<String> ids) async {
    final cleanedIds = ids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleanedIds.isEmpty) return;

    try {
      final res = await _client.post(
        _buildUri('/read'),
        headers: _headers(),
        body: jsonEncode({'ids': cleanedIds}),
      ).timeout(_timeout);

      _ensureSuccess(res);
    } catch (e) {
      throw Exception('Failed to update notification status: $e');
    }
  }

  /// Mark all unread notifications as read.
  Future<void> markAllAsRead() async {
    try {
      final res = await _client.post(
        _buildUri('/read-all'),
        headers: _headers(),
      ).timeout(_timeout);

      _ensureSuccess(res);
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  /// Sync the device FCM token to the User record in MongoDB.
  /// This enables the FCM Dispatcher in fcm.js
  Future<void> registerFcmToken(String token) async {
    if (token.trim().isEmpty) return;

    try {
      final res = await _client.post(
        _buildUri('/register-token'),
        headers: _headers(),
        body: jsonEncode({'token': token.trim()}),
      ).timeout(_timeout);

      _ensureSuccess(res, expectedStatuses: [200, 201]);
    } catch (e) {
      debugPrint('FCM Token Registration Error: $e');
    }
  }

  /// Removes the FCM token from the VPS database (on logout).
  Future<void> unregisterFcmToken(String token) async {
    if (token.trim().isEmpty) return;

    try {
      final res = await _client.post(
        _buildUri('/unregister-token'),
        headers: _headers(),
        body: jsonEncode({'token': token.trim()}),
      ).timeout(_timeout);

      _ensureSuccess(res, expectedStatuses: [200, 204]);
    } catch (e) {
      debugPrint('FCM Token Unregistration Error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}