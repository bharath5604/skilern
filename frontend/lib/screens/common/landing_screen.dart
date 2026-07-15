import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/stats_service.dart';
import '../../services/task_service.dart';
import '../../constants/domains.dart';

// =============================================================================
// POLICY DISPLAY PAGE (For Legal Compliance)
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
        centerTitle: true,
        title: Text(title, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
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
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF6A11CB))),
                const SizedBox(height: 8),
                const Text("Last updated: July 9, 2026", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const Divider(height: 40),
                Text(content, style: const TextStyle(fontSize: 15, height: 1.8, color: Colors.black87)),
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
      'value': _stats != null ? '${_stats!['tasks']}' : '--', // FIXED: Consistency check
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
        _stats = {'students': s['students'] ?? 0, 'clients': s['clients'] ?? 0, 'tasks': s['tasks'] ?? 0};
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
                _formField(titleCtrl, "Task Title (e.g. Website Bug Fix)", Icons.title),
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
                const Text("Required Skills", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryPurple)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
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
                TextButton.icon(onPressed: () => _addCustomSkill(setSheetState, selectedSkills), icon: const Icon(Icons.add, size: 16), label: const Text("Add Other Skill", style: TextStyle(fontSize: 12))),
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
                        await _taskService.createGuestTask(title: titleCtrl.text, description: descCtrl.text, guestName: nameCtrl.text, guestMobile: mobileCtrl.text, deadline: deadlineCtrl.text, domain: selectedDomain, requiredSkills: selectedSkills.toList());
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
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Icon(Icons.check_circle, color: Colors.green, size: 50), content: const Text("Request Received! Admin will contact you shortly.", textAlign: TextAlign.center), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Got it"))]));
  }

  Widget _formField(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(controller: ctrl, maxLines: maxLines, keyboardType: keyboard, decoration: _inputDeco(hint, icon)));
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: primaryPurple, size: 20), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)));
  }

  Widget _buildComplianceFooter() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24), color: deepBg,
      child: Column(children: [
        const Text("SKILERN by KRR Innovations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        const Text("Managed student marketplace connecting businesses with university expertise.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
        const SizedBox(height: 32),
        Wrap(alignment: WrapAlignment.center, spacing: 24, runSpacing: 16, children: [
          _footerLink("Privacy Policy", _privacyContent),
          _footerLink("Terms & Conditions", _termsContent),
          _footerLink("Refund Policy", _refundContent),
          _footerLink("Contact Us", "krrinnovations@gmail.com"),
        ]),
        const SizedBox(height: 40),
        const Divider(color: Colors.white10, thickness: 1),
        const SizedBox(height: 24),
        const Text("© 2024 KRR Innovations. All rights reserved.", style: TextStyle(color: Colors.white30, fontSize: 11)),
        const Text("Registered Address: Vijayawada, Andhra Pradesh, India", textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 10, height: 1.6)),
      ]),
    );
  }

  Widget _footerLink(String label, String content) {
    return InkWell(
      onTap: label == "Contact Us" 
          ? null 
          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PolicyPage(title: label, content: content))),
      child: Text(label, style: const TextStyle(color: secondaryPurple, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose(); _slideController.dispose(); _bounceController.dispose(); _glowController.dispose(); _pulseController.dispose(); super.dispose();
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
// ANIMATED SUB-COMPONENTS (RESTORED FROM CODE 1)
// =============================================================================

class _InteractiveStatsSection extends StatefulWidget {
  final bool statsLoading; final List<Map<String, dynamic>> statsList; final bool isDesktop;
  const _InteractiveStatsSection({required this.statsLoading, required this.statsList, required this.isDesktop});
  @override State<_InteractiveStatsSection> createState() => _InteractiveStatsSectionState();
}
class _InteractiveStatsSectionState extends State<_InteractiveStatsSection> with TickerProviderStateMixin {
  late List<AnimationController> _controllers; late List<Animation<double>> _scaleAnims;
  @override void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(vsync: this, duration: Duration(milliseconds: 400 + i * 120)));
    _scaleAnims = _controllers.map((c) => Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut))).toList();
    if (!widget.statsLoading) _play();
  }
  void _play() { for (int i = 0; i < _controllers.length; i++) { Future.delayed(Duration(milliseconds: i * 100), () { if (mounted) _controllers[i].forward(); }); } }
  @override void dispose() { for (final c in _controllers) c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (widget.statsLoading) return const Center(child: CircularProgressIndicator());
    return Row(children: List.generate(widget.statsList.length, (i) => Expanded(child: Padding(padding: EdgeInsets.only(right: i < 2 ? 12 : 0), child: ScaleTransition(scale: _scaleAnims[i], child: _StatTile(label: widget.statsList[i]['label'], value: widget.statsList[i]['value'], icon: widget.statsList[i]['icon'], color: widget.statsList[i]['color'], bgColor: widget.statsList[i]['bgColor']))))));
  }
}

