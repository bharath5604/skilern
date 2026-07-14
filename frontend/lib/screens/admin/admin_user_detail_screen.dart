import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/socketservice.dart';
import '../common/unified_preview_screen.dart'; // MODIFICATION: IMPORTED SECURE PREVIEWER

// =============================================================================
// GLOBAL DESIGN TOKENS
// =============================================================================
const Color kAdminPrimary = Color(0xFFE53935);
const Color kAdminSecondary = Color(0xFF2563EB);
const Color kAdminBg = Color(0xFFF6F7FB);
const Color kAdminTextDark = Color(0xFF111827);
const Color kAdminTextMuted = Color(0xFF6B7280);
const Color kAdminCard = Colors.white;

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;
  const AdminUserDetailScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final AdminService _adminService = AdminService();
  Map<String, dynamic>? _userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();

    // ============================================================
    // REAL-TIME PROFILE SYNC (SOCKETS)
    // ============================================================
    SocketService.connect();
    
    // Listen for profile update signals from the server
    SocketService.on('user_profile_updated', (payload) {
      if (mounted && payload['userId'] == widget.userId) {
        debugPrint("Admin User Detail: Profile updated live, refreshing data...");
        _loadUser(isSilent: true); 
      }
    });
  }

  @override
  void dispose() {
    // CLEAN UP
    SocketService.off('user_profile_updated');
    super.dispose();
  }

  /// Fetches user data. [isSilent] prevents full-screen spinner during live sync.
  Future<void> _loadUser({bool isSilent = false}) async {
    if (!isSilent) setState(() => _loading = true);
    try {
      final res = await _adminService.getStudentDetails(widget.userId);
      if (mounted) {
        setState(() { 
          _userData = res['student']; 
          _loading = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint("Error loading user details: $e");
    }
  }

  // ============================================================
  // MODIFICATION: USE SECURE IN-APP PREVIEWER
  // ============================================================
  void _openIdProof(String? url, String userName) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No ID document has been provided by this user."))
      );
      return;
    }

    // Logic: Navigate to the internal previewer.
    // This allows the app to send the JWT header to your VPS Secure Vault.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedPreviewScreen(
          url: url,
          title: "Identity Proof: $userName",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kAdminPrimary)));
    }
    
    if (_userData == null) {
      return const Scaffold(body: Center(child: Text("User account not found")));
    }

    final String role = _userData!['role'] ?? 'user';
    final bool isStudent = role == 'student';
    final String name = _userData!['name'] ?? 'Unknown User';

    return Scaffold(
      backgroundColor: kAdminBg,
      appBar: AppBar(
        title: Text('${role.toUpperCase()} PROFILE'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: kAdminTextDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded), 
            onPressed: () => _loadUser()
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(isStudent, name),
          const SizedBox(height: 24),
          
          _sectionTitle("Core Account Information"),
          _infoTile(Icons.email_outlined, "Email Address", _userData!['email']),
          _infoTile(Icons.phone_iphone, "Contact Number", _userData!['mobile']),
          _infoTile(Icons.location_on_outlined, "Primary Location", _userData!['location'] ?? "Not Set"),

          if (isStudent) ...[
            const Divider(height: 40),
            _sectionTitle("Identity Verification"),
            // Pass the student name for the preview title
            _buildIdProofCard(_userData!['idCardUrl'], name),

            const Divider(height: 40),
            _sectionTitle("Banking (Payout Information)"),
            _infoTile(Icons.account_balance_outlined, "Account Holder", _userData!['bankAccountHolderName'] ?? "Not Set"),
            _infoTile(Icons.credit_card_outlined, "Bank Account Number", _userData!['bankAccountNumber'] ?? "Not Set"),
            _infoTile(Icons.code_rounded, "IFSC Code", _userData!['ifscCode'] ?? "Not Set"),

            const Divider(height: 40),
            _sectionTitle("Expertise & Skills"),
            const SizedBox(height: 8),
            _buildSkillsWrap(),
          ],

          if (!isStudent) ...[
            const Divider(height: 40),
            _sectionTitle("Business Information"),
            _infoTile(Icons.business_outlined, "Company / Entity Name", _userData!['company'] ?? "Individual"),
          ],
          
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI SUB-COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildHeader(bool isStudent, String name) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kAdminCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: isStudent ? Colors.indigo.withOpacity(0.05) : Colors.teal.withOpacity(0.05),
            child: Icon(
              isStudent ? Icons.school_rounded : Icons.business_rounded, 
              size: 40, 
              color: isStudent ? Colors.indigo : Colors.teal
            ),
          ),
          const SizedBox(height: 16), 
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAdminTextDark)),
          const SizedBox(height: 8),
          _statusBadge(),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    final bool approved = _userData!['isApproved'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: approved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(20)
      ),
      child: Text(
        approved ? "ACCOUNT ACTIVE" : "PENDING VETTING", 
        style: TextStyle(
          color: approved ? Colors.green : Colors.orange, 
          fontWeight: FontWeight.bold, 
          fontSize: 10
        )
      ),
    );
  }

  Widget _buildIdProofCard(String? url, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminCard, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: Colors.grey.shade100)
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: Colors.blueGrey),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Identity Verification Proof", 
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
            )
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey, 
              padding: const EdgeInsets.symmetric(horizontal: 12)
            ),
            // Call the internal secure viewer
            onPressed: () => _openIdProof(url, name),
            icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
            label: const Text("View Securely", style: TextStyle(fontSize: 11)),
          )
        ],
      ),
    );
  }

  Widget _buildSkillsWrap() {
    final List skills = _userData!['skills'] as List? ?? [];
    if (skills.isEmpty) {
      return const Text("No technical skills listed by user.", 
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    return Wrap(
      spacing: 8,
      children: skills.map((s) => Chip(
        backgroundColor: Colors.indigo.withOpacity(0.05),
        side: BorderSide.none,
        label: Text(
          s.toString(), 
          style: const TextStyle(
            fontSize: 11, 
            color: Colors.indigo, 
            fontWeight: FontWeight.bold
          )
        )
      )).toList(),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(
      t.toUpperCase(), 
      style: const TextStyle(
        fontWeight: FontWeight.w900, 
        color: kAdminTextMuted, 
        fontSize: 10, 
        letterSpacing: 1.1
      )
    ),
  );

  Widget _infoTile(IconData i, String l, String? v) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: kAdminCard, borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: Icon(i, size: 20, color: Colors.grey[400]),
      title: Text(l, style: const TextStyle(fontSize: 11, color: kAdminTextMuted, fontWeight: FontWeight.w500)),
      subtitle: Text(
        v != null && v.isNotEmpty ? v : "Not Provided", 
        style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminTextDark, fontSize: 14)
      ),
    ),
  );
}