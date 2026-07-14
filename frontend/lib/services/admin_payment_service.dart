import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../env.dart';

class AdminPaymentService {
  AdminPaymentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl = '${Env.apiBaseUrl}/api/admin';

  // ============================================================
  // ORIGINAL HELPERS (RESTORED 100%)
  // ============================================================

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = AuthService.token;
    if (token != null && token.trim().isNotEmpty) {
      // Logic Fix: Ensure Bearer prefix is used for backend middleware compatibility
      headers['Authorization'] = token.startsWith('Bearer ') ? token : 'Bearer $token';
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

  dynamic _decodeBody(http.Response res) {
    if (res.body.trim().isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  String _extractErrorMessage(http.Response res, String fallback) {
    try {
      final decoded = _decodeBody(res);

      if (decoded is Map<String, dynamic>) {
        final possibleMessage = decoded['message'] ??
            decoded['error'] ??
            decoded['msg'] ??
            decoded['details'];

        if (possibleMessage != null &&
            possibleMessage.toString().trim().isNotEmpty) {
          return possibleMessage.toString().trim();
        }
      }
    } catch (_) {}

    return '$fallback (${res.statusCode})';
  }

  void _ensureSuccess(http.Response res, String fallbackMessage) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractErrorMessage(res, fallbackMessage));
    }
  }

  List<Map<String, dynamic>> _parseListResponse(
    http.Response res,
    String fallbackMessage,
  ) {
    _ensureSuccess(res, fallbackMessage);

    final decoded = _decodeBody(res);
    if (decoded is List) {
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    
    if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
      return (decoded['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    throw Exception('Invalid response format: expected a list');
  }

  Map<String, dynamic> _parseMapResponse(
    http.Response res,
    String fallbackMessage,
  ) {
    _ensureSuccess(res, fallbackMessage);

    final decoded = _decodeBody(res);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Invalid response format: expected an object');
  }

  // ============================================================
  // PAYMENT MANAGEMENT METHODS
  // ============================================================

  // ============================================================
  // MODIFICATION: HYBRID PAYMENT FINALIZER
  // This method locks the budget and enables Razorpay for the Client.
  // ============================================================
  Future<Map<String, dynamic>> finalizeTaskBudget({
    required String taskId,
    required double amount,
  }) async {
    final res = await _client.patch(
      _buildUri('/tasks/$taskId/finalize-budget'),
      headers: _headers,
      body: jsonEncode({'amount': amount}),
    );

    return _parseMapResponse(res, 'Failed to finalize project budget');
  }

  /// List payments, optionally filtered by status:
  /// status = 'created' | 'held' | 'approved' | 'released' | 'cancelled'
  Future<List<Map<String, dynamic>>> getPayments({String? status}) async {
    final params = <String, String>{};

    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }

    final res = await _client.get(
      _buildUri('/payments', params),
      headers: _headers,
    );

    return _parseListResponse(res, 'Failed to load payments');
  }

  /// Get a single payment ledger by id
  Future<Map<String, dynamic>> getPaymentById(String id) async {
    final res = await _client.get(
      _buildUri('/payments/$id'),
      headers: _headers,
    );

    return _parseMapResponse(res, 'Failed to load payment');
  }

  /// Generic status update: PATCH /api/admin/payments/:id/status
  Future<Map<String, dynamic>> updatePaymentStatus({
    required String id,
    required String status,
    String? adminNote,
  }) async {
    final body = <String, dynamic>{
      'status': status.trim(),
      if (adminNote != null && adminNote.trim().isNotEmpty)
        'adminNote': adminNote.trim(),
    };

    final res = await _client.patch(
      _buildUri('/payments/$id/status'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _parseMapResponse(res, 'Failed to update payment');
  }

  /// Admin Manual Payout Override (The Backup System)
  /// Records that the Client paid offline and updates the Virtual Wallet.
  Future<Map<String, dynamic>> recordManualPayment({
    required String taskId,
    required String type, // 'advance' or 'final'
    required String note, // Transaction reference number
  }) async {
    final res = await _client.post(
      _buildUri('/tasks/$taskId/record-manual-payment'),
      headers: _headers,
      body: jsonEncode({
        'type': type,
        'note': note,
      }),
    );

    return _parseMapResponse(res, 'Failed to record manual payment');
  }

  /// Fetch payments requiring verification (awaiting advance or final approval)
  Future<List<Map<String, dynamic>>> getPendingPayments() async {
    final res = await _client.get(
      _buildUri('/getPendingPayments'),
      headers: _headers,
    );

    return _parseListResponse(res, 'Failed to load pending payments');
  }

  /// Final step: Moves money from SKILEN account to Student virtual wallet
  Future<void> releasePayment(String paymentId) async {
    final res = await _client.post(
      _buildUri('/releasePayment/$paymentId'),
      headers: _headers,
    );

    _ensureSuccess(res, 'Failed to release payment');
  }

  // ============================================================
  // ANALYTICS (RESTORED 100%)
  // ============================================================

  Future<Map<String, dynamic>> getTaskStats() async {
    final res = await _client.get(
      _buildUri('/getTaskStats'),
      headers: _headers,
    );

    return _parseMapResponse(res, 'Failed to load task stats');
  }

  Future<List<Map<String, dynamic>>> getTopStudents({int limit = 10}) async {
    final safeLimit = limit <= 0 ? 10 : limit;

    final res = await _client.get(
      _buildUri('/getTopStudents', {'limit': '$safeLimit'}),
      headers: _headers,
    );

    return _parseListResponse(res, 'Failed to load top students');
  }

  void dispose() {
    _client.close();
  }
}