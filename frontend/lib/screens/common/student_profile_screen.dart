import 'package:flutter/material.dart';
import '../../services/student_service.dart';
import '../../services/socketservice.dart'; // IMPORTED for dynamic updates

class StudentProfileScreen extends StatefulWidget {
  final String studentId;

  const StudentProfileScreen({
    Key? key,
    required this.studentId,
  }) : super(key: key);

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final StudentService service = StudentService();

  Map<String, dynamic>? data;
  bool loading = false;

  // Design Tokens
  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _initializeRealTimeProfile();
  }

  /// Sets up real-time sync and initial data load
  Future<void> _initializeRealTimeProfile() async {
    await _loadProfile();

    // ============================================================
    // MODIFICATION: REAL-TIME DYNAMIC REFRESH
    // ============================================================
    SocketService.connect();
    
    // Listen for profile update signals from the student
    SocketService.on('user_profile_updated', (payload) {
      if (mounted && payload['userId'] == widget.studentId) {
        debugPrint("Public Student Profile: Data changed, refreshing...");
        _loadProfile(isSilent: true); 
      }
    });
  }

  @override
  void dispose() {
    // CLEAN UP
    SocketService.off('user_profile_updated');
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final String s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return [];
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------

  Future<void> _loadProfile({bool isSilent = false}) async {
    if (mounted && !isSilent) {
      setState(() => loading = true);
    }

    try {
      final res = await service.getPublicProfile(widget.studentId);
      if (!mounted) return;

      setState(() {
        data = Map<String, dynamic>.from(res);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      if (mounted && !isSilent) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = data;

    // Identity
    final String name = _asString(profile?['name']);
    final String email = _asString(profile?['email']);
    final String mobile = _asString(profile?['mobile']);
    final String location = _asString(profile?['location'], fallback: 'Remote');
    // final String bio = _asString(profile?['bio'], fallback: 'No professional bio provided.');
    final String portfolioUrl = _asString(profile?['portfolioUrl']);

    // Reputation
    final double totalAverageScore = _asDouble(profile?['totalAverageScore']);
    final int totalScoreCount = _asInt(profile?['totalScoreCount']);
    final int tasksCompleted = _asInt(profile?['tasksCompleted']);
    
    // Skills & History
    final List<dynamic> skills = _asList(profile?['skills']);
    final List<dynamic> domains = _asList(profile?['domains']);
    final List<dynamic> reviews = _asList(profile?['feedbackEntries']);

    // Banking (New for Admin insight)
    final String accHolder = _asString(profile?['bankAccountHolderName'], fallback: 'Not provided');
    final String accNumber = _asString(profile?['bankAccountNumber'], fallback: 'Not provided');
    final String ifsc = _asString(profile?['ifscCode'], fallback: 'Not provided');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Student Full Insight'),
        actions: [IconButton(onPressed: _loadProfile, icon: const Icon(Icons.refresh))],
      ),
      body: loading && profile == null
          ? const Center(child: CircularProgressIndicator(color: primaryPurple))
          : profile == null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(name, email, location, totalAverageScore, totalScoreCount, tasksCompleted),
                        const SizedBox(height: 16),
                        
                        // _sectionTitle("Professional Bio"),
                        // _buildContentCard(Text(bio, style: const TextStyle(height: 1.5, fontSize: 13))),
                        // const SizedBox(height: 16),

                        if (skills.isNotEmpty) ...[
                          _sectionTitle("Technical Skills"),
                          _buildContentCard(Wrap(
                            spacing: 8, runSpacing: 0,
                            children: skills.map((s) => Chip(
                              label: Text(s.toString(), style: const TextStyle(fontSize: 11, color: primaryPurple)),
                              backgroundColor: primaryPurple.withOpacity(0.05),
                            )).toList(),
                          )),
                          const SizedBox(height: 16),
                        ],

                        // ============================================================
                        // MODIFICATION: COMPLETE BANKING DETAILS SECTION
                        // ============================================================
                        _sectionTitle("Banking (Payout Information)"),
                        _buildContentCard(Column(
                          children: [
                            _infoRow(Icons.badge_outlined, "A/C Holder", accHolder),
                            _infoRow(Icons.credit_card, "Account No", accNumber),
                            _infoRow(Icons.code, "IFSC Code", ifsc),
                          ],
                        )),
                        const SizedBox(height: 16),

                        if (portfolioUrl.isNotEmpty) ...[
                          _sectionTitle("Portfolio"),
                          _buildContentCard(ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.link, color: Colors.blue),
                            title: Text(portfolioUrl, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 13)),
                          )),
                          const SizedBox(height: 16),
                        ],

                        _sectionTitle("Domain-wise Performance"),
                        if (domains.isEmpty)
                          const Text("No project history yet.", style: TextStyle(fontSize: 12, color: Colors.grey))
                        else
                          ...domains.map((d) => _buildDomainCard(d)).toList(),

                        const SizedBox(height: 16),
                        _sectionTitle("Client Reviews"),
                        if (reviews.isEmpty)
                          const Text("No written feedback yet.", style: TextStyle(fontSize: 12, color: Colors.grey))
                        else
                          ...reviews.map((r) => _buildReviewCard(r)).toList(),
                          
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildHeaderCard(String name, String email, String loc, double avg, int count, int done) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryPurple, secondaryPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const CircleAvatar(radius: 35, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white, size: 40)),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _headerStat(Icons.star, avg.toStringAsFixed(1)),
              const SizedBox(width: 20),
              _headerStat(Icons.task_alt, "$done done"),
              const SizedBox(width: 20),
              _headerStat(Icons.location_on, loc),
            ],
          )
        ],
      ),
    );
  }

  Widget _headerStat(IconData i, String v) => Row(children: [Icon(i, color: Colors.amber, size: 14), const SizedBox(width: 5), Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]);

  Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(t.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: textMuted, fontSize: 11, letterSpacing: 1.1)));

  Widget _buildContentCard(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
    child: child
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [Icon(icon, size: 16, color: textMuted), const SizedBox(width: 10), Text("$label:", style: const TextStyle(fontSize: 12, color: textMuted)), const Spacer(), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))]),
  );

  Widget _buildDomainCard(dynamic d) {
    final String domainName = _asString(d['domain'], fallback: 'general');
    final double score = _asDouble(d['averageScore']);
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        dense: true,
        title: Text(domainName, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text("${score.toStringAsFixed(1)} ★", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildReviewCard(dynamic r) {
    final double rating = _asDouble(r['rating']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r['taskTitle'] ?? 'Project', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text("$rating ★", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(r['comment'] ?? 'No comment.', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildErrorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.grey), const SizedBox(height: 12), const Text('Profile not found'), const SizedBox(height: 12), ElevatedButton(onPressed: _loadProfile, child: const Text('Retry'))]));
}