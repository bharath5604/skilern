import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../env.dart';

class AdminService {
  AdminService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final String baseUrl = '${Env.apiBaseUrl}/api/admin';
  static const Duration _timeout = Duration(seconds: 25);

  // =========================================================
  // HELPERS (RESTORED & OPTIMIZED)
  // =========================================================

  Map<String, String> _headers() {
    final token = AuthService.token;
    if (token == null || token.isEmpty) {
      throw Exception('Admin token missing. Please login again.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _buildUri(String path, [Map<String, String>? params]) {
    final String cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath').replace(
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
      final msg = body['message'] ?? body['error'] ?? body['details'] ?? 'Request failed ($statusCode)';
      if (msg is List) return msg.map((e) => e.toString()).join(', ');
      return msg.toString();
    }
    return 'Request failed ($statusCode)';
  }

  Future<dynamic> _getRequest(Uri uri) async {
    try {
      final res = await _client.get(uri, headers: _headers()).timeout(_timeout);
      final body = _decodeResponse(res);
      if (res.statusCode >= 200 && res.statusCode < 300) return body;
      throw Exception(_extractErrorMessage(body, res.statusCode));
    } catch (e) { rethrow; }
  }

  Future<dynamic> _postRequest(Uri uri, {Map<String, dynamic>? body}) async {
    try {
      final res = await _client.post(
        uri, 
        headers: _headers(), 
        body: body != null ? jsonEncode(body) : null
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode >= 200 && res.statusCode < 300) return data;
      throw Exception(_extractErrorMessage(data, res.statusCode));
    } catch (e) { rethrow; }
  }

  Future<dynamic> _patchRequest(Uri uri, {Map<String, dynamic>? body}) async {
    try {
      final res = await _client.patch(
        uri, 
        headers: _headers(), 
        body: body != null ? jsonEncode(body) : null
      ).timeout(_timeout);
      final data = _decodeResponse(res);
      if (res.statusCode >= 200 && res.statusCode < 300) return data;
      throw Exception(_extractErrorMessage(data, res.statusCode));
    } catch (e) { rethrow; }
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, val) => MapEntry(key.toString(), val));
    throw Exception('Unexpected response format');
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic data) {
    if (data is List) return data.map<Map<String, dynamic>>(_normalizeMap).toList();
    if (data is Map && data.containsKey('data') && data['data'] is List) {
       return (data['data'] as List).map<Map<String, dynamic>>(_normalizeMap).toList();
    }
    return [];
  }

  // =========================================================
  // USER MANAGEMENT
  // =========================================================

  Future<List<Map<String, dynamic>>> getUsers({
    String? role,
    String? location,
    String? company,
    String? domain,
  }) async {
    final Map<String, String> params = {};
    if (role != null && role != 'All') params['role'] = role;
    if (location != null && location.isNotEmpty) params['location'] = location;
    if (company != null && company.isNotEmpty) params['company'] = company;
    if (domain != null && domain.isNotEmpty) params['domain'] = domain;

    final uri = _buildUri('/users', params);
    final data = await _getRequest(uri);
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> updateUserApproval(String userId, bool isApproved) async {
    final uri = _buildUri('/users/$userId/approve');
    final data = await _patchRequest(uri, body: {'isApproved': isApproved});
    return _normalizeMap(data);
  }

  // =========================================================
  // TASK REGISTRY & CANDIDATE VETTING
  // =========================================================

  Future<List<Map<String, dynamic>>> getTasks({String? location, String? domain, String? status}) async {
    final Map<String, String> params = {};
    if (location != null && location.isNotEmpty) params['location'] = location;
    if (domain != null && domain.isNotEmpty) params['domain'] = domain;
    if (status != null && status.isNotEmpty) params['status'] = status;

    final uri = _buildUri('/tasks', params);
    final data = await _getRequest(uri);
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> getTaskById(String taskId) async {
    final uri = _buildUri('/tasks/$taskId');
    return _normalizeMap(await _getRequest(uri));
  }

  Future<Map<String, List<String>>> getStudentFilters() async {
    final data = await _getRequest(_buildUri('/student-filters'));
    return {
      'locations': List<String>.from(data['locations'] ?? []),
      'skills': List<String>.from(data['skills'] ?? []),
    };
  }

  Future<List<Map<String, dynamic>>> getSuggestedStudentsForTask(
    String taskId, {String? skill, String? location}
  ) async {
    final Map<String, String> params = {};
    if (skill != null && skill.isNotEmpty) params['skill'] = skill;
    if (location != null && location.isNotEmpty) params['location'] = location;

    final uri = _buildUri('/tasks/$taskId/candidates', params);
    final data = await _getRequest(uri);
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> getStudentDetails(String studentId) async {
    final uri = _buildUri('/students/$studentId');
    final data = await _getRequest(uri);
    return _normalizeMap(data);
  }

  Future<Map<String, dynamic>> assignTaskToStudent({required String taskId, required String studentId}) async {
    final uri = _buildUri('/tasks/$taskId/assign');
    final data = await _postRequest(uri, body: {'studentId': studentId});
    return _normalizeMap(data);
  }

  Future<Map<String, dynamic>> toggleSubmissionVisibility(String taskId, bool canView) async {
    final uri = _buildUri('/tasks/$taskId/visibility');
    final data = await _patchRequest(uri, body: {'canView': canView});
    return _normalizeMap(data);
  }

  Future<Map<String, dynamic>> getTaskFilters() async {
    final uri = _buildUri('/tasks/filters');
    final data = await _getRequest(uri);
    return _normalizeMap(data);
  }

  // =========================================================
  // MODIFICATION: DUAL FINALIZE LOGIC (CLIENT vs STUDENT)
  // =========================================================

  /// Admin sets the final price the Client pays vs the Student receives.
  /// Hits PATCH /api/admin/tasks/:taskId/finalize-budget
  Future<Map<String, dynamic>> finalizeBudget({
    required String taskId, 
    required double clientAmount,   // Amount charged to the Client
    required double studentAmount,  // Amount to be paid to the Student
  }) async {
    final uri = _buildUri('/tasks/$taskId/finalize-budget');
    
    // Logic: Send both fields to the backend to resolve the privacy split
    final data = await _patchRequest(uri, body: {
      'clientBudget': clientAmount,
      'studentPayout': studentAmount
    });
    
    return _normalizeMap(data);
  }

  // =========================================================
  // MANUAL PAYMENT CHAIN ACTIONS
  // =========================================================

  Future<Map<String, dynamic>> confirmClientPayment(String taskId) async {
    final uri = _buildUri('/tasks/$taskId/confirm-client-payment');
    return _normalizeMap(await _patchRequest(uri));
  }

  Future<Map<String, dynamic>> confirmStudentPayout(String taskId) async {
    final uri = _buildUri('/tasks/$taskId/confirm-student-payout');
    return _normalizeMap(await _patchRequest(uri));
  }

  // =========================================================
  // ANALYTICS & DASHBOARD
  // =========================================================

  Future<Map<String, dynamic>> getOverviewStats() async {
    final uri = _buildUri('/stats/overview');
    final data = await _getRequest(uri);
    return _normalizeMap(data);
  }

  Future<Map<String, dynamic>> getTaskStats() async {
    final uri = _buildUri('/getTaskStats');
    final data = await _getRequest(uri);
    return _normalizeMap(data);
  }

  Future<List<Map<String, dynamic>>> getTopStudents() async {
    final uri = _buildUri('/getTopStudents');
    final data = await _getRequest(uri);
    return _asListOfMap(data);
  }

  Future<List<Map<String, dynamic>>> getGrowthStats({required String metric}) async {
    final uri = _buildUri('/stats/growth', {'metric': metric});
    final data = await _getRequest(uri);
    return _asListOfMap(data);
  }

  // =========================================================
  // MODERATED MESSAGING (ADMIN CONTEXT)
  // =========================================================

  Future<List<Map<String, dynamic>>> getClientTaskMessages(String taskId) async {
    final uri = _buildUri('/tasks/$taskId/chat/client/messages');
    final data = await _getRequest(uri);
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> sendClientTaskMessage({required String taskId, required String message}) async {
    final uri = _buildUri('/tasks/$taskId/chat/client/messages');
    return _normalizeMap(await _postRequest(uri, body: {'text': message}));
  }

  Future<List<Map<String, dynamic>>> getStudentTaskMessages({required String taskId, required String studentId}) async {
    final uri = _buildUri('/tasks/$taskId/chat/student/messages', {'studentId': studentId});
    final data = await _getRequest(uri);
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> sendStudentTaskMessage({required String taskId, required String studentId, required String message}) async {
    final uri = _buildUri('/tasks/$taskId/chat/student/messages');
    return _normalizeMap(await _postRequest(uri, body: {'text': message, 'studentId': studentId}));
  }

  void dispose() => _client.close();
}