class _StatTile extends StatefulWidget {
  final String label, value; final IconData icon; final Color color, bgColor;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color, required this.bgColor});
  @override State<_StatTile> createState() => _StatTileState();
}
class _StatTileState extends State<_StatTile> {
  bool _pressed = false;
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true), onTapUp: (_) => setState(() => _pressed = false), onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(color: _pressed ? widget.bgColor : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4))]),
        child: Column(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: widget.bgColor, borderRadius: BorderRadius.circular(13)), child: Icon(widget.icon, color: widget.color, size: 22)), const SizedBox(height: 10), Text(widget.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)), Text(widget.label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))]),
      ),
    );
  }
}

class _InteractiveWorkflowSection extends StatefulWidget {
  final bool isDesktop; const _InteractiveWorkflowSection({required this.isDesktop});
  @override State<_InteractiveWorkflowSection> createState() => _InteractiveWorkflowSectionState();
}
class _InteractiveWorkflowSectionState extends State<_InteractiveWorkflowSection> {
  int _activeStep = 0;
  static const List<Map<String, dynamic>> _steps = [
    {'icon': Icons.edit_note_rounded, 'title': 'Post Request', 'desc': 'Emergency or Logged-in', 'detail': 'Step 1: Ask for help. Clients post what they need. Use "Emergency Work" to submit without an account.', 'color': Color(0xFF6A11CB), 'bgColor': Color(0xFFF3E8FF), 'step': '01'},
    {'icon': Icons.person_search_rounded, 'title': 'Admin Match', 'desc': 'Fast vetting', 'detail': 'Step 2: The Matchmaker. Admins review and assign a Student with the right skills to get it done well.', 'color': Color(0xFF2575FC), 'bgColor': Color(0xFFEFF6FF), 'step': '02'},
    {'icon': Icons.task_alt_rounded, 'title': 'Approve Work', 'desc': 'Review preview', 'detail': 'Step 3 & 4: Preview and Pay. Client previews work first. If satisfied, they approve and make payment.', 'color': Color(0xFF059669), 'bgColor': Color(0xFFECFDF5), 'step': '03'},
    {'icon': Icons.qr_code_2_rounded, 'title': 'Payout', 'desc': 'Verified', 'detail': 'Step 5 & 6: Delivery and Payday. Client downloads unwatermarked files; Student receives agreed-upon payment.', 'color': Color(0xFFD97706), 'bgColor': Color(0xFFFFFBEB), 'step': '04'},
  ];
  @override Widget build(BuildContext context) {
    final active = _steps[_activeStep];
    return Column(children: [
      Row(children: List.generate(_steps.length, (i) => Expanded(child: GestureDetector(onTap: () => setState(() => _activeStep = i), child: AnimatedContainer(duration: const Duration(milliseconds: 280), margin: EdgeInsets.only(right: i < 3 ? 8 : 0), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: i == _activeStep ? _steps[i]['color'] : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Column(children: [Icon(_steps[i]['icon'], color: i == _activeStep ? Colors.white : _steps[i]['color'], size: 22), const SizedBox(height: 6), Text(_steps[i]['title'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: i == _activeStep ? Colors.white : Colors.black87), textAlign: TextAlign.center)])))))),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(20), width: double.infinity, decoration: BoxDecoration(color: active['bgColor'], borderRadius: BorderRadius.circular(20), border: Border.all(color: (active['color'] as Color).withOpacity(0.2))), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: active['color'], borderRadius: BorderRadius.circular(14)), child: Center(child: Text(active['step'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(active['title'], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: active['color'])), const SizedBox(height: 4), Text(active['detail'], style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4))]))])),
    ]);
  }
}

