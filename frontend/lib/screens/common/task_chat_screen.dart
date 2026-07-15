import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
// REMOVED: import 'package:firebase_storage/firebase_storage.dart' as fstorage; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/message_service.dart';
import '../../services/socketservice.dart';
import '../../services/file_service.dart'; // MODIFICATION: IMPORT VPS FILE SERVICE

/// Task-specific chat screen supporting dynamic real-time messaging
/// across Admin, Client, and Student roles with strict thread isolation.
class TaskChatScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String? peerStudentId;

  const TaskChatScreen({
    Key? key,
    required this.taskId,
    required this.taskTitle,
    this.peerStudentId,
  }) : super(key: key);

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final MessageService _service = MessageService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode(); 

  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _sending = false;
  bool _sendingFile = false;

  // Modern Purple Palette
  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color bg = Color(0xFFF5F7FB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color myBubble = Color(0xFF6A11CB);
  static const Color otherBubble = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // ============================================================
    // DYNAMIC REAL-TIME LOGIC (STRICT PRIVACY)
    // ============================================================
    SocketService.connect();
    
    String? currentThreadStudentId;
    final String? myRole = AuthService.role?.toLowerCase();

    if (myRole == 'student') {
      currentThreadStudentId = AuthService.userId;
    } else {
      currentThreadStudentId = widget.peerStudentId;
    }

    SocketService.joinTaskRoom(widget.taskId, studentId: currentThreadStudentId);

    SocketService.socket!.on('new_message', (data) {
      if (mounted) {
        final currentUserId = AuthService.userId;
        final newMessage = _safeMap(data);

        // --- THE LEAK PROTECTOR ---
        final String? msgStudentId = newMessage['student']?.toString();
        if (msgStudentId != currentThreadStudentId) {
          debugPrint("TaskChat: Blocked real-time message leak from another thread.");
          return; 
        }

        final senderRaw = newMessage['sender'];
        String? incomingSenderId;
        if (senderRaw is String) {
          incomingSenderId = senderRaw;
        } else if (senderRaw is Map) {
          incomingSenderId = senderRaw['_id']?.toString() ?? senderRaw['id']?.toString();
        }

        if (incomingSenderId != currentUserId) {
          setState(() {
            _messages.add(newMessage);
          });
          _scrollToBottom();
        }
      }
    });
  }

  @override
  void dispose() {
    SocketService.socket!.off('new_message');
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose(); 
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // STATE HELPERS
  // ---------------------------------------------------------------------------

  bool get _isAdmin => AuthService.role?.trim().toLowerCase() == 'admin';
  bool get _isAdminStudentThread => _isAdmin && widget.peerStudentId != null;
  bool get _isAdminClientThread => _isAdmin && widget.peerStudentId == null;

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _safeMessageList(dynamic value) {
    if (value is! List) return [];
    return value.map<Map<String, dynamic>>((item) => _safeMap(item)).toList();
  }

  // ---------------------------------------------------------------------------
  // DATA ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> res;
      if (_isAdminStudentThread) {
        res = await _service.getAdminStudentMessages(taskId: widget.taskId, studentId: widget.peerStudentId!.trim());
      } else if (_isAdminClientThread) {
        res = await _service.getAdminClientMessages(taskId: widget.taskId);
      } else {
        res = await _service.getTaskMessages(widget.taskId, studentId: widget.peerStudentId);
      }

      if (mounted) {
        setState(() => _messages = _safeMessageList(res));
        _scrollToBottom(animated: false);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to load chat history');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send({String? fileUrl, String? fileName}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && fileUrl == null) return;
    if (_sending) return;

    setState(() => _sending = true);
    try {
      Map<String, dynamic> msg;
      if (_isAdminStudentThread) {
        msg = await _service.sendAdminStudentMessage(taskId: widget.taskId, studentId: widget.peerStudentId ?? '', text: text, fileUrl: fileUrl, fileName: fileName);
      } else if (_isAdminClientThread) {
        msg = await _service.sendAdminClientMessage(taskId: widget.taskId, text: text, fileUrl: fileUrl, fileName: fileName);
      } else {
        msg = await _service.sendTaskMessage(widget.taskId, text, targetRole: 'admin', fileUrl: fileUrl, fileName: fileName, studentId: (AuthService.role?.toLowerCase() == 'student') ? AuthService.userId : null);
      }

      if (mounted) {
        setState(() => _messages.add(_safeMap(msg)));
        _controller.clear();
        _scrollToBottom();
        _inputFocusNode.requestFocus(); 
      }
    } catch (e) {
      _showSnackBar('Could not send message');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ============================================================
  // MODIFICATION: VPS SECURE FILE UPLOAD (Fixes CORS Net::ERR_FAILED)
  // ============================================================
  Future<void> _pickAndSendFile() async {
    try {
      setState(() => _sendingFile = true);
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);

      if (result == null || result.files.isEmpty) {
        setState(() => _sendingFile = false);
        return;
      }

      final picked = result.files.first;
      if (picked.size > 15 * 1024 * 1024) { 
        _showSnackBar('File too large (Max 15MB)');
        setState(() => _sendingFile = false);
        return;
      }

      // Logic: Hit the VPS Secure Vault instead of Firebase
      // This uses a standard HTTP Multipart request which bypasses CORS net errors.
      final String secureVpsUrl = await FileService.uploadToVault(picked, picked.name);

      // Construct and send the message with the VPS link
      await _send(fileUrl: secureVpsUrl, fileName: picked.name);

    } catch (e) {
      if (mounted) _showSnackBar('VPS Upload failed: $e');
    } finally {
      if (mounted) setState(() => _sendingFile = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI UTILITIES
  // ---------------------------------------------------------------------------

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(pos, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(pos);
      }
    });
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: primaryPurple, behavior: SnackBarBehavior.floating));
  
  String _formatTimestamp(dynamic r) {
    if (r == null) return '';
    final dt = DateTime.tryParse(r.toString())?.toLocal();
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  Future<void> _openAttachment(String u) async {
    final Uri uri = Uri.parse(u);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.userId;
    final displayTitle = widget.taskTitle.trim().isEmpty ? 'Task Chat' : widget.taskTitle.trim();

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(displayTitle),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: primaryPurple))
                  : _messages.isEmpty ? _buildEmptyState() : _buildMessageList(currentUserId),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String displayTitle) {
    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      iconTheme: const IconThemeData(color: primaryPurple),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryPurple.withOpacity(0.1), secondaryPurple.withOpacity(0.05)]), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.forum_rounded, color: primaryPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w700)),
                Text(_isAdminStudentThread ? 'Student thread' : (_isAdminClientThread ? 'Client thread' : 'Support chat'), style: const TextStyle(color: textMuted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
      actions: [IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _loadMessages, icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 4)],
    );
  }

  Widget _buildMessageList(String? currentUserId) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];
        final sender = _safeMap(m['sender']);
        
        String? senderId = (m['sender'] is String) ? m['sender'] : (sender['_id'] ?? sender['id'])?.toString();

        final bool isMe = senderId != null && currentUserId != null && senderId == currentUserId;
        final String name = (sender['name'] ?? (isMe ? 'You' : 'User')).toString();

        return _MessageBubble(
          isMe: isMe,
          name: name,
          text: (m['text'] ?? '').toString(),
          timestamp: _formatTimestamp(m['createdAt']),
          fileUrl: m['fileUrl']?.toString(),
          fileName: m['fileName']?.toString(),
          onAttachmentTap: m['fileUrl'] != null ? () => _openAttachment(m['fileUrl']) : null,
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: border))),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
              child: IconButton(
                onPressed: _sendingFile ? null : _pickAndSendFile,
                icon: _sendingFile ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryPurple)) : const Icon(Icons.attach_file_rounded, color: textMuted),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
                child: KeyboardListener(
                  focusNode: FocusNode(), 
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                      _send();
                    }
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocusNode, 
                    minLines: 1, 
                    maxLines: 4, 
                    textInputAction: TextInputAction.send, 
                    decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _sending ? null : () => _send(),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: _sending ? _TaskChatScreenState.primaryPurple.withOpacity(0.6) : _TaskChatScreenState.primaryPurple, borderRadius: BorderRadius.circular(18)),
                child: _sending ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No messages yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMuted)),
          const Text('Start the conversation!', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isMe; final String name, text, timestamp; final String? fileUrl, fileName; final VoidCallback? onAttachmentTap;
  const _MessageBubble({required this.isMe, required this.name, required this.text, required this.timestamp, this.fileUrl, this.fileName, this.onAttachmentTap});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? _TaskChatScreenState.myBubble : _TaskChatScreenState.otherBubble;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(radius: 14, backgroundColor: _TaskChatScreenState.primaryPurple.withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _TaskChatScreenState.primaryPurple))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 6), bottomRight: Radius.circular(isMe ? 6 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(isMe ? 'You' : name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMe ? Colors.white70 : _TaskChatScreenState.primaryPurple)),
                  if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, style: TextStyle(color: isMe ? Colors.white : _TaskChatScreenState.textDark, fontSize: 14))),
                  if (fileUrl != null) _AttachmentCard(isMe: isMe, fileName: fileName ?? 'File', onTap: onAttachmentTap ?? () {}),
                  const SizedBox(height: 4),
                  Text(timestamp, style: TextStyle(fontSize: 8, color: isMe ? Colors.white60 : _TaskChatScreenState.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  final bool isMe; final String fileName; final VoidCallback onTap;
  const _AttachmentCard({required this.isMe, required this.fileName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isMe ? Colors.white12 : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, size: 16, color: isMe ? Colors.white : _TaskChatScreenState.primaryPurple),
            const SizedBox(width: 8),
            Flexible(child: Text(fileName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isMe ? Colors.white : _TaskChatScreenState.textDark))),
          ],
        ),
      ),
    );
  }
}