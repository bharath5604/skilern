import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/student_dashboard_service.dart';
import '../../services/student_service.dart';
import '../../services/user_service.dart'; 
import '../../services/socketservice.dart'; // Corrected naming convention

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final StudentDashboardService feedbackService = StudentDashboardService();
  final StudentService studentService = StudentService();
  final UserService userService = UserService();

  Map<String, dynamic>? summary;
  bool loading = false;

  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color backgroundColor = Color(0xFFF5F7FB);

  @override
  void initState() {
    super.initState();
    _initializeRealTime();
  }

  /// Sets up real-time sync and initial data load
  Future<void> _initializeRealTime() async {
    _loadAll();

    // ============================================================
    // MODIFICATION: REAL-TIME DYNAMIC SYNC
    // ============================================================
    SocketService.connect();
    
    if (AuthService.userId != null) {
      // Join the student's private room to receive live review/payment updates
      SocketService.joinUserRoom(AuthService.userId!); 
    }

    // 1. Listen for new reviews (updates rating and feedback list)
    SocketService.on('feedback_update', (data) {
      if (mounted) {
        _loadAll(isSilent: true); 
        _showLiveSnack('New feedback received! Your reputation has been updated.');
      }
    });

    // 2. Listen for payout confirmations (updates wallet/points)
    SocketService.on('payout_processed', (data) {
      if (mounted) {
        _loadAll(isSilent: true);
        _showLiveSnack('Admin confirmed your payout! Check your account.');
      }
    });
  }

  @override
  void dispose() {
    // MODIFICATION: CLEAN UP LISTENERS
    SocketService.off('feedback_update');
    SocketService.off('payout_processed');
    super.dispose();
  }

  void _showLiveSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CORE ACTIONS (Syncs Task Count and Feedback List)
  // ---------------------------------------------------------------------------

  /// Fetches data. [isSilent] prevents full-screen spinner during live updates.
  Future<void> _loadAll({bool isSilent = false}) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    if (mounted && !isSilent) setState(() => loading = true);

    try {
      // Logic: Pulling feedback stats and fresh user profile in parallel
      final results = await Future.wait([
        feedbackService.getFeedbackSummary(user.id),
        userService.getMe(), 
      ]);

      if (!mounted) return;
      setState(() {
        summary = results[0] as Map<String, dynamic>;
        AuthService.currentUser = results[1] as User; 
      });
    } catch (e) {
      debugPrint('Dashboard Sync Error: $e');
    } finally {
      if (mounted && !isSilent) setState(() => loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // TYPE-SAFE HELPERS
  // ---------------------------------------------------------------------------

  int _toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
  double _toDouble(dynamic v) => v is double ? v : double.tryParse(v?.toString() ?? '0.0') ?? 0.0;
  
  List<Map<String, dynamic>> _asMapList(dynamic list) {
    if (list is! List) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = summary;
    final User? u = AuthService.currentUser;

    final int tasksCompleted = u?.tasksCompleted ?? 0;
    final int totalScore = _toInt(data?['totalScore']);
    final int totalScoreCount = _toInt(data?['totalScoreCount']);
    final double averageScore = _toDouble(data?['averageScore']);
    final List domainList = data?['domains'] is List ? data!['domains'] : [];
    final List feedbackEntries = _asMapList(data?['feedbackEntries']);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [primaryPurple, secondaryPurple]).createShader(bounds),
          child: const Text('Reputation Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: primaryPurple), onPressed: () => _loadAll()),
          const SizedBox(width: 8),
        ],
      ),
      body: loading && data == null
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryPurple)))
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Professional Standing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                  const Text('Metrics generated based on your completed tasks.', style: TextStyle(fontSize: 13, color: textMuted)),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _ReputationCard(
                          label: 'Tasks Done',
                          value: tasksCompleted.toString(),
                          color: primaryPurple,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReputationCard(
                          label: 'Points Earned',
                          value: totalScore.toString(),
                          color: Colors.teal,
                          icon: Icons.insights_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: primaryPurple.withOpacity(0.05)),
                      boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      children: [
                        const Text('Average Quality Score', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textMuted)),
                        const SizedBox(height: 8),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(colors: [primaryPurple, secondaryPurple]).createShader(bounds),
                          child: Text('${averageScore.toStringAsFixed(1)} / 5.0', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                        const SizedBox(height: 8),
                        Text('Calculated from $totalScoreCount client reviews', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // RESTORED: DOMAIN BREAKDOWN SECTION
                  // const _HeaderLabel(text: 'Domain Breakdown'),
                  // const SizedBox(height: 12),
                  // if (domainList.isEmpty)
                  //   const _EmptyHint(text: "Performance data by domain will appear here.")
                  // else
                  //   ...domainList.map((d) => _DomainBar(
                  //         label: d['domain'] ?? 'General',
                  //         score: _toDouble(d['averageScore']),
                  //         count: _toInt(d['count']),
                  //       )).toList(),

                  // const SizedBox(height: 24),

                  const _HeaderLabel(text: 'Recent Written Feedback'),
                  const SizedBox(height: 12),
                  if (feedbackEntries.isEmpty)
                    const _EmptyHint(text: "No text feedback received yet.")
                  else
                    ...feedbackEntries.map((f) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(f['taskTitle'] ?? 'Task', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text("${f['rating']} ★", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            f['comment'] != null && f['comment'].toString().isNotEmpty 
                                ? "\"${f['comment']}\"" 
                                : "The client approved the work without a written comment.",
                            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
                          ),
                        ),
                      ),
                    )).toList(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// --- UI COMPONENTS ---

class _ReputationCard extends StatelessWidget {
  final String label, value; final Color color; final IconData icon;
  const _ReputationCard({required this.label, required this.value, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DomainBar extends StatelessWidget {
  final String label; final double score; final int count;
  const _DomainBar({required this.label, required this.score, required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${score.toStringAsFixed(1)}/5', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6A11CB))),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: (score / 5).clamp(0.0, 1.0), minHeight: 8, backgroundColor: const Color(0xFFF5F7FB), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB))),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: Text('$count completion(s)', style: const TextStyle(fontSize: 10, color: Colors.grey))),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String text;
  const _HeaderLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFF6A11CB), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12))));
  }
}