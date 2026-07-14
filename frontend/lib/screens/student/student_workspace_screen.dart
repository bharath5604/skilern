import 'dart:async';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
// REMOVED: import 'package:firebase_storage/firebase_storage.dart' as fstorage; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/task_service.dart';
import '../../services/auth_service.dart'; 
import '../../services/socketservice.dart'; 
import '../../services/file_service.dart'; // MODIFICATION: IMPORT VPS FILE SERVICE
import '../../models/task.dart';
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

  /// Sets up sockets and initial data load
  Future<void> _initializeRealTimeAndData() async {
    await _loadAllData();

    SocketService.connect();
    
    if (AuthService.userId != null) {
      SocketService.joinUserRoom(AuthService.userId!);
    }

    // Refresh everything when signals are received from backend
    SocketService.on('task_request', (_) => _loadAllData(isSilent: true));
    SocketService.on('task_update', (_) => _loadAllData(isSilent: true));
    SocketService.on('task_assigned', (_) => _loadAllData(isSilent: true));
    SocketService.on('task_status_changed', (_) => _loadAllData(isSilent: true));
  }

  @override
  void dispose() {
    SocketService.off('task_request');
    SocketService.off('task_update');
    SocketService.off('task_assigned');
    SocketService.off('task_status_changed');
    _animationController.dispose();
    super.dispose();
  }

  /// Fetches invitations and current assignments.
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

      // Join individual rooms for project-specific signals
      for (var t in _tasks) {
        if (t.id.isNotEmpty) SocketService.joinTaskRoom(t.id);
      }

      _animationController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to sync: $e');
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
        elevation: 0,
        backgroundColor: Colors.white,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [primaryPurple, secondaryPurple],
          ).createShader(bounds),
          child: const Text('My Workspace',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
        ),
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
                    _buildSectionHeader('Active & Closed Assignments', _tasks.length, primaryPurple),
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
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      child: const Column(
        children: [
          Icon(Icons.assignment_late_outlined, size: 48, color: Color(0xFFE2E8F0)),
          SizedBox(height: 16),
          Text('No active assignments', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INVITATION CARD
// ---------------------------------------------------------------------------

class _InvitationCard extends StatefulWidget {
  final Task task;
  final Future<void> Function({bool isSilent}) onAction;
  const _InvitationCard({required this.task, required this.onAction});

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _busy = false;

  String _formatCurrency(double? val) => val == null ? 'TBD' : '₹${val.toStringAsFixed(0)}';

  Future<void> _accept() async {
    bool accepted = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Student Terms & Declaration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Please read and confirm eligibility to accept this task:", 
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  
                  _term("1. Eligibility", "I declare I am currently enrolled in a recognized undergraduate program. Ineligible users will be terminated."),
                  _term("2. Verification", "SKILERN reserves the right to verify my status. False info leads to immediate suspension and payment withholding."),
                  _term("3. Payment", "Payment is subject to: fulfilling requirements, meeting deadlines, and client approval/satisfaction."),
                  _term("4. Non-Compliance", "If requirements or client expectations are not met, no payment shall be processed."),
                  _term("5. Information", "I confirm that all information provided during registration and for this task is true and complete."),
                  _term("6. Liability", "I am solely responsible for misrepresentation. SKILERN reserves the right to take legal action for damages."),
                  _term("7. Authority", "All decisions made by SKILERN regarding eligibility, approval, and payout are final and binding."),

                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: CheckboxListTile(
                      value: accepted,
                      activeColor: const Color(0xFF6A11CB),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text("I have read, understood, and agree to the 7 points above.", 
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                      onChanged: (v) => setDialogState(() => accepted = v ?? false),
                    ),
                  )
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Decline', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: accepted ? () => Navigator.pop(ctx, true) : null, 
              style: ElevatedButton.styleFrom(backgroundColor: accepted ? const Color(0xFF6A11CB) : Colors.grey),
              child: const Text('Accept & Start')
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() => _busy = true);
      try {
        await TaskService().acceptAssignmentRequest(taskId: widget.task.id, acceptedTerms: true);
        widget.onAction(isSilent: true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Widget _term(String t, String b) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF6A11CB))),
        const SizedBox(height: 2),
        Text(b, style: const TextStyle(fontSize: 12, height: 1.3, color: Colors.black87)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.blue, width: 0.8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(widget.task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text("Proposed Budget: ${_formatCurrency(widget.task.budget)}", style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
        trailing: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 16)),
          onPressed: _accept, child: const Text("Accept", style: TextStyle(fontSize: 12))
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WORKSPACE TASK CARD
// ---------------------------------------------------------------------------

class _WorkspaceTaskCard extends StatefulWidget {
  final Task task;
  final Future<void> Function({bool isSilent}) onSubmitted;
  const _WorkspaceTaskCard({required this.task, required this.onSubmitted});

  @override
  State<_WorkspaceTaskCard> createState() => _WorkspaceTaskCardState();
}

class _WorkspaceTaskCardState extends State<_WorkspaceTaskCard> {
  bool _uploading = false;

  String _formatCurrency(double? val) => val == null ? 'TBD' : '₹${val.toStringAsFixed(0)}';

  // ============================================================
  // MODIFICATION: SECURE VPS DELIVERABLE UPLOAD
  // ============================================================
  Future<void> _submitWork() async {
    final noteCtrl = TextEditingController();
    String? fileUrl;
    String? fileName;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Upload Deliverables"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_uploading) const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6A11CB)),
                    SizedBox(height: 12),
                    Text("Storing securely on VPS...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
              else ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                leading: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF6A11CB)),
                title: Text(fileName ?? "Select Work File", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text("PDF, ZIP or Images (Max 15MB)", style: TextStyle(fontSize: 11)),
                onTap: () async {
                  final res = await FilePicker.platform.pickFiles(withData: true);
                  if (res != null) {
                    setDialogState(() => _uploading = true);
                    try {
                      // MODIFICATION: Secure VPS Upload
                      fileUrl = await FileService.uploadToVault(res.files.first, res.files.first.name);
                      fileName = res.files.first.name;
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
                    } finally {
                      setDialogState(() => _uploading = false);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(controller: noteCtrl, maxLines: 2, decoration: const InputDecoration(hintText: "Add a note for the Client...")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: (fileUrl == null || _uploading) ? null : () async {
                await TaskService().submitWork(taskId: widget.task.id, fileUrl: fileUrl!, notes: noteCtrl.text);
                Navigator.pop(ctx);
                widget.onSubmitted(isSilent: true);
              },
              child: const Text("Submit Work"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.task.status.toLowerCase();
    final bool canSubmit = status == 'assigned' || status == 'declined';
    final bool isCompleted = status == 'completed';
    final bool isReview = status == 'under_review';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.task.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Text(_formatCurrency(widget.task.budget), style: const TextStyle(color: Color(0xFF6A11CB), fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          
          if ((status == 'assigned' || status == 'declined') && widget.task.modificationNotes != null && widget.task.modificationNotes!.isNotEmpty)
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 14),
               decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.2))),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Row(
                     children: [
                       Icon(Icons.edit_note_rounded, color: Colors.orange, size: 18),
                       SizedBox(width: 8),
                       Text("MODIFICATION INSTRUCTIONS", style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(height: 6),
                   Text(widget.task.modificationNotes!, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
                 ],
               ),
             ),

          Row(
            children: [
              _statusBadge(status),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentMainShell(initialIndex: 3))), 
                icon: const Icon(Icons.chat_bubble_outline, size: 22, color: Colors.blue)
              ),
              const SizedBox(width: 8),
              
              if (canSubmit) 
                ElevatedButton(
                  onPressed: _submitWork, 
                  child: Text(status == 'assigned' && widget.task.modificationNotes!.isNotEmpty ? "Resubmit" : "Submit Work")
                )
              else if (isCompleted)
                const Row(children: [Icon(Icons.verified, color: Colors.green, size: 16), SizedBox(width: 4), Text("Finalized", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))])
              else if (isReview)
                const Text("Under Review", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color c = Colors.grey;
    String label = status;
    if (status == 'assigned') { c = Colors.orange; label = "In Progress"; }
    if (status == 'under_review') { c = Colors.blue; label = "Vetting"; }
    if (status == 'completed') { c = Colors.green; label = "Completed"; }
    if (status == 'declined') { c = Colors.red; label = "Revision"; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c, letterSpacing: 0.5)),
    );
  }
}