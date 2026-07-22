import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../services/admin_service.dart';
import '../../services/admin_payment_service.dart'; 
import '../../services/socketservice.dart'; 
import '../../services/auth_service.dart'; 
import '../common/unified_preview_screen.dart';

class AdminTaskDetailScreen extends StatefulWidget {
  final Map task;

  const AdminTaskDetailScreen({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  State<AdminTaskDetailScreen> createState() => _AdminTaskDetailScreenState();
}

class _AdminTaskDetailScreenState extends State<AdminTaskDetailScreen> {
  final AdminService adminService = AdminService();
  final AdminPaymentService paymentService = AdminPaymentService();

  bool loadingSuggestions = false;
  bool sendingRequest = false; 
  bool processingPayment = false;
  bool finalizingBudget = false;

  // Search Filters
  String? selectedFilterLoc;
  String? selectedFilterSkill;
  List<String> availableLocs = [];
  List<String> availableSkills = [];

  List<Map<String, dynamic>> suggestedStudents = [];
  late Map<String, dynamic> _taskData;

  static const Color _primaryRed = Color(0xFFE53935);
  static const Color _surface = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _bg = Color(0xFFF4F5F9);

  @override
  void initState() {
    super.initState();
    _taskData = _safeMap(widget.task);
    
    // Real-time Sync Setup
    SocketService.connect();
    SocketService.joinTaskRoom(_taskId()); 
    
    SocketService.socket!.on('task_update', (data) {
      if (mounted && data['taskId'] == _taskId()) {
        debugPrint("Admin Detail: Live Refresh Triggered via Sockets.");
        _reloadTaskData(); 
      }
    });

    _loadVettingFilters(); 
    _loadSuggestedStudents();
  }

  @override
  void dispose() {
    SocketService.socket!.off('task_update');
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _taskMap() => _safeMap(_taskData);

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return value.map((key, val) => MapEntry(key.toString(), val));
    return <String, dynamic>{};
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }

  num _safeNum(dynamic value, {num fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? fallback;
  }

  List<String> _safeStringList(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  String _extractId(dynamic value) {
    final map = _safeMap(value);
    if (value is String) return value;
    return _safeString(map['_id'] ?? map['id']);
  }

  String _taskId() => _extractId(_taskData);

  // LOGIC: Check if task is still in recruitment phase
  bool _isVettingAllowed() {
    final status = _safeString(_taskData['status']).toLowerCase();
    return status == 'open' || status == 'request_sent';
  }

  bool _hasAssignedStudent() {
    final student = _taskMap()['student'];
    return student != null && _extractId(student).isNotEmpty;
  }

  String _formatCurrency(num value) {
    if (value <= 0) return 'TBD';
    return '₹${value.toStringAsFixed(0)}';
  }

  String _initialsFromName(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ').where((p) => p.trim().isNotEmpty).toList();
    if (parts.length >= 2) return (parts.first[0] + parts.last[0]).toUpperCase();
    return parts.first[0].toUpperCase();
  }

  Future<void> _makeCall(String? num) async {
    if (num == null || num.isEmpty) return;
    final Uri u = Uri(scheme: 'tel', path: num);
    if (await canLaunchUrl(u)) {
      await launchUrl(u);
    }
  }

  // ---------------------------------------------------------------------------
  // CORE ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _reloadTaskData() async {
    try {
      final updated = await adminService.getTaskById(_taskId());
      if (mounted) setState(() => _taskData = _safeMap(updated));
    } catch (_) {}
  }

  Future<void> _loadVettingFilters() async {
    try {
      final filters = await adminService.getStudentFilters();
      if (mounted) {
        setState(() {
          availableLocs = List<String>.from(filters['locations'] ?? []);
          availableSkills = List<String>.from(filters['skills'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSuggestedStudents() async {
    setState(() => loadingSuggestions = true);
    try {
      final raw = await adminService.getSuggestedStudentsForTask(
        _taskId(),
        skill: selectedFilterSkill,
        location: selectedFilterLoc,
      );
      setState(() => suggestedStudents = List<Map<String, dynamic>>.from(raw));
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => loadingSuggestions = false);
    }
  }

  Future<void> _handleFinalizeFinancials(String clientAmt, String studentAmt) async {
    final double? cVal = double.tryParse(clientAmt);
    final double? sVal = double.tryParse(studentAmt);
    
    if (cVal == null || cVal <= 0 || sVal == null || sVal <= 0) {
      _showSnackBar("Enter valid amounts for both fields");
      return;
    }

    setState(() => finalizingBudget = true);
    try {
      await paymentService.finalizeTaskBudget(
        taskId: _taskId(), 
        clientBudget: cVal, 
        studentPayout: sVal
      );
      _showSnackBar("Finances locked. Margin secured.");
      await _reloadTaskData();
    } catch (e) { 
      _showSnackBar("Finalization failed."); 
    } finally { 
      if (mounted) setState(() => finalizingBudget = false); 
    }
  }

  Future<void> _verifyClientPayment() async {
    setState(() => processingPayment = true);
    try {
      await adminService.confirmClientPayment(_taskId());
      await _reloadTaskData();
      _showSnackBar("Payment verified.");
    } catch (e) { _showSnackBar("Update failed"); }
    finally { if (mounted) setState(() => processingPayment = false); }
  }

  Future<void> _verifyStudentPayout() async {
    setState(() => processingPayment = true);
    try {
      await adminService.confirmStudentPayout(_taskId());
      await _reloadTaskData();
      _showSnackBar("Payout confirmed.");
    } catch (e) { _showSnackBar("Update failed"); }
    finally { if (mounted) setState(() => processingPayment = false); }
  }

  Future<void> _sendRequestToStudent(Map<String, dynamic> student) async {
    final studentId = _extractId(student);
    setState(() => sendingRequest = true);
    try {
      await adminService.assignTaskToStudent(taskId: _taskId(), studentId: studentId);
      await _reloadTaskData();
      _showSnackBar('Invitation sent.');
    } catch (e) { _showSnackBar('Failed to send request'); }
    finally { if (mounted) setState(() => sendingRequest = false); }
  }

  void _openChat(String? studentId) {
    Navigator.pushNamed(context, '/taskChat', arguments: {
      'taskId': _taskId(),
      'taskTitle': _safeString(_taskData['title']),
      'peerStudentId': studentId
    });
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildBudgetFinalizer() {
    final status = _taskData['status'];
    if (status != 'assigned' && status != 'under_review' && status != 'completed') return const SizedBox.shrink();
    if (_taskData['adminReceivedPayment'] == true) return const SizedBox.shrink();

    final bool isFinalized = _taskData['budgetFinalized'] == true;
    final TextEditingController clientCtrl = TextEditingController(text: _taskData['budget']?.toString() ?? '');
    final TextEditingController studentCtrl = TextEditingController(text: _taskData['studentPayout']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isFinalized ? "UPDATE PROJECT FINANCES" : "FINALIZE FINANCES (MANDATORY)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: TextField(controller: clientCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Client Pays", isDense: true, border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: studentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Student Gets", isDense: true, border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: finalizingBudget ? null : () => _handleFinalizeFinancials(clientCtrl.text, studentCtrl.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(isFinalized ? "Update Values" : "Finalize & Lock Amounts"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPaymentControl() {
    if (_taskData['status'] != 'completed') return const SizedBox.shrink();
    final bool clientPaid = _taskData['adminReceivedPayment'] == true;
    final bool studentPaid = _taskData['adminPaidStudent'] == true;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.withOpacity(0.2))),
      child: Column(
        children: [
          _paymentToggle("1. Client paid Admin", clientPaid, _verifyClientPayment),
          const SizedBox(height: 12),
          _paymentToggle("2. Admin paid Student", studentPaid, _verifyStudentPayout),
        ],
      ),
    );
  }

  Widget _paymentToggle(String label, bool value, VoidCallback onAction) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        if (value) const Icon(Icons.check_circle, color: Colors.green, size: 24)
        else ElevatedButton(onPressed: processingPayment ? null : onAction, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text("Confirm", style: TextStyle(fontSize: 11))),
      ],
    );
  }

  Widget _buildClientAttachmentsSection() {
    final List attachments = _taskData['attachments'] as List? ?? [];
    final List names = _taskData['attachmentNames'] as List? ?? [];
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CLIENT PROJECT ASSETS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          ...List.generate(attachments.length, (index) {
            final String url = attachments[index].toString();
            final String name = names.length > index ? names[index].toString() : "Project File ${index + 1}";
            return ListTile(
              dense: true,
              leading: const Icon(Icons.description_outlined, color: Colors.blue),
              title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.grey),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnifiedPreviewScreen(url: url, title: "Brief: $name"))),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubmissionSection() {
    final submission = _safeMap(_taskData['submission']);
    if (submission.isEmpty) return const SizedBox.shrink();
    final List files = submission['files'] is List ? submission['files'] : [];
    final String? legacyUrl = submission['fileUrl']?.toString();

    if (files.isEmpty && (legacyUrl == null || legacyUrl.isEmpty)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ADMIN QUALITY CHECK: STUDENT WORK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.green)),
          const SizedBox(height: 12),
          if (files.isNotEmpty)
            ...files.map((file) => _fileQualityCheckTile(file['name']?.toString() ?? 'Work File', file['url']?.toString() ?? '')).toList(),
          if (files.isEmpty && legacyUrl != null)
            _fileQualityCheckTile("Work Deliverable (Legacy)", legacyUrl),
          if (submission['notes'] != null && submission['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("STUDENT NOTE:", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
            Text(submission['notes'], style: const TextStyle(fontSize: 12, color: Colors.black87, fontStyle: FontStyle.italic)),
          ]
        ],
      ),
    );
  }

  Widget _fileQualityCheckTile(String name, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.1))),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.green),
        title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.remove_red_eye_outlined, color: Colors.blue, size: 18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnifiedPreviewScreen(url: url, title: "Quality Check: $name"))),
      ),
    );
  }

  /// RESTORED: Candidate Section with PRE-INVITE CHAT AND CALL
  Widget _buildSuggestedStudentsSection() {
    // SECURITY: Hide this entire section if task is already assigned
    if (!_isVettingAllowed()) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("CANDIDATE VETTING", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11, letterSpacing: 1.1)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Row(
            children: [
              Expanded(child: DropdownButtonFormField<String>(isExpanded: true, value: selectedFilterLoc, hint: const Text("City"), items: [const DropdownMenuItem(value: null, child: Text("All")), ...availableLocs.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))], onChanged: (v) { setState(() => selectedFilterLoc = v); _loadSuggestedStudents(); })),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(isExpanded: true, value: selectedFilterSkill, hint: const Text("Skill"), items: [const DropdownMenuItem(value: null, child: Text("All")), ...availableSkills.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))], onChanged: (v) { setState(() => selectedFilterSkill = v); _loadSuggestedStudents(); })),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (loadingSuggestions) const Center(child: CircularProgressIndicator()),
        ...suggestedStudents.map((s) {
          final isInvited = _extractId(_taskData['requestedStudent']) == _extractId(s);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _border)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(_initialsFromName(_safeString(s['name'])))),
                    title: Text(_safeString(s['name']), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${s['location'] ?? 'Remote'} • ${s['tasksCompleted'] ?? 0} tasks"),
                  ),
                  Row(
                    children: [
                      // RESTORED: CHAT BEFORE INVITING
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue), 
                        onPressed: () => _openChat(_extractId(s))
                      ),
                      // RESTORED: CALL BEFORE INVITING
                      IconButton(
                        icon: const Icon(Icons.call_outlined, color: Colors.green), 
                        onPressed: () => _makeCall(_safeString(s['mobile']))
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isInvited ? Colors.green : _primaryRed),
                        onPressed: isInvited ? null : () => _sendRequestToStudent(s),
                        child: Text(isInvited ? "Sent" : "Invite"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAssignedStudentCard() {
    final student = _safeMap(_taskMap()['student']);
    final studentId = _extractId(student);
    final String mobile = _safeString(student['mobile']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.2))),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.white, child: Text(_initialsFromName(_safeString(student['name'])), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        title: Text(_safeString(student['name']), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(mobile),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue), onPressed: () => _openChat(studentId)),
            IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => _makeCall(mobile)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _taskData;
    final bool isGuest = task['isGuestTask'] == true;
    final guest = _safeMap(task['guestInfo']);
    final client = _safeMap(task['client']);
    final requiredSkills = _safeStringList(task['requiredSkills']);
    final clientName = isGuest ? _safeString(guest['name']) : _safeString(client['name']);
    final clientMobile = isGuest ? _safeString(guest['mobile']) : _safeString(client['mobile']);

    return Scaffold(
      appBar: AppBar(title: const Text('Matching Hub'), backgroundColor: Colors.white, foregroundColor: Colors.black87, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _reloadTaskData)]),
      backgroundColor: _bg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGuest) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)), child: const Text("EMERGENCY TASK", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Text(_safeString(task['title']), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Client: $clientName", style: const TextStyle(fontWeight: FontWeight.bold)), Text("Mob: $clientMobile", style: const TextStyle(fontSize: 12, color: Colors.grey))])),
                  IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => _makeCall(clientMobile)), 
                  IconButton(icon: const Icon(Icons.chat_outlined, color: _primaryRed), onPressed: () => _openChat(null))
                ]),
              ],
            ),
          ),
          
          _buildClientAttachmentsSection(), 
          _buildSubmissionSection(),
          _buildBudgetFinalizer(), 
          _buildAdminPaymentControl(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("REQUIRED SKILLS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: requiredSkills.map((s) => Chip(backgroundColor: _primaryRed.withOpacity(0.05), label: Text(s, style: const TextStyle(fontSize: 11, color: _primaryRed)))).toList()),
                const Divider(height: 24),
                const Text("DESCRIPTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(_safeString(task['description']), style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
                const SizedBox(height: 12),
                Text("Final Client Cost: ${_formatCurrency(_safeNum(task['budget']))}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text("Student Earning: ${_formatCurrency(_safeNum(task['studentPayout']))}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_hasAssignedStudent()) _buildAssignedStudentCard(),
          _buildSuggestedStudentsSection(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _iconDetail(IconData icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 10), Text(text, style: const TextStyle(fontSize: 14))]));
  Widget _infoCardRow(String l, String v) => Row(children: [Text("$l:", style: const TextStyle(fontSize: 12, color: Colors.grey)), const Spacer(), Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]);
  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
}