import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../services/auth_service.dart';

/// A secure, in-app media player that supports PDF, Images, and Video.
/// MODIFIED: Supports Authenticated Handshake for VPS Private Storage.
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
  
  Uint8List? _fileBytes; // Logic: Store downloaded secure bytes
  bool _isVideo = false;
  bool _isPdf = false;
  bool _isLoading = true;
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
      } else {
        if (path.contains('.pdf')) {
          _isPdf = true;
        }
        // Logic: For Images and PDFs, we must download bytes using the JWT header
        await _fetchFileWithSecurityToken();
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

  /// MODIFICATION: Authenticated HTTP GET request for Private Storage
  Future<void> _fetchFileWithSecurityToken() async {
    final String? token = AuthService.token;
    
    if (token == null || token.isEmpty) {
      throw Exception("Unauthorized: No security token found.");
    }

    final response = await http.get(
      Uri.parse(widget.url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/octet-stream',
      },
    );

    if (response.statusCode == 200) {
      _fileBytes = response.bodyBytes;
    } else if (response.statusCode == 403) {
      throw Exception("Access Denied: You are not authorized for this deliverable.");
    } else {
      throw Exception("Server Error (${response.statusCode})");
    }
  }

  /// MODIFICATION: Passing headers to the Video Network Streamer
  Future<void> _initializeSecureVideo() async {
    final String? token = AuthService.token;

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        // Logic: Pass security token so VPS allows the stream
        httpHeaders: {
          'Authorization': 'Bearer ${token ?? ""}',
        },
      );
      
      await _videoPlayerController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6A11CB),
          handleColor: const Color(0xFF2575FC),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white.withOpacity(0.5),
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
        showOptions: false, // Security: Disable the built-in download button
      );
    } catch (e) {
      throw Exception("Streaming failed: $e");
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
    return Scaffold(
      backgroundColor: _isVideo ? Colors.black : const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)))
          : _errorMessage != null
              ? _buildErrorView(_errorMessage!)
              : _buildViewer(),
    );
  }

  Widget _buildViewer() {
    if (_isPdf && _fileBytes != null) {
      // Logic: Show PDF from memory instead of network
      return SfPdfViewer.memory(
        _fileBytes!,
        onDocumentLoadFailed: (details) {
          _showSnackBar("Failed to render PDF data.");
        },
      );
    } 
    
    if (_isVideo) {
      if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
        return Center(
          child: Chewie(controller: _chewieController!),
        );
      } else {
        return const Center(
          child: Text("Unable to stream secure video", style: TextStyle(color: Colors.white)),
        );
      }
    }

    // DEFAULT: IMAGE VIEWER WITH SECURE MEMORY DATA
    if (_fileBytes != null) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            _fileBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined, size: 50, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("File data is corrupt or invalid", style: TextStyle(color: Colors.grey)),
                ],
              );
            },
          ),
        ),
      );
    }

    return _buildErrorView("Unsupported file or access denied.");
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_outlined, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Go Back"),
            )
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}