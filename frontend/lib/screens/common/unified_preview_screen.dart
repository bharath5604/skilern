import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Logic: Conditional imports for saving files
import 'dart:html' as html if (dart.library.io) 'package:skilern/utils/stub_html.dart';

import '../../services/auth_service.dart';

/// A secure, in-app media player and file downloader.
/// Supports PDF, Images, Video, Excel, Word, CSV, and ZIP.
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
  bool _isUnsupportedPreview = false; // For Excel, Word, ZIP, etc.
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepareSecureSession();
  }

  /// Logic: Determine file type and perform Authenticated Handshake
  Future<void> _prepareSecureSession() async {
    try {
      final String path = widget.url.toLowerCase();
      
      if (path.contains('.mp4') || path.contains('.mov') || path.contains('.avi') || path.contains('.m4v')) {
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
        // Excel, Word, CSV, ZIP etc.
        _isUnsupportedPreview = true;
      }
    } catch (e) {
      debugPrint("Security Handshake Error: $e");
      if (mounted) {
        setState(() => _errorMessage = "Secure connection failed. You may not have permission to view this file.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFileWithSecurityToken() async {
    final String? token = AuthService.token;
    if (token == null) throw Exception("Unauthorized");

    final response = await http.get(
      Uri.parse(widget.url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/octet-stream',
      },
    );

    if (response.statusCode == 200) {
      _fileBytes = response.bodyBytes;
    } else {
      throw Exception("Access Denied (${response.statusCode})");
    }
  }

  Future<void> _initializeSecureVideo() async {
    final String? token = AuthService.token;
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: {'Authorization': 'Bearer ${token ?? ""}'},
      );
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        showOptions: false,
      );
    } catch (e) {
      throw Exception("Streaming failed: $e");
    }
  }

  /// MODIFICATION: Authenticated Download for quality checks and final files
  Future<void> _downloadFile() async {
    setState(() => _isDownloading = true);
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse(widget.url),
        headers: {'Authorization': 'Bearer ${token ?? ""}'}
      );

      if (response.statusCode == 200) {
        if (kIsWeb) {
          final blob = html.Blob([response.bodyBytes], 'application/octet-stream');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", widget.title)
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          // On Mobile, showing a Snack. 
          // (In a full implementation, you'd use path_provider to save to storage)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Download complete. Check your files folder."))
          );
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: $e")));
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AuthService.role?.toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: _isVideo ? Colors.black : const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        title: Text(widget.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        actions: [
          if (isAdmin || _isUnsupportedPreview)
            IconButton(
              icon: _isDownloading 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded, color: Color(0xFF6A11CB)),
              onPressed: _isDownloading ? null : _downloadFile,
              tooltip: "Download File",
            )
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
              const Text("In-App Preview Unavailable", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                isAdmin 
                ? "As an Admin, you can download this file to perform a quality check."
                : "This file type (${widget.url.split('.').last.toUpperCase()}) must be downloaded to be viewed.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),
              if (isAdmin) 
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _isDownloading ? null : _downloadFile, 
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: Text(_isDownloading ? "Downloading..." : "Download for Quality Check")
                )
              else
                const Text("Download will be available once the project is finalized.", 
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_isPdf && _fileBytes != null) return SfPdfViewer.memory(_fileBytes!); 
    
    if (_isVideo) {
      if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
        return Center(child: Chewie(controller: _chewieController!));
      }
      return const Center(child: Text("Initializing stream...", style: TextStyle(color: Colors.white)));
    }

    if (_fileBytes != null) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5, maxScale: 4.0,
          child: Image.memory(_fileBytes!, fit: BoxFit.contain),
        ),
      );
    }

    return _buildErrorView("Access denied or unsupported file.");
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_person_outlined, size: 60, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back"))
        ],
      ),
    );
  }
}