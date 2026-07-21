import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/task_service.dart';
import '../../services/auth_service.dart'; 
import '../../services/socketservice.dart'; 
import '../../services/file_service.dart'; 
import '../../models/task.dart';
import '../common/unified_preview_screen.dart'; 
import 'student_main_shell.dart';

class StudentWorkspaceScreen extends StatefulWidget {
  const StudentWorkspaceScreen({Key? key}) : super(key: key);

  @override
  State<StudentWorkspaceScreen> createState() => _StudentWorkspaceScreenState();
}

class _StudentWorkspaceScreenState extends State<StudentWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  final TaskService _taskService = TaskService();

  bool _loading = false;
  List<Task> _tasks = [];
  List<Task> _invitations = [];
  late AnimationController _animationController;

  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color backgroundColor = Color(0xFFF5F7FB);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _initializeRealTimeAndData();
  }

  Future<void> _initializeRealTimeAndData() async {
    await _loadAllData();
    SocketService.connect();
    
    if (AuthService.userId != null) {
      SocketService.joinUserRoom(AuthService.userId!);
    }

    SocketService.on('task_request', (_) => _loadAllData(isSilent: true));
    SocketService.on('task_update', (_) => _loadAllData(isSilent: true));
    SocketService.on('task_assigned', (_) => _loadAllData(isSilent: true));
  }

  @override
  void dispose() {
    SocketService.off('task_request');
    SocketService.off('task_update');
    SocketService.off('task_assigned');
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) setState(() => _loading = true);
    
    try {
      final results = await Future.wait([
        _taskService.getAssignedTasks(),
        _taskService.getAssignmentRequests(),
      ]);

      if (!mounted) return;
      setState(() {
        _tasks = results[0];
        _invitations = results[1];
      });

      for (var t in _tasks) {
        if (t.id.isNotEmpty) SocketService.joinTaskRoom(t.id);
      }

      _animationController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to sync workspace');
    } finally {
      if (mounted && !isSilent) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: primaryPurple, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0.5,
        backgroundColor: Colors.white,
        title: const Text('My Workspace',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textDark)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAllData(isSilent: false),
        color: primaryPurple,
        child: _loading && _tasks.isEmpty && _invitations.isEmpty
            ? const Center(child: CircularProgressIndicator(color: primaryPurple))
            : FadeTransition(
                opacity: _animationController,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_invitations.isNotEmpty) ...[
                      _buildSectionHeader('Work Invitations', _invitations.length, Colors.blue),
                      const SizedBox(height: 10),
                      ..._invitations.map((t) => _InvitationCard(task: t, onAction: _loadAllData)),
                      const SizedBox(height: 24),
                    ],
                    _buildSectionHeader('Active Assignments', _tasks.length, primaryPurple),
                    const SizedBox(height: 10),
                    if (_tasks.isEmpty)
                      _buildEmptyState()
                    else
                      ..._tasks.map((t) => _WorkspaceTaskCard(task: t, onSubmitted: _loadAllData)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
        const Spacer(),
        Text('$count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: const Center(child: Text('No active projects', style: TextStyle(color: Colors.grey))),
    );
  }
}

class _InvitationCard extends StatefulWidget {
  final Task task;
  final Future<void> Function({bool isSilent}) onAction;
  const _InvitationCard({required this.task, required this.onAction});

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.blue, width: 0.5)),
      child: ListTile(
        title: Text(widget.task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("Budget: ₹${widget.task.studentPayout?.toStringAsFixed(0) ?? 'TBD'}", style: const TextStyle(fontSize: 11, color: Colors.blue)),
        trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          onPressed: _accept, child: const Text("Accept", style: TextStyle(fontSize: 11))
        ),
      ),
    );
  }

  Future<void> _accept() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Accept Task?"),
        content: const Text("By accepting, you agree to complete the work by the deadline."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Accept")),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _busy = true);
      try {
        await TaskService().acceptAssignmentRequest(taskId: widget.task.id, acceptedTerms: true);
        widget.onAction(isSilent: true);
      } finally { if (mounted) setState(() => _busy = false); }
    }
  }
}

class _WorkspaceTaskCard extends StatefulWidget {
  final Task task;
  final Future<void> Function({bool isSilent}) onSubmitted;
  const _WorkspaceTaskCard({required this.task, required this.onSubmitted});

  @override
  State<_WorkspaceTaskCard> createState() => _WorkspaceTaskCardState();
}

class _WorkspaceTaskCardState extends State<_WorkspaceTaskCard> {
  bool _uploading = false;

  Future<void> _submitWork() async {
    final noteCtrl = TextEditingController();
    List<Map<String, String>> stagedFiles = [];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Submit Deliverables"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_uploading) const CircularProgressIndicator()
                else ...[
                  if (stagedFiles.isNotEmpty)
                    ...stagedFiles.map((f) => ListTile(dense: true, title: Text(f['name']!, style: const TextStyle(fontSize: 12)))).toList(),
                  ElevatedButton(
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
                      if (res != null) {
                        setDialogState(() => _uploading = true);
                        try {
                          for (var f in res.files) {
                            final url = await FileService.uploadToVault(f, f.name);
                            stagedFiles.add({'url': url, 'name': f.name});
                          }
                        } finally { setDialogState(() => _uploading = false); }
                      }
                    },
                    child: const Text("Select Files"),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: noteCtrl, decoration: const InputDecoration(hintText: "Notes...")),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: stagedFiles.isEmpty ? null : () async {
                await TaskService().submitWork(taskId: widget.task.id, files: stagedFiles, notes: noteCtrl.text);
                Navigator.pop(ctx);
                widget.onSubmitted(isSilent: true);
              },
              child: const Text("Submit"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.task.status.toLowerCase();
    final canSubmit = status == 'assigned' || status == 'declined';
    final List<String> clientFiles = widget.task.attachments;
    final List<String> clientFileNames = widget.task.attachmentNames;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(widget.task.title, style: const TextStyle(fontWeight: FontWeight.bold))),
            Text("₹${widget.task.budget?.toStringAsFixed(0) ?? 'TBD'}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          
          // ============================================================
          // DISPLAY CLIENT ATTACHMENTS
          // ============================================================
          if (clientFiles.isNotEmpty) ...[
            const Text("CLIENT PROJECT ASSETS:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: List.generate(clientFiles.length, (index) {
                  final String name = clientFileNames.length > index ? clientFileNames[index] : "Instruction File ${index + 1}";
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.file_present, color: Colors.blue, size: 18),
                    title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnifiedPreviewScreen(url: clientFiles[index], title: name))),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (widget.task.modificationNotes != null && widget.task.modificationNotes!.isNotEmpty)
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text("Revision: ${widget.task.modificationNotes!}", style: const TextStyle(fontSize: 12))),

          Row(
            children: [
              _statusBadge(status),
              const Spacer(),
              IconButton(icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue), onPressed: () => Navigator.pushReplacementNamed(context, '/studentMain', arguments: 3)),
              if (canSubmit) ElevatedButton(onPressed: _submitWork, child: const Text("Submit Work", style: TextStyle(fontSize: 11))),
            ],
          )
        ],
      ),
    );
  }

  Widget _statusBadge(String s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)));
}