import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Logic: Conditional imports for cross-platform file saving
import 'dart:html' as html if (dart.library.io) 'package:skilern/utils/stub_html.dart';

import '../../services/auth_service.dart';

/// A secure, authenticated media player and file downloader.
/// Supports PDF, Images, Video, and Quality Check downloads for Excel, Word, and ZIP.
class UnifiedPreviewScreen extends StatefulWidget {
  final String url;
  final String title;

  const UnifiedPreviewScreen({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  State<UnifiedPreviewScreen> createState() => _UnifiedPreviewScreenState();
}

class _UnifiedPreviewScreenState extends State<UnifiedPreviewScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  Uint8List? _fileBytes; 
  bool _isVideo = false;
  bool _isPdf = false;
  bool _isUnsupportedPreview = false; 
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepareSecureSession();
  }

  /// Logic: Determine file type and perform Authenticated Handshake with the VPS Vault
  Future<void> _prepareSecureSession() async {
    try {
      final String path = widget.url.toLowerCase();
      
      // 1. Identify File Category with robust extension checking
      if (path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi') || path.contains('.m4v')) {
        _isVideo = true;
        await _initializeSecureVideo();
      } 
      else if (path.contains('.pdf')) {
        _isPdf = true;
        await _fetchFileWithSecurityToken();
      }
      else if (path.contains('.jpg') || path.contains('.jpeg') || path.contains('.png') || path.contains('.gif') || path.contains('.webp')) {
        await _fetchFileWithSecurityToken();
      }
      else {
        // Handle Excel, Word, CSV, ZIP, etc.
        _isUnsupportedPreview = true;
      }
    } catch (e) {
      debugPrint("Security Handshake Error: $e");
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// MODIFICATION: Clean Token logic to prevent "Authorization Missing" errors
  Map<String, String> _getAuthenticatedHeaders() {
    String? rawToken = AuthService.token;
    if (rawToken == null || rawToken.isEmpty) return {};

    // Remove any existing Bearer prefix to prevent "Bearer Bearer" errors on VPS
    final String cleanToken = rawToken.startsWith('Bearer ') 
        ? rawToken.replaceFirst('Bearer ', '').trim() 
        : rawToken.trim();

    return {
      'Authorization': 'Bearer $cleanToken',
      'Accept': '*/*', 
    };
  }

  /// Logic: Standard HTTP fetch for binary data (Images/PDF)
  Future<void> _fetchFileWithSecurityToken() async {
    final headers = _getAuthenticatedHeaders();
    if (headers.isEmpty) throw Exception("Session expired. Please login again.");

    final response = await http.get(Uri.parse(widget.url), headers: headers);

    if (response.statusCode == 200) {
      // Logic Check: Did the server return an error JSON instead of the file?
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        final decoded = jsonDecode(response.body);
        throw Exception(decoded['message'] ?? "Access Denied");
      }
      
      // Successfully received bytes
      if (mounted) {
        setState(() {
          _fileBytes = response.bodyBytes;
        });
      }
    } else {
      throw Exception("VPS Access Denied (${response.statusCode})");
    }
  }

  /// Logic: Setup streaming headers for the video player
  Future<void> _initializeSecureVideo() async {
    try {
      final headers = _getAuthenticatedHeaders();
      
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: headers,
      );
      
      await _videoPlayerController!.initialize();
      
      if (mounted) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: true,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            placeholder: Container(color: Colors.black),
            showOptions: false,
          );
        });
      }
    } catch (e) {
      throw Exception("Secure video stream failed. Check permissions.");
    }
  }

  /// MODIFICATION: Secure Download Handler (Used by Client and Admin Quality Check)
  Future<void> _downloadFile() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final headers = _getAuthenticatedHeaders();
      final response = await http.get(Uri.parse(widget.url), headers: headers);

      if (response.statusCode == 200) {
        if (kIsWeb) {
          final blob = html.Blob([response.bodyBytes], 'application/octet-stream');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", widget.title) // Ensures correct extension (.xlsx, .pdf, etc.)
            ..click();
          html.Url.revokeObjectUrl(url);
          _showSnack("Saved: ${widget.title}");
        } else {
          _showSnack("File retrieved successfully.");
        }
      } else {
        throw Exception("Server rejected secure download.");
      }
    } catch (e) {
      _showSnack("Download failed: $e");
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _showSnack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AuthService.role?.toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: _isVideo ? Colors.black : const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text(widget.title, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
        actions: [
          // Quality check icon for Admin, or download icon for unlocked files
          if (isAdmin || _isUnsupportedPreview)
            IconButton(
              icon: _isDownloading 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6A11CB)))
                : const Icon(Icons.download_for_offline_rounded, color: Color(0xFF6A11CB)),
              onPressed: _isDownloading ? null : _downloadFile,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)))
          : _errorMessage != null
              ? _buildErrorView(_errorMessage!)
              : _buildViewer(isAdmin),
    );
  }

  Widget _buildViewer(bool isAdmin) {
    if (_isUnsupportedPreview) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text("Preview Unavailable", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                isAdmin 
                ? "As an Admin, please download this file to perform a quality check."
                : "This file type must be downloaded to be viewed correctly.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),
              if (isAdmin) 
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: _isDownloading ? null : _downloadFile, 
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: Text(_isDownloading ? "Retrieving..." : "Download & Review Work")
                ),
            ],
          ),
        ),
      );
    }

    // FIXED PDF VIEWER: Using Key + Memory Check + setState bytes
    if (_isPdf && _fileBytes != null && _fileBytes!.isNotEmpty) {
      return SfPdfViewer.memory(
        _fileBytes!,
        key: ValueKey(widget.url), // Forces refresh when bytes are set
        onDocumentLoadFailed: (details) {
          if(mounted) setState(() => _errorMessage = "PDF Rendering Failed: ${details.description}");
        },
      ); 
    } 
    
    if (_isVideo) {
      if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
        return Center(child: Chewie(controller: _chewieController!));
      }
      return const Center(child: Text("Preparing secure stream...", style: TextStyle(color: Colors.white)));
    }

    if (_fileBytes != null) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5, maxScale: 4.0,
          child: Image.memory(_fileBytes!, fit: BoxFit.contain),
        ),
      );
    }

    return _buildErrorView("No renderable content found.");
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_clock_rounded, size: 60, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back"))
        ],
      ),
    );
  }
}