class _HeroSliderSection extends StatefulWidget {
  final Animation<double> fadeAnim; final Animation<Offset> slideAnim; final bool isDesktop;
  const _HeroSliderSection({required this.fadeAnim, required this.slideAnim, required this.isDesktop});
  @override State<_HeroSliderSection> createState() => _HeroSliderSectionState();
}
class _HeroSliderSectionState extends State<_HeroSliderSection> {
  final List<Map<String, dynamic>> _slides = [
    {'imageUrl': 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800&q=80', 'tag': 'Talent Network', 'headline': 'Vetted Student Talent,\nAssigned Directly.'},
    {'imageUrl': 'https://images.unsplash.com/photo-1531482615713-2afd69097998?w=800&q=80', 'tag': 'Fast Matching', 'headline': 'Post a Task.\nGet Matched in Hours.'},
    {'imageUrl': 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=800&q=80', 'tag': 'Quality Work', 'headline': 'Review Deliverables.\nPay Only on Approval.'},
  ];
  int _currentIndex = 0; late PageController _pageController; Timer? _timer;
  @override void initState() { super.initState(); _pageController = PageController(); _timer = Timer.periodic(const Duration(seconds: 4), (_) { if (mounted) { _currentIndex = (_currentIndex + 1) % _slides.length; _pageController.animateToPage(_currentIndex, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic); } }); }
  @override void dispose() { _timer?.cancel(); _pageController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return FadeTransition(opacity: widget.fadeAnim, child: SlideTransition(position: widget.slideAnim, child: Column(children: [ClipRRect(borderRadius: BorderRadius.circular(24), child: SizedBox(height: widget.isDesktop ? 340 : 260, child: PageView.builder(controller: _pageController, itemCount: _slides.length, onPageChanged: (i) => setState(() => _currentIndex = i), itemBuilder: (context, index) => Stack(fit: StackFit.expand, children: [Image.network(_slides[index]['imageUrl'], fit: BoxFit.cover), Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black87, Colors.transparent], stops: [0.1, 0.8]))), Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(_slides[index]['tag'], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))), const SizedBox(height: 12), Text(_slides[index]['headline'], style: TextStyle(color: Colors.white, fontSize: widget.isDesktop ? 32 : 24, fontWeight: FontWeight.w900))]))])))), const SizedBox(height: 14), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_slides.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), width: i == _currentIndex ? 24 : 8, height: 8, decoration: BoxDecoration(color: i == _currentIndex ? _LandingScreenState.primaryPurple : _LandingScreenState.primaryPurple.withOpacity(0.25), borderRadius: BorderRadius.circular(4)))))])));
  }
}

class _AnimatedAppBar extends StatelessWidget {
  final VoidCallback onEmergencyPost; const _AnimatedAppBar({required this.onEmergencyPost});
  @override Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Row(children: [RichText(text: const TextSpan(children: [TextSpan(text: 'SKI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF6A11CB))), TextSpan(text: 'LERN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2575FC)))])), const Spacer(), TextButton(onPressed: onEmergencyPost, child: const Text('Emergency Post', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))), const SizedBox(width: 8), ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/login'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Sign In', style: TextStyle(color: Colors.white)))]));
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection();
  static const String _contactEmail = 'krrinnovations@gmail.com';
  Future<void> _openGmail(BuildContext context) async { final Uri mailtoUri = Uri.parse('mailto:$_contactEmail?subject=Hello from SKILERN'); if (await canLaunchUrl(mailtoUri)) await launchUrl(mailtoUri); else { await Clipboard.setData(const ClipboardData(text: _contactEmail)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied to clipboard!'))); } }
  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE9D5FF))),
      child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]), borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: const Text('We\'d love to hear from you', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        Padding(padding: const EdgeInsets.all(20), child: Column(children: [_ContactActionCard(icon: Icons.send_rounded, title: 'Send us a message', subtitle: _contactEmail, onTap: () => _openGmail(context)), const SizedBox(height: 12), _ContactActionCard(icon: Icons.copy_rounded, title: 'Copy email address', subtitle: 'Paste it anywhere', onTap: () async { await Clipboard.setData(const ClipboardData(text: _contactEmail)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied!'))); })]))
      ]),
    );
  }
}

class _ContactActionCard extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _ContactActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override Widget build(BuildContext context) { return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: const Color(0xFF6A11CB)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))])]))); }
}

