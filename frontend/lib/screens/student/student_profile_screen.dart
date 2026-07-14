import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // IMPORTED for InputFormatters
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';

// Predefined list for technical skills
const List<String> kAllSkills = [
  'Flutter', 'React', 'Node.js', 'Python', 'Java',
  'Machine Learning', 'Data Science', 'UI/UX Design',
  'Backend Development', 'Frontend Development', 'DevOps', 'Databases',
  'Editing', 'Writing', 'Bug Fixing'
];

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({Key? key}) : super(key: key);

  @override
  StudentProfileScreenState createState() => StudentProfileScreenState();
}

class StudentProfileScreenState extends State<StudentProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>(); // Global Key for Form Validation

  bool _loading = false;
  User? _user;
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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() => _loading = true);
    try {
      final u = await _userService.getMe();
      if (!mounted) return;
      setState(() {
        _user = u;
        AuthService.currentUser = u; 
      });
      _animationController.forward(from: 0);
    } catch (e) {
      debugPrint("Profile refresh error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AuthService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/landing');
    }
  }

  // ============================================================
  // MODIFICATION: COMPLETE VALIDATED EDIT DIALOG
  // ============================================================
  Future<void> _editProfile() async {
    if (_user == null) return;
    
    final nameCtrl = TextEditingController(text: _user!.name);
    final mobileCtrl = TextEditingController(text: _user!.mobile);
    final locCtrl = TextEditingController(text: _user!.location);
    final holderCtrl = TextEditingController(text: _user!.bankAccountHolderName);
    final accNumCtrl = TextEditingController(text: _user!.bankAccountNumber);
    final ifscCtrl = TextEditingController(text: _user!.ifscCode);
    
    final customSkillCtrl = TextEditingController();
    final Set<String> tempSkills = {..._user!.skills};
    final List<String> allSkillsForUI = {...kAllSkills, ...tempSkills}.toList()..sort();

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: StatefulBuilder(
          builder: (ctx, setStateDialog) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey, // FORM WRAPPER FOR HIGHLIGHTING
                child: Column(
                  children: [
                    const Text('Edit Account Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _editLabel("Personal Information"),
                            _buildValidatedField(nameCtrl, "Full Name", Icons.person_outline, 
                                validator: (v) => (v == null || v.isEmpty) ? "Required" : null),
                            
                            _buildValidatedField(mobileCtrl, "Contact Number", Icons.phone_android_outlined, 
                                type: TextInputType.number,
                                formatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (v) => (v == null || v.length != 10) ? "Enter 10 digits" : null),
                                
                            _buildValidatedField(locCtrl, "Current City", Icons.location_on_outlined, 
                                validator: (v) => (v == null || v.isEmpty) ? "Required" : null),
                            
                            const SizedBox(height: 20),
                            _editLabel("Banking (For Payouts)"),
                            _buildValidatedField(holderCtrl, "Account Holder", Icons.badge_outlined, 
                                validator: (v) => (v == null || v.isEmpty) ? "Required" : null),
                                
                            _buildValidatedField(accNumCtrl, "Account Number", Icons.credit_card_outlined, 
                                type: TextInputType.number,
                                formatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (v) => (v == null || v.length < 9) ? "Enter valid number" : null),
                                
                            _buildValidatedField(ifscCtrl, "IFSC Code", Icons.code_rounded, 
                                caps: TextCapitalization.characters,
                                validator: (v) {
                                  final reg = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                                  return (v == null || !reg.hasMatch(v.toUpperCase())) ? "Invalid IFSC Format" : null;
                                }),
                            
                            const SizedBox(height: 20),
                            _editLabel("Technical Skills"),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: customSkillCtrl, decoration: const InputDecoration(hintText: "Add skill...", isDense: true))),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: primaryPurple, size: 32),
                                  onPressed: () {
                                    if (customSkillCtrl.text.isNotEmpty) {
                                      setStateDialog(() {
                                        String cleaned = customSkillCtrl.text.trim();
                                        tempSkills.add(cleaned);
                                        if (!allSkillsForUI.contains(cleaned)) {
                                          allSkillsForUI.add(cleaned);
                                          allSkillsForUI.sort();
                                        }
                                      });
                                      customSkillCtrl.clear();
                                    }
                                  },
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, children: allSkillsForUI.map((s) => FilterChip(
                              label: Text(s, style: TextStyle(fontSize: 10, color: tempSkills.contains(s) ? Colors.white : Colors.black87)),
                              selected: tempSkills.contains(s),
                              selectedColor: primaryPurple,
                              onSelected: (val) => setStateDialog(() => val ? tempSkills.add(s) : tempSkills.remove(s)),
                            )).toList()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        onPressed: () async {
                          // Validate form before API call
                          if (!_formKey.currentState!.validate()) return;
                          
                          try {
                            final updated = await _userService.updateMe({
                              'name': nameCtrl.text.trim(),
                              'mobile': mobileCtrl.text.trim(),
                              'location': locCtrl.text.trim(),
                              'bankAccountHolderName': holderCtrl.text.trim(),
                              'bankAccountNumber': accNumCtrl.text.trim(),
                              'ifscCode': ifscCtrl.text.trim().toUpperCase(),
                              'skills': tempSkills.toList()
                            });
                            setState(() => _user = updated);
                            Navigator.pop(ctx);
                            _loadProfile();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                        },
                        child: const Text("Save Account Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidatedField(
    TextEditingController ctrl, 
    String label, 
    IconData icon, 
    {String? Function(String?)? validator, 
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
    TextCapitalization caps = TextCapitalization.none}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: type,
        inputFormatters: formatters,
        textCapitalization: caps,
        autovalidateMode: AutovalidateMode.onUserInteraction, // DYNAMIC HIGHLIGHTING
        decoration: InputDecoration(
          labelText: label, 
          prefixIcon: Icon(icon, size: 20, color: primaryPurple),
          isDense: true,
          errorStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _user == null) return const Center(child: CircularProgressIndicator(color: primaryPurple));
    final u = _user;
    if (u == null) return const Center(child: Text("Profile load failed. Pull down to retry."));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false, // REMOVED BACK ARROW
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(onPressed: _handleLogout, icon: const Icon(Icons.logout_rounded, color: Colors.red)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: primaryPurple,
        child: FadeTransition(
          opacity: _animationController,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(u),
              const SizedBox(height: 16),
              _buildDetailsCard(u),
              const SizedBox(height: 16),
              _buildBankCard(u),
              const SizedBox(height: 16),
              _buildSkillsCard(u),
              const SizedBox(height: 16),
              _buildSectionTitle('Recent Performance Feedback'),
              _buildFeedbackList(u),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(User u) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryPurple, secondaryPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _editProfile,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const CircleAvatar(radius: 35, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white, size: 40)),
          const SizedBox(height: 16),
          Text(u.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(u.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(User u) {
    return _profileCard("Contact & Location", primaryPurple, [
      _infoRow(Icons.phone_iphone, "Mobile", u.mobile),
      _infoRow(Icons.location_on_outlined, "Current City", u.location ?? "Not set"),
      _infoRow(Icons.verified_user_outlined, "Account Status", u.isApproved ? "Approved" : "Under Review"),
    ]);
  }

  Widget _buildBankCard(User u) {
    return _profileCard("Bank Account (Payout Info)", Colors.green, [
      _infoRow(Icons.badge_outlined, "A/C Holder", u.bankAccountHolderName.isEmpty ? "Not set" : u.bankAccountHolderName),
      _infoRow(Icons.credit_card, "A/C Number", u.bankAccountNumber.isEmpty ? "Not set" : u.bankAccountNumber),
      _infoRow(Icons.code, "IFSC Code", u.ifscCode.isEmpty ? "Not set" : u.ifscCode),
    ]);
  }

  Widget _buildSkillsCard(User u) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Technical Expertise", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryPurple)),
          const Divider(),
          const SizedBox(height: 8),
          u.skills.isEmpty
              ? const Text("No skills listed. Tap the edit icon to update.", style: TextStyle(color: Colors.grey, fontSize: 12))
              : Wrap(spacing: 8, runSpacing: 8, children: u.skills.map((s) => Chip(
                  label: Text(s, style: const TextStyle(fontSize: 11, color: primaryPurple)),
                  backgroundColor: primaryPurple.withOpacity(0.05),
                )).toList()),
        ],
      ),
    );
  }

  Widget _buildFeedbackList(User u) {
    if (u.feedbackEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
        child: const Center(child: Text("No written reviews yet.", style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }
    return Column(
      children: u.feedbackEntries.map((f) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
        child: ListTile(
          title: Text(f.taskTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(f.comment ?? "Delivered successfully.", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          trailing: Text("${f.rating.toStringAsFixed(0)} ★", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ),
      )).toList(),
    );
  }

  Widget _profileCard(String title, Color color, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const Divider(),
          ...children
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 10), Text("$label:", style: const TextStyle(fontSize: 12, color: Colors.grey)), const Spacer(), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 12, top: 8), child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)));
  }

  Widget _editLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 10, top: 10), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.blueGrey)));
  }
}