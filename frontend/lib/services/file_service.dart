// lib/services/file_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../env.dart';

class FileService {
  /// Standard Upload: Used for task deliverables and profile updates.
  /// Requires a valid Security Token (JWT).
  static Future<String> uploadToVault(dynamic file, String fileName) async {
    final token = AuthService.token;
    
    // Logic: Force a check for the token to prevent accidental public uploads
    if (token == null || token.trim().isEmpty) {
      throw Exception("Authentication required for project uploads.");
    }
    
    return _performUpload(
      file: file, 
      fileName: fileName, 
      path: '/api/files/upload', 
      token: token
    );
  }

  /// MODIFICATION: Signup Upload. 
  /// Specifically for Student ID cards during the registration phase.
  /// Does NOT require a token.
  static Future<String> uploadRegistrationFile(dynamic file, String fileName) async {
    return _performUpload(
      file: file, 
      fileName: fileName, 
      path: '/api/files/upload-registration', 
      token: null // No token sent for public registration endpoint
    );
  }

  /// Core logic to handle the multi-part request to the VPS Secure Vault.
  /// Handles both Web (bytes) and Mobile (filepath) logic automatically.
  static Future<String> _performUpload({
    required dynamic file, 
    required String fileName, 
    required String path, 
    String? token
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}$path');
    var request = http.MultipartRequest('POST', uri);

    // Attach Authorization Header if a token is provided
    if (token != null) {
      request.headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    try {
      // Logic: Platform-specific file attachment
      if (kIsWeb) {
        // Web: Use bytes from PlatformFile
        if (file.bytes == null) throw Exception("File data is empty");
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes,
          filename: fileName,
        ));
      } else {
        // Mobile: Use system file path
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
        ));
      }

      // Execute the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Logic: Return the internal VPS route used for authenticated viewing
        final String savedFilename = data['filename'];
        return '${Env.apiBaseUrl}/api/files/view/$savedFilename';
      } else {
        // Extract server-side error if available
        final errorMsg = _tryParseError(response.body);
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('VPS Storage Error: $e');
    }
  }

  /// Helper to extract clean error messages from backend JSON
  static String _tryParseError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['message'] ?? decoded['error'] ?? 'Server Error';
    } catch (_) {
      return 'Upload failed (Status Code error)';
    }
  }

  /// Utility to check if a URL belongs to the Skilern Secure Vault
  static bool isVaultUrl(String url) {
    return url.contains('/api/files/view/');
  }
}