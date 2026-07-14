import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/stats_service.dart';
import '../../services/task_service.dart';
import '../../constants/domains.dart';

// =============================================================================
// NEW: SEPARATE POLICY PAGE (For Google Play URL Compliance)
// =============================================================================
class PolicyPage extends StatelessWidget {
  final String title;
  final String content;

  const PolicyPage({Key? key, required this.title, required this.content}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF6A11CB)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F7FB),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6A11CB))),
                const SizedBox(height: 8),
                const Text("Last updated: July 9, 2026", style: TextStyle(color: Colors.grey, fontSize: 11)),
                const Divider(height: 40),
                Text(
                  content,
                  style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color lightPurple = Color(0xFFF3E8FF);
  static const Color deepBg = Color(0xFF1A1A2E); 

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _bounceController;
  late final AnimationController _glowController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _bounceAnimation;
  late final Animation<double> _glowAnimation;

  final StatsService _statsService = StatsService();
  final TaskService _taskService = TaskService();

  Map<String, dynamic>? _stats;
  bool _statsLoading = true;

  final List<String> _baseSkills = [
    'Flutter', 'React', 'Node.js', 'Python', 'Java',
    'Machine Learning', 'Data Science', 'UI/UX Design', 'Databases',
  ];

  List<Map<String, dynamic>> get _statsList => [
    {
      'label': 'Students',
      'value': _stats != null ? '${_stats!['students']}' : '--',
      'icon': Icons.school_outlined,
      'color': const Color(0xFF6A11CB),
      'bgColor': const Color(0xFFF3E8FF),
    },
    {
      'label': 'Clients',
      'value': _stats != null ? '${_stats!['clients']}' : '--',
      'icon': Icons.business_center_outlined,
      'color': const Color(0xFF2575FC),
      'bgColor': const Color(0xFFEFF6FF),
    },
    {
      'label': 'Active Tasks',
      'value': _stats != null ? '${_stats!['Tasks']}' : '--',
      'icon': Icons.assignment_outlined,
      'color': const Color(0xFF059669),
      'bgColor': const Color(0xFFECFDF5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _bounceController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _glowController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _bounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut));
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine));

    _fadeController.forward();
    _slideController.forward();
    _bounceController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);

    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final s = await _statsService.getStats();
      if (!mounted) return;
      setState(() {
        _stats = {'students': s['students'] ?? 0, 'clients': s['clients'] ?? 0, 'Tasks': s['tasks'] ?? 0};
        _statsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  void _showGuestTaskSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final deadlineCtrl = TextEditingController();
    final Set<String> selectedSkills = {};
    
    final List<String> sessionDomains = List.from(kSkilernDomains);
    String? selectedDomain;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                const Text("Emergency Task Post", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryPurple)),
                const Text("Fill details for direct student matching by Admin.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 24),

                _formField(titleCtrl, "Task Title", Icons.title),
                _formField(descCtrl, "Deliverables & Description", Icons.description, maxLines: 3),

                Row(
                  children: [
                    Expanded(child: _formField(nameCtrl, "Your Name", Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(child: _formField(mobileCtrl, "WhatsApp/Mobile", Icons.phone, keyboard: TextInputType.phone)),
                  ],
                ),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedDomain,
                        isExpanded: true,
                        decoration: _inputDeco("Select Domain", Icons.category_outlined),
                        items: sessionDomains.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setSheetState(() => selectedDomain = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: primaryPurple, size: 36),
                      onPressed: () => _showAddCustomDomainDialog(setSheetState, sessionDomains, (val) => selectedDomain = val),
                      tooltip: 'Add Custom Domain',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text("Required Skills (Help us match the right talent)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryPurple)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: _baseSkills.map((skill) {
                    final isSelected = selectedSkills.contains(skill);
                    return ChoiceChip(
                      label: Text(skill, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      selectedColor: primaryPurple,
                      onSelected: (val) => setSheetState(() => val ? selectedSkills.add(skill) : selectedSkills.remove(skill)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: deadlineCtrl,
                  readOnly: true,
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) deadlineCtrl.text = DateFormat('yyyy-MM-dd').format(d);
                  },
                  decoration: _inputDeco("Deadline", Icons.calendar_today),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: isSubmitting ? null : () async {
                      if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty || nameCtrl.text.isEmpty || mobileCtrl.text.isEmpty || deadlineCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all mandatory fields")));
                        return;
                      }
                      setSheetState(() => isSubmitting = true);
                      try {
                        await _taskService.createGuestTask(
                          title: titleCtrl.text,
                          description: descCtrl.text,
                          guestName: nameCtrl.text,
                          guestMobile: mobileCtrl.text,
                          deadline: deadlineCtrl.text,
                          domain: selectedDomain,
                          requiredSkills: selectedSkills.toList(),
                        );
                        Navigator.pop(ctx);
                        _showSuccessDialog();
                      } catch (e) {
                        setSheetState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Match with Student", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCustomDomainDialog(StateSetter setSheetState, List<String> sessionDomains, Function(String) onAdded) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Custom Domain"), content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "e.g. Graphic Design"), autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () { if (ctrl.text.isNotEmpty) { setSheetState(() { if (!sessionDomains.contains(ctrl.text.trim())) sessionDomains.add(ctrl.text.trim()); onAdded(ctrl.text.trim()); }); Navigator.pop(ctx); } }, child: const Text("Add"))]));
  }

  void _addCustomSkill(StateSetter setSheetState, Set<String> selectedSkills) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Custom Skill"), content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "e.g. SEO")), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () { if (ctrl.text.isNotEmpty) setSheetState(() => selectedSkills.add(ctrl.text.trim())); Navigator.pop(ctx); }, child: const Text("Add"))]));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: const Text("Request Received! Our Admin will contact you shortly.", textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Got it"))],
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: _inputDeco(hint, icon),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint, prefixIcon: Icon(icon, color: primaryPurple, size: 20),
      filled: true, fillColor: Colors.grey[50], hintStyle: const TextStyle(fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
    );
  }

  // ============================================================
  // COMPLIANCE FOOTER Logic (Finalized for Google Play)
  // ============================================================
  Widget _buildComplianceFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      color: deepBg,
      child: Column(
        children: [
          const Text("SKILERN by KRR Innovations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Text("Managed student marketplace connecting businesses with university expertise.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
          const SizedBox(height: 32),
          
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24, runSpacing: 16,
            children: [
              _footerLink("Privacy Policy", _privacyContent),
              _footerLink("Terms & Conditions", _termsContent),
              _footerLink("Refund Policy", _refundContent),
              _footerLink("Delivery Policy", _deliveryContent),
            ],
          ),
          
          const SizedBox(height: 40),
          const Divider(color: Colors.white10, thickness: 1),
          const SizedBox(height: 24),
          const Text("© 2024 KRR Innovations. All rights reserved.", style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          const Text("Support: skilernapp@gmail.com\nRegistered Address: Vijayawada, Andhra Pradesh, India", textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 10, height: 1.6)),
        ],
      ),
    );
  }

  Widget _footerLink(String label, String content) {
    return InkWell(
      onTap: () {
        // This opens the specific policy in a new full-screen internal page
        Navigator.push(context, MaterialPageRoute(builder: (_) => PolicyPage(title: label, content: content)));
      },
      child: Text(label, style: const TextStyle(color: secondaryPurple, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose(); _slideController.dispose(); _bounceController.dispose();
    _glowController.dispose(); _pulseController.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.grey.shade50, Colors.white, lightPurple.withOpacity(0.2)])),
        child: SafeArea(
          child: Column(
            children: [
              _AnimatedAppBar(onEmergencyPost: _showGuestTaskSheet),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeroSliderSection(fadeAnim: _fadeAnimation, slideAnim: _slideAnimation, isDesktop: isDesktop),
                            const SizedBox(height: 36),
                            _SectionTitle(title: 'Platform Activity'),
                            const SizedBox(height: 16),
                            _InteractiveStatsSection(statsLoading: _statsLoading, statsList: _statsList, isDesktop: isDesktop),
                            const SizedBox(height: 36),
                            _SectionTitle(title: 'How It Works'),
                            const SizedBox(height: 20),
                            _InteractiveWorkflowSection(isDesktop: isDesktop),
                            const SizedBox(height: 60),
                            _AnimatedBottomCTA(glowAnim: _glowAnimation, bounceAnim: _bounceAnimation, onTap: _showGuestTaskSheet),
                            const SizedBox(height: 48),
                            _SectionTitle(title: 'Contact Us'),
                            const SizedBox(height: 20),
                            const _ContactSection(),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                      _buildComplianceFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// LEGAL CONTENT (BASED ON YOUR DOCUMENTS)
// =============================================================================

const String _privacyContent = """
Privacy Policy
Last updated: July 9, 2026

At Skilern, we take your privacy seriously. We only collect the information we actually need to make the platform work for you, and we promise to treat your data with respect.

1. What We Collect
- When you sign up: We ask for basics like your name, email, phone number, and (if you are a Student) what skills you have.
- When you use "Emergency Work": Even if you don't create an account, we need an email or phone number so we can actually send you the finished work.
- When you pay or get paid: We collect necessary billing and payment details to make sure transactions go through smoothly.

2. Why We Need It
We use data to help our Admins figure out which Student is the perfect match for a Client's task, send you notifications, and process payments securely.

3. Sharing
We do not sell your personal data to anyone. Information is shared only between the assigned Student and Client for a specific task to facilitate communication.
""";

const String _termsContent = """
Terms and Conditions
Last updated: July 9, 2026

Welcome to Skilern! These are the ground rules for using our website (https://skilern.com/) and app. By using Skilern, you are agreeing to these terms.

1. Who Does What?
- Clients: You need something done. You post the task.
- Students: You have the skills. You complete the tasks.
- Admins (That’s us!): We work behind the scenes to match Clients with the perfect Student for the job and make sure everyone gets what they need safely.

2. How Skilern Works
Step 1: Clients post what they need (including "Emergency Work").
Step 2: Admins review the task and assign it to a Student.
Step 3: The Student does the work. Once finished, the Client gets to preview it.
Step 4: If the Client likes the work, they approve it and make the payment to Skilern.
Step 5: Deliverables are released for download.
Step 6: Admins transfer payment to the Student.

3. Playing by the Rules
We want Skilern to be a great place for everyone. Be honest, be on time, and do your own work. Copying someone else’s work (plagiarism) is strictly forbidden.
""";

const String _refundContent = """
Refund Policy
Last updated: July 9, 2026

Nobody likes a messy refund process, so we built Skilern to avoid it entirely.

1. The "See It First" Guarantee
When you post a task on Skilern, it costs nothing. When the Student finishes the work, you get to preview it. If it’s not what you asked for, you can reject it or ask for changes—all without paying a single rupee.

2. When We DO Give Refunds
Technology isn't perfect. You are eligible for a refund if:
- You were charged twice: If a computer glitch bills you two times for one project, we will refund the extra charge immediately.
- The file is broken: If you pay and the file is completely corrupted, blank, or broken—and our team cannot get you a working copy within 48 hours—we will give you your money back.

3. Finality
Because you only pay after you have reviewed the work and explicitly said "Yes, I approve this," we do not offer standard refunds once a payment is made and the file is downloaded.
""";

const String _deliveryContent = """
Shipping & Delivery Policy

1. Digital Delivery
All deliverables on Skilern are digital services. No physical shipping is required.

2. Accessing Files
Once the Client approves the deliverables and completes the payment, unwatermarked files will be available for instant download directly in the user dashboard.

3. Delivery Timeline
Timelines for project completion are agreed upon during the assignment phase between the Admin and the matched Student.
""";

// =============================================================================
// SUB-COMPONENTS (PRESERVED ORIGINAL LOGIC)
// =============================================================================

class _InteractiveStatsSection extends StatefulWidget {
  final bool statsLoading; final List<Map<String, dynamic>> statsList; final bool isDesktop;
  const _InteractiveStatsSection({required this.statsLoading, required this.statsList, required this.isDesktop});
  @override State<_InteractiveStatsSection> createState() => _InteractiveStatsSectionState();
}
class _InteractiveStatsSectionState extends State<_InteractiveStatsSection> with TickerProviderStateMixin {
  late List<AnimationController> _controllers; late List<Animation<double>> _scaleAnims; late List<Animation<double>> _fadeAnims;
  @override void initState() { super.initState(); _controllers = List.generate(3, (i) => AnimationController(vsync: this, duration: Duration(milliseconds: 400 + i * 120))); _scaleAnims = _controllers.map((c) => Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut))).toList(); _fadeAnims = _controllers.map((c) => Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.easeOut))).toList(); if (!widget.statsLoading) _playAll(); }
  void _playAll() { for (int i = 0; i < _controllers.length; i++) { Future.delayed(Duration(milliseconds: i * 100), () { if (mounted) _controllers[i].forward(); }); } }
  @override void dispose() { for (final c in _controllers) c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { if (widget.statsLoading) return const Center(child: CircularProgressIndicator()); return Row(children: List.generate(widget.statsList.length, (i) { final stat = widget.statsList[i]; return Expanded(child: Padding(padding: EdgeInsets.only(right: i < 2 ? 12 : 0), child: ScaleTransition(scale: _scaleAnims[i], child: FadeTransition(opacity: _fadeAnims[i], child: _StatTile(label: stat['label'], value: stat['value'], icon: stat['icon'], color: stat['color'], bgColor: stat['bgColor']))))); })); }
}
class _StatTile extends StatelessWidget {
  final String label, value; final IconData icon; final Color color, bgColor;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color, required this.bgColor});
  @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!), boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4))]), child: Column(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 22)), const SizedBox(height: 10), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))])); }
}
class _InteractiveWorkflowSection extends StatefulWidget {
  final bool isDesktop; const _InteractiveWorkflowSection({required this.isDesktop});
  @override State<_InteractiveWorkflowSection> createState() => _InteractiveWorkflowSectionState();
}
class _InteractiveWorkflowSectionState extends State<_InteractiveWorkflowSection> with TickerProviderStateMixin {
  int _activeStep = 0; late AnimationController _pulseCtrl; late Animation<double> _pulseAnim;
  static const List<Map<String, dynamic>> _steps = [
    {'icon': Icons.edit_note_rounded, 'title': 'Post Request', 'desc': 'Easy Flow', 'detail': 'Describe your task and set a deadline. No account needed for emergency posts.', 'color': Color(0xFF6A11CB), 'bgColor': Color(0xFFF3E8FF), 'step': '01'},
    {'icon': Icons.person_search_rounded, 'title': 'Admin Match', 'desc': 'Vetting', 'detail': 'Admin reviews requirements and hand-picks the best-fit student based on skills.', 'color': Color(0xFF2575FC), 'bgColor': Color(0xFFEFF6FF), 'step': '02'},
    {'icon': Icons.task_alt_rounded, 'title': 'Approve Work', 'desc': 'Review', 'detail': 'Review all deliverables in one place. Only approve when you are 100% satisfied.', 'color': Color(0xFF059669), 'bgColor': Color(0xFFECFDF5), 'step': '03'},
    {'icon': Icons.qr_code_2_rounded, 'title': 'Direct Payout', 'desc': 'Verified', 'detail': 'Payment is released directly to the student — zero middleman fees, fully admin-verified.', 'color': Color(0xFFD97706), 'bgColor': Color(0xFFFFFBEB), 'step': '04'},
  ];
  @override void initState() { super.initState(); _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900)); _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut)); _pulseCtrl.repeat(reverse: true); }
  @override void dispose() { _pulseCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { final active = _steps[_activeStep]; return Column(children: [Row(children: List.generate(_steps.length, (i) => Expanded(child: GestureDetector(onTap: () => setState(() => _activeStep = i), child: AnimatedContainer(duration: const Duration(milliseconds: 280), margin: EdgeInsets.only(right: i < 3 ? 8 : 0), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: i == _activeStep ? active['color'] : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Column(children: [Icon(_steps[i]['icon'], color: i == _activeStep ? Colors.white : _steps[i]['color'], size: 20), const SizedBox(height: 6), Text(_steps[i]['title'], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))])))))), const SizedBox(height: 16), Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: active['bgColor'], borderRadius: BorderRadius.circular(20), border: Border.all(color: (active['color'] as Color).withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(active['title'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: active['color'])), const SizedBox(height: 6), Text(active['detail'], style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5))]))]); }
}
class _HeroSliderSection extends StatelessWidget {
  final Animation<double> fadeAnim; final Animation<Offset> slideAnim; final bool isDesktop;
  const _HeroSliderSection({required this.fadeAnim, required this.slideAnim, required this.isDesktop});
  @override build(BuildContext context) { return FadeTransition(opacity: fadeAnim, child: SlideTransition(position: slideAnim, child: Container(height: isDesktop ? 300 : 200, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF6A11CB)])), child: const Center(child: Text("Managed Student Talent Marketplace", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)))))); }
}
class _AnimatedAppBar extends StatelessWidget {
  final VoidCallback onEmergencyPost; const _AnimatedAppBar({required this.onEmergencyPost});
  @override build(BuildContext context) { return Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Row(children: [const Text('SKILERN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF6A11CB))), const Spacer(), TextButton(onPressed: onEmergencyPost, child: const Text('Emergency Post', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))), const SizedBox(width: 8), ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/login'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB)), child: const Text('Sign In', style: TextStyle(color: Colors.white)))])); }
}
class _ContactSection extends StatelessWidget {
  const _ContactSection();
  @override build(BuildContext context) { return Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE9D5FF))), child: Column(children: [const Text("We'd love to hear from you", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text("skilernapp@gmail.com", style: TextStyle(color: Color(0xFF6A11CB), fontWeight: FontWeight.bold))])); }
}
class _AnimatedBottomCTA extends StatelessWidget {
  final Animation<double> glowAnim; final Animation<double> bounceAnim; final VoidCallback onTap;
  const _AnimatedBottomCTA({required this.glowAnim, required this.bounceAnim, required this.onTap});
  @override build(BuildContext context) { return ScaleTransition(scale: bounceAnim, child: ElevatedButton.icon(onPressed: onTap, icon: const Icon(Icons.bolt, color: Colors.white), label: const Text("Submit Emergency Task", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))))); }
}
class _SectionTitle extends StatelessWidget {
  final String title; const _SectionTitle({required this.title});
  @override build(BuildContext context) { return Row(children: [Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF6A11CB), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 12), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]); }
}