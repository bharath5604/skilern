import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http; // MODIFICATION: For Secure Downloads

// Conditional Import for Razorpay Web Bridge
import '../../utils/razorpay_web_bridge.dart'
    if (dart.library.js) '../../utils/razorpay_web_impl.dart';

import '../../services/task_service.dart';
import '../../services/auth_service.dart';
import '../../services/socketservice.dart'; 
import '../../models/task.dart';
import '../../env.dart'; 
import '../common/unified_preview_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({Key? key}) : super(key: key);

  @override
  MyTasksScreenState createState() => MyTasksScreenState();
}

class MyTasksScreenState extends State<MyTasksScreen> {
  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color backgroundColor = Color(0xFFF5F7FB);

  final TaskService taskService = TaskService();
  final TextEditingController _feedbackController = TextEditingController();
  
  Razorpay? _razorpay;
  List<Task> tasks = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccessMobile);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    }
    
    _initializeRealTimeAndData();
  }

  Future<void> _initializeRealTimeAndData() async {
    await loadMyTasks();
    SocketService.connect();
    
    // Logic: React instantly to payment success or student resubmissions
    SocketService.on('task_update', (data) {
      if (mounted) {
        debugPrint("Client MyTasks: Refreshing view via Socket signal.");
        loadMyTasks(isSilent: true); 
      }
    });
  }

  @override
  void dispose() {
    if (!kIsWeb) _razorpay?.clear(); 
    SocketService.off('task_update');
    _feedbackController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // CORE ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> loadMyTasks({bool isSilent = false}) async {
    if (mounted && !isSilent) setState(() => loading = true);
    try {
      final List<Task> res = await taskService.getMyTasks();
      if (!mounted) return;
      setState(() => tasks = res);

      // Join individual client rooms for thread isolation
      for (var t in res) {
        if (t.id.isNotEmpty) {
          // joins {taskId}_client sub-room by default
          SocketService.joinTaskRoom(t.id); 
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to load tasks');
    } finally {
      if (mounted && !isSilent) setState(() => loading = false);
    }
  }

  // ============================================================
  // FIXED: MODIFICATION REQUEST DIALOG
  // ============================================================
  Future<void> _handleRequestModification(Task t) async {
    final TextEditingController reasonCtrl = TextEditingController();
    
    final String? resultText = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Request Changes", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Provide clear instructions for the student:", style: TextStyle(fontSize: 12, color: textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "e.g. Please update the color to Skilern purple...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
            onPressed: () {
              final text = reasonCtrl.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            }, 
            child: const Text("Send", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (resultText != null && resultText.isNotEmpty) {
      try {
        if (mounted) setState(() => loading = true);
        await taskService.requestRevision(taskId: t.id, reason: resultText);
        _showSnackBar('Instructions sent to student.');
        await loadMyTasks(isSilent: true);
      } catch (e) {
        _showSnackBar('Failed to send request');
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
    reasonCtrl.dispose();
  }

  void _startRazorpayPayment(Task t) {
    final double amount = t.budget ?? 0.0;
    if (amount <= 0) {
      _showSnackBar("Negotiated amount not finalized.");
      return;
    }

    if (kIsWeb) {
      openRazorpayWeb(
        key: Env.razorpayKeyId,
        amount: (amount * 100).toInt(),
        title: t.title,
        contact: AuthService.currentUser?.mobile ?? '',
        email: AuthService.currentUser?.email ?? '',
        onSuccess: () => _onPaymentSuccessInternal(),
      );
    } else {
      final options = {
        'key': Env.razorpayKeyId,
        'amount': (amount * 100).toInt(),
        'name': 'Skilern',
        'description': t.title,
        'prefill': {'contact': AuthService.currentUser?.mobile ?? '', 'email': AuthService.currentUser?.email ?? ''},
      };
      _razorpay?.open(options);
    }
  }

  void _onPaymentSuccessInternal() {
    _showSnackBar("Success! Verification in progress.");
    loadMyTasks(isSilent: true);
  }

  void _handlePaymentSuccessMobile(PaymentSuccessResponse response) => _onPaymentSuccessInternal();

  void _handlePaymentError(PaymentFailureResponse response) {
    _showSnackBar("Payment Failed: ${response.message}");
  }

  Future<void> approveAndRate(String taskId) async {
    int rating = 5;
    _feedbackController.clear();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Approval', style: TextStyle(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (ctx, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Finalizing will approve the work and enable payment.', 
                    style: TextStyle(fontSize: 12, color: textMuted)),
                  const SizedBox(height: 16),
                  DropdownButton<int>(
                    value: rating,
                    isExpanded: true,
                    items: [1, 2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text("Rate: $e Stars"))).toList(),
                    onChanged: (val) => setStateDialog(() => rating = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _feedbackController, decoration: const InputDecoration(hintText: 'Comment (Optional)...')),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await taskService.approveSubmittedTask(taskId: taskId);
                  await taskService.sendFeedback(taskId: taskId, text: _feedbackController.text, score: rating);
                  loadMyTasks(isSilent: true);
                  Navigator.pop(dialogCtx);
                } catch (e) { _showSnackBar("Error during approval"); }
              },
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryPurple),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Project Workspace',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textDark),
        ),
        actions: [IconButton(onPressed: () => loadMyTasks(), icon: const Icon(Icons.refresh_rounded, color: primaryPurple))],
      ),
      body: loading && tasks.isEmpty
        ? const Center(child: CircularProgressIndicator(color: primaryPurple)) 
        : tasks.isEmpty 
          ? const Center(child: Text("No active projects found."))
          : RefreshIndicator(
              onRefresh: loadMyTasks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (ctx, i) => _buildTaskCard(tasks[i]),
              ),
            ),
    );
  }

  Widget _buildTaskCard(Task t) {
    final bool hasSubmitted = t.hasSubmission;
    final bool isDownloadUnlocked = t.clientCanDownload;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                _buildStatusChip(t.status),
              ],
            ),
            const SizedBox(height: 6),
            Text("Negotiated Budget: ${t.budget != null ? '₹${t.budget!.toStringAsFixed(0)}' : 'TBD'}", 
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
            
            if (hasSubmitted) ...[
              const Divider(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDownloadUnlocked ? Colors.green.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isDownloadUnlocked ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(isDownloadUnlocked ? Icons.verified_user : Icons.lock_open_rounded, 
                             color: isDownloadUnlocked ? Colors.green : Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(isDownloadUnlocked ? "Deliverables Ready" : "Vetting Stage (Preview Only)", 
                             style: TextStyle(fontWeight: FontWeight.bold, color: isDownloadUnlocked ? Colors.green : Colors.blue, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: t.submissionFile == null ? null : () {
                          // The previewer now handles the Authenticated Handshake for VPS
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => UnifiedPreviewScreen(url: t.submissionFile!, title: t.title)
                          ));
                        },
                        icon: const Icon(Icons.remove_red_eye_rounded),
                        label: const Text("View Work"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        // MODIFICATION: Trigger internal secure download via VPS endpoint if unlocked
                        onPressed: (isDownloadUnlocked && t.submissionFile != null) ? () => _launchSecureUrl(t.submissionFile!) : null, 
                        icon: Icon(isDownloadUnlocked ? Icons.file_download : Icons.lock_clock),
                        label: const Text("Save to Device"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDownloadUnlocked ? primaryPurple : Colors.grey[300],
                          foregroundColor: Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    if (t.status != 'completed') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => _handleRequestModification(t), child: const Text("Modify", style: TextStyle(fontSize: 11)))),
                          const SizedBox(width: 10),
                          Expanded(child: ElevatedButton(onPressed: () => approveAndRate(t.id), child: const Text("Approve Work", style: TextStyle(fontSize: 11)))),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            ],

            if (t.status == 'completed') ...[
              const Divider(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.adminReceivedPayment ? Colors.green.withOpacity(0.05) : Colors.amber.withOpacity(0.05), 
                  borderRadius: BorderRadius.circular(15), 
                  border: Border.all(color: t.adminReceivedPayment ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2))
                ),
                child: Column(
                  children: [
                    if (t.adminReceivedPayment) ...[
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
                      const SizedBox(height: 8),
                      const Text("Project Finalized", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ] else if (t.budgetFinalized) ...[
                      const Text("Budget Finalized", style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
                        onPressed: () => _startRazorpayPayment(t),
                        icon: const Icon(Icons.payment, color: Colors.white),
                        label: Text("Pay ₹${(t.budget ?? 0).toStringAsFixed(0)} via Razorpay"),
                      ),
                    ] else ...[
                      const Text("Awaiting Payment Verification", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text("Contact Admin to verify your manual payment or wait for budget finalization.", 
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: textMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    switch (status.toLowerCase()) {
      case 'open': color = Colors.blue; break;
      case 'assigned': color = Colors.orange; break;
      case 'under_review': color = Colors.indigo; break;
      case 'completed': color = Colors.green; break;
      case 'declined': color = Colors.red; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  
  /// MODIFICATION: Secure Download aware launcher
  Future<void> _launchSecureUrl(String url) async { 
    // Logic: Since VPS requires headers, standard browser launching might fail.
    // For now, we launch the URL. If you encounter 401s, we will implement
    // an authenticated downloader next.
    final Uri u = Uri.parse(url); 
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication); 
    }
  }
}