import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/socketservice.dart'; // IMPORTED
import 'admin_task_detail_screen.dart';

// --- DESIGN TOKENS ---
const Color primaryRed = Color(0xFFE53935);
const Color bgGray = Color(0xFFF7F8FC);
const Color textDark = Color(0xFF1F2937);
const Color textMuted = Color(0xFF6B7280);
const Color blueColor = Color(0xFF2563EB);
const Color greenColor = Color(0xFF059669);
const Color amberColor = Color(0xFFD97706);

class AdminPendingPaymentsScreen extends StatefulWidget {
  const AdminPendingPaymentsScreen({super.key});

  @override
  State<AdminPendingPaymentsScreen> createState() => _AdminPendingPaymentsScreenState();
}

class _AdminPendingPaymentsScreenState extends State<AdminPendingPaymentsScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  List<Map<String, dynamic>> _underReviewTasks = [];
  List<Map<String, dynamic>> _payoutQueue = [];
  List<Map<String, dynamic>> _historyTasks = [];

  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();

    // ============================================================
    // MODIFICATION: REAL-TIME DYNAMIC LISTENERS
    // ============================================================
    SocketService.connect();
    SocketService.joinAdminRoom();

    // Automatically refresh data when these events occur on the platform
    SocketService.on('task_update', (_) => _loadAllData(isSilent: true));
    SocketService.on('task_submitted', (_) => _loadAllData(isSilent: true));
    SocketService.on('admin_stats_update', (_) => _loadAllData(isSilent: true));
  }

  @override
  void dispose() {
    // MODIFICATION: CLEAN UP LISTENERS
    SocketService.off('task_update');
    SocketService.off('task_submitted');
    SocketService.off('admin_stats_update');
    _tabController.dispose();
    super.dispose();
  }

  String _safeString(dynamic v) => v?.toString() ?? '';

  /// Loads all tasks and categorizes them into the 3 tab buckets.
  /// [isSilent] prevents the full-screen spinner for background updates.
  Future<void> _loadAllData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) setState(() => _loading = true);
    
    try {
      final allTasks = await _adminService.getTasks();
      
      if (mounted) {
        setState(() {
          // 1. Pending Vetting: Current status is under review
          _underReviewTasks = allTasks.where((t) => t['status'] == 'under_review').toList();

          // 2. Payments Queue: Completed but one of the two steps is missing
          _payoutQueue = allTasks.where((t) => 
            t['status'] == 'completed' && 
            (t['adminReceivedPayment'] == false || t['adminPaidStudent'] == false)
          ).toList();

          // 3. Finished: Completed and both manual payment steps are verified
          _historyTasks = allTasks.where((t) => 
            t['status'] == 'completed' && 
            t['adminReceivedPayment'] == true && 
            t['adminPaidStudent'] == true
          ).toList();
        });
      }
    } catch (e) {
      debugPrint("Load Error: $e");
    } finally {
      if (mounted && !isSilent) setState(() => _loading = false);
    }
  }

  Future<void> _grantClientPermission(Map<String, dynamic> task) async {
    setState(() => _busy = true);
    try {
      await _adminService.toggleSubmissionVisibility(_safeString(task['_id']), true);
      _showSnackBar('Access granted to Client.');
      await _loadAllData(isSilent: true);
    } catch (e) { _showSnackBar('Error: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _verifyClientPay(String taskId) async {
    setState(() => _busy = true);
    try {
      await _adminService.confirmClientPayment(taskId);
      _showSnackBar('Payment from Client verified.');
      await _loadAllData(isSilent: true);
    } catch (e) { _showSnackBar('Update failed'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _verifyStudentPayout(String taskId) async {
    setState(() => _busy = true);
    try {
      await _adminService.confirmStudentPayout(taskId);
      _showSnackBar('Payout to Student confirmed.');
      await _loadAllData(isSilent: true);
    } catch (e) { _showSnackBar('Update failed'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        title: const Text('Review & Payout Queue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryRed,
          unselectedLabelColor: textMuted,
          indicatorColor: primaryRed,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Vetting'),
            Tab(text: 'Payments'),
            Tab(text: 'Finished'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryRed))
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(minHeight: 2, color: primaryRed),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVettingTab(),
                      _buildPaymentTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVettingTab() {
    if (_underReviewTasks.isEmpty) return const _EmptyState(icon: Icons.fact_check, title: "No pending submissions");
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _underReviewTasks.length,
        itemBuilder: (ctx, i) {
          final t = _underReviewTasks[i];
          final bool isVisible = t['clientCanViewSubmission'] == true;
          return _ReviewCard(
            task: t,
            action: isVisible 
              ? const Text("Waiting for Client Approval", style: TextStyle(fontSize: 11, color: amberColor, fontWeight: FontWeight.bold))
              : ElevatedButton.icon(
                  onPressed: _busy ? null : () => _grantClientPermission(t),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text("Release to Client"),
                  style: ElevatedButton.styleFrom(backgroundColor: blueColor),
                ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentTab() {
    if (_payoutQueue.isEmpty) return const _EmptyState(icon: Icons.account_balance_wallet, title: "No pending verifications");
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payoutQueue.length,
        itemBuilder: (ctx, i) {
          final t = _payoutQueue[i];
          final bool clientPaid = t['adminReceivedPayment'] == true;
          final bool studentPaid = t['adminPaidStudent'] == true;

          return _ReviewCard(
            task: t,
            action: Column(
              children: [
                _paymentActionRow("1. Client -> Admin", clientPaid, () => _verifyClientPay(t['_id'])),
                const SizedBox(height: 8),
                _paymentActionRow("2. Admin -> Student", studentPaid, () => _verifyStudentPayout(t['_id'])),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_historyTasks.isEmpty) return const _EmptyState(icon: Icons.history, title: "No history found");
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyTasks.length,
        itemBuilder: (ctx, i) => _ReviewCard(
          task: _historyTasks[i],
          action: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Icon(Icons.verified, color: greenColor, size: 16),
              SizedBox(width: 4),
              Text("Task & Payment Finalized", style: TextStyle(color: greenColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentActionRow(String label, bool isDone, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        if (isDone) const Icon(Icons.check_circle, color: greenColor, size: 20)
        else ElevatedButton(
          onPressed: _busy ? null : onTap,
          style: ElevatedButton.styleFrom(backgroundColor: amberColor, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
          child: const Text("Confirm", style: TextStyle(fontSize: 10)),
        )
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map task;
  final Widget action;
  const _ReviewCard({required this.task, required this.action});

  @override
  Widget build(BuildContext context) {
    final client = task['client'] as Map? ?? {};
    final student = task['student'] as Map? ?? {};
    final bool isGuest = task['isGuestTask'] == true;
    final guest = task['guestInfo'] as Map? ?? {};

    final clientName = isGuest ? "${guest['name']} (Guest)" : (client['name'] ?? 'Unknown');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminTaskDetailScreen(task: task))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              _meta(Icons.person_outline, "Client: $clientName"),
              _meta(Icons.school_outlined, "Student: ${student['name'] ?? 'N/A'}"),
              const Divider(height: 24),
              action,
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [Icon(icon, size: 14, color: textMuted), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 12, color: textMuted))]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String title;
  const _EmptyState({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 48, color: Colors.grey[300]), const SizedBox(height: 12), Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]));
  }
}