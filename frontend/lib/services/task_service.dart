import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import 'auth_service.dart';
import '../env.dart';

class TaskService {
  TaskService({http.Client? client}) : client = client ?? http.Client();

  final String baseUrl = '${Env.apiBaseUrl}/api/tasks';
  final String adminUrl = '${Env.apiBaseUrl}/api/admin/tasks';
  final http.Client client;

  static const Duration timeout = Duration(seconds: 25);

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (AuthService.token != null && AuthService.token!.trim().isNotEmpty)
          'Authorization': 'Bearer ${AuthService.token}',
      };

  // ============================================================
  // HELPERS
  // ============================================================

  String extractErrorMessage(http.Response res, {String? fallback}) {
    final body = res.body.trim();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message'] ?? decoded['error'] ?? decoded['details'];
          if (message != null) return message.toString();
        }
      } catch (_) {
        if (body.startsWith('<!DOCTYPE html')) return 'Server error (${res.statusCode})';
        return body;
      }
    }
    return fallback ?? 'Request failed (${res.statusCode})';
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

  List<Task> handleTaskListResponse(http.Response res, {String err = 'Failed to load tasks'}) {
    if (res.statusCode != 200) throw Exception(extractErrorMessage(res, fallback: err));
    final decoded = _decodeBody(res);
    if (decoded is! List) throw Exception('Invalid response format');
    return decoded.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> handleMapResponse(http.Response res, {String err = 'Request failed'}) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(extractErrorMessage(res, fallback: err));
    }
    final decoded = _decodeBody(res);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'success': true};
  }

  // ============================================================
  // CLIENT & GUEST ENDPOINTS
  // ============================================================

  /// Fetches unique domains from DB to allow propagation of custom domains
  Future<List<String>> getExistingDomains() async {
    try {
      final res = await client.get(
        Uri.parse('$baseUrl/filters'), 
        headers: headers
      ).timeout(timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data.containsKey('domains')) {
          return List<String>.from(data['domains']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching existing domains: $e');
      return [];
    }
  }

  /// MODIFICATION: Removed 'budget' parameter.
  Future<Map<String, dynamic>> createTask({
    required String title,
    required String description,
    required String deadline,
    required bool acceptedTerms,
    String? location,
    String? domain,
    List<String>? requiredSkills,
    String? company,
    List<String>? attachments,
    List<String>? attachmentNames,
  }) async {
    final body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'deadline': deadline,
      'clientAgreedToTerms': acceptedTerms,
      if (location != null) 'location': location.trim(),
      if (domain != null) 'domain': domain.trim(),
      if (requiredSkills != null) 'requiredSkills': requiredSkills,
      if (company != null) 'company': company.trim(),
      if (attachments != null) 'attachments': attachments,
      if (attachmentNames != null) 'attachmentNames': attachmentNames,
    };

    final res = await client.post(
      Uri.parse('$baseUrl/create'), 
      headers: headers, 
      body: jsonEncode(body)
    ).timeout(timeout);
    
    return handleMapResponse(res, err: 'Task creation failed');
  }

  /// MODIFICATION: Removed 'budget' parameter.
  Future<Map<String, dynamic>> createGuestTask({
    required String title,
    required String description,
    required String guestName,
    required String guestMobile,
    String? guestEmail,
    required String deadline,
    String? domain,
    List<String>? requiredSkills,
  }) async {
    final body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'guestName': guestName.trim(),
      'guestMobile': guestMobile.trim(),
      if (guestEmail != null) 'guestEmail': guestEmail.trim(),
      'deadline': deadline,
      'domain': domain ?? 'General',
      if (requiredSkills != null) 'requiredSkills': requiredSkills,
    };

    final res = await client.post(
      Uri.parse('$baseUrl/guest-create'), 
      headers: {'Content-Type': 'application/json'}, 
      body: jsonEncode(body)
    ).timeout(timeout);
    
    return handleMapResponse(res, err: 'Emergency task submission failed');
  }

  Future<List<Task>> getMyTasks() async {
    final res = await client.get(Uri.parse('$baseUrl/mine'), headers: headers).timeout(timeout);
    return handleTaskListResponse(res);
  }

  /// MODIFICATION: Removed 'budget' parameter.
  Future<Map<String, dynamic>> updateTask({
    required String taskId,
    required String title,
    required String description,
    required String deadline,
    String? location,
    String? domain,
    List<String>? requiredSkills,
    List<String>? attachments,
    List<String>? attachmentNames,
  }) async {
    final body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'deadline': deadline,
      if (location != null) 'location': location.trim(),
      if (domain != null) 'domain': domain.trim(),
      if (requiredSkills != null) 'requiredSkills': requiredSkills,
      if (attachments != null) 'attachments': attachments,
      if (attachmentNames != null) 'attachmentNames': attachmentNames,
    };

    final res = await client.post(
      Uri.parse('$baseUrl/$taskId/update'), 
      headers: headers, 
      body: jsonEncode(body)
    ).timeout(timeout);
    
    return handleMapResponse(res, err: 'Task update failed');
  }

  Future<void> deleteTask(String taskId) async {
    final res = await client.delete(Uri.parse('$baseUrl/$taskId'), headers: headers).timeout(timeout);
    if (res.statusCode != 200) throw Exception(extractErrorMessage(res));
  }

  // ============================================================
  // ADMIN CONTROL ENDPOINTS
  // ============================================================

  Future<Map<String, dynamic>> toggleSubmissionVisibility(String taskId, bool canView) async {
    final res = await client.patch(
      Uri.parse('$adminUrl/$taskId/visibility'),
      headers: headers,
      body: jsonEncode({'canView': canView}),
    ).timeout(timeout);
    
    return handleMapResponse(res);
  }

  Future<List<dynamic>> getTaskCandidates(String taskId, {String? skill, String? location}) async {
    final query = <String, String>{
      if (skill != null && skill.isNotEmpty) 'skill': skill,
      if (location != null && location.isNotEmpty) 'location': location,
    };
    
    final uri = Uri.parse('$adminUrl/$taskId/candidates').replace(
      queryParameters: query.isEmpty ? null : query
    );
    
    final res = await client.get(uri, headers: headers).timeout(timeout);
    if (res.statusCode != 200) throw Exception(extractErrorMessage(res));
    return _decodeBody(res) as List;
  }

  Future<Map<String, dynamic>> sendAssignmentRequest({required String taskId, required String studentId}) async {
    final res = await client.post(
      Uri.parse('$adminUrl/$taskId/assign'), 
      headers: headers, 
      body: jsonEncode({'studentId': studentId})
    ).timeout(timeout);
    
    return handleMapResponse(res, err: 'Failed to send invitation');
  }

  // ============================================================
  // STUDENT WORKFLOW ENDPOINTS
  // ============================================================

  Future<List<Task>> getAssignmentRequests() async {
    final res = await client.get(Uri.parse('$baseUrl/requests'), headers: headers).timeout(timeout);
    return handleTaskListResponse(res);
  }

  Future<Map<String, dynamic>> acceptAssignmentRequest({required String taskId, required bool acceptedTerms}) async {
    final res = await client.post(
      Uri.parse('$baseUrl/$taskId/accept-request'), 
      headers: headers, 
      body: jsonEncode({'studentAgreedToTerms': acceptedTerms})
    ).timeout(timeout);
    
    return handleMapResponse(res, err: 'Acceptance failed');
  }

  Future<List<Task>> getAssignedTasks() async {
    final res = await client.get(Uri.parse('$baseUrl/assigned'), headers: headers).timeout(timeout);
    return handleTaskListResponse(res);
  }

  // ============================================================
  // MODIFICATION: MULTI-FILE SUBMISSION
  // ============================================================
  Future<Map<String, dynamic>> submitWork({
    required String taskId, 
    required List<Map<String, String>> files, 
    String? notes
  }) async {
    final res = await client.post(
      Uri.parse('$baseUrl/$taskId/submit'), 
      headers: headers, 
      body: jsonEncode({
        'files': files, // Sending the full list of deliverables
        if (notes != null) 'notes': notes
      }),
    ).timeout(timeout);
    
    return handleMapResponse(res, err: 'Submission failed');
  }

  // ============================================================
  // FEEDBACK & MESSAGING SYNC
  // ============================================================

  Future<Map<String, dynamic>> approveSubmittedTask({required String taskId}) async {
    final res = await client.post(Uri.parse('$baseUrl/$taskId/approve'), headers: headers).timeout(timeout);
    return handleMapResponse(res, err: 'Approval failed');
  }

  Future<Map<String, dynamic>> requestRevision({required String taskId, required String reason}) async {
    final res = await client.post(
      Uri.parse('$baseUrl/$taskId/decline'), 
      headers: headers, 
      body: jsonEncode({'reason': reason.trim()})
    ).timeout(timeout);
    
    return handleMapResponse(res, err: 'Revision request failed');
  }

  Future<Map<String, dynamic>> sendFeedback({required String taskId, required String text, required int score}) async {
    final res = await client.post(
      Uri.parse('$baseUrl/$taskId/feedback'), 
      headers: headers, 
      body: jsonEncode({
        'feedback': text.trim(), 
        'score': score
      })
    ).timeout(timeout);
    
    return handleMapResponse(res);
  }

  Future<List<Task>> getChatTasksForStudent() async {
    final res = await client.get(Uri.parse('$baseUrl/chat-tasks'), headers: headers).timeout(timeout); 
    return handleTaskListResponse(res);
  }

  void dispose() => client.close();
}