class _AnimatedBottomCTA extends StatelessWidget {
  final Animation<double> glowAnim, bounceAnim; final VoidCallback onTap;
  const _AnimatedBottomCTA({required this.glowAnim, required this.bounceAnim, required this.onTap});
  @override Widget build(BuildContext context) { return AnimatedBuilder(animation: glowAnim, builder: (context, child) => Container(decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF6A11CB).withOpacity(0.3 * glowAnim.value), blurRadius: 40 * glowAnim.value)]), child: Center(child: ScaleTransition(scale: bounceAnim, child: ElevatedButton.icon(onPressed: onTap, icon: const Icon(Icons.bolt, color: Colors.white), label: const Text("Submit Emergency Task", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)))))))); }
}

class _SectionTitle extends StatelessWidget {
  final String title; const _SectionTitle({required this.title});
  @override Widget build(BuildContext context) { return Row(children: [Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF6A11CB), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 12), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))]); }
}

// =============================================================================
// LEGAL CONTENT (FROM OCR)
// =============================================================================

const String _privacyContent = """
1. What We Collect
- When you sign up: Name, email, phone number, and skills.
- When you use "Emergency Work": Email or phone number for delivery.
- When you pay or get paid: Necessary billing and payment details.

2. Why We Need It
- To help Admins match Students with Client tasks.
- To send notifications regarding task progress.
- To process payments securely.

3. Who Sees Your Information?
We do not sell your personal data. Personal info is used by the Admin team. Profile identity (like your name) is shared with the person you are working with.

4. Keeping It Safe
We use industry-standard security to protect payment info and files. While no website can promise 100% security, we do everything in our power to keep your data locked down.
""";

const String _termsContent = """
1. Who Does What?
- Clients: Post the task.
- Students: Complete the task.
- Admins: Match Clients with the perfect Student and ensure safety.

2. How Skilern Works (Step-by-Step)
Step 1: Ask for help (including Emergency Work).
Step 2: The Matchmaker assignments.
Step 3: The Preview (See exactly what you pay for).
Step 4: Approval and Payment to Skilern.
Step 5: Delivery of final unwatermarked files.
Step 6: Payday to the Student.

3. Playing by the Rules
- Clients must provide clear instructions.
- Students must be honest and avoid plagiarism.
- Everyone must process payments through the Skilern platform.

4. Who Owns the Work?
Once a Client pays and downloads the work, it belongs to them.

5. Limitation of Liability
Skilern is not legally responsible for project delays or disagreements, but we resolve issues fairly.

6. Legal Jurisdiction
Disputes are handled according to the laws of Andhra Pradesh, India, in the courts of Vijayawada.
""";

const String _refundContent = """
1. The "See It First" Guarantee
Clients only pay after reviewing the preview. If not satisfied, reject or ask for changes without paying. We do not offer refunds once payment is made and the file is downloaded.

2. When We DO Give Refunds
- Double charges due to technical glitches.
- Broken files (corrupted/blank) that cannot be fixed within 48 hours.

3. What Doesn't Qualify
- Changing your mind after approval and download.
- Deciding you don't like the work after approval.
- Emergency Tasks once approved.

4. How to Fix a Glitch
Contact support with your Task ID. Verification leads to a refund within 7 to 10 business days.
""";