// lib/services/file_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../env.dart';

class FileService {
  /// Uploads a file to the VPS Secure Vault.
  /// [file] can be a File object (Mobile) or PlatformFile (Web).
  /// Returns the PROTECTED URL that requires a JWT to view.
  static Future<String> uploadToVault(dynamic file, String fileName) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/api/files/upload');
    
    // 1. Create a Multipart Request
    var request = http.MultipartRequest('POST', uri);

    // 2. Attach Authorization Header (The Security Token)
    final token = AuthService.token;
    if (token == null) throw Exception("Authentication required for upload.");
    request.headers['Authorization'] = 'Bearer $token';

    // 3. Attach the File Bits
    try {
      if (kIsWeb) {
        // For Web: We must use the bytes from the PlatformFile
        if (file.bytes == null) throw Exception("File data is empty");
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes,
          filename: fileName,
        ));
      } else {
        // For Mobile: We use the file path
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
        ));
      }

      // 4. Execute the Upload
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Logic: The backend returns the unique filename (e.g. vault-123.pdf)
        // We construct the protected viewing URL.
        final String savedFilename = data['filename'];
        return '${Env.apiBaseUrl}/api/files/view/$savedFilename';
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('VPS Connection Error: $e');
    }
  }

  /// Helper to check if a URL is a VPS Vault URL
  static bool isVaultUrl(String url) {
    return url.contains('/api/files/view/');
  }
}