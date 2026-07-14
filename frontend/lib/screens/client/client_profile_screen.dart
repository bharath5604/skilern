import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../models/task.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({Key? key}) : super(key: key);

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  User? _user;

  final _companyController = TextEditingController();
  final _locationController = TextEditingController();

  bool _editing = false;
  bool _loading = false;
  bool _loadingDomains = false;

  final TaskService _taskService = TaskService();
  List<String> _domainsFromTasks = [];

  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color backgroundColor = Color(0xFFF5F7FB);
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
    if (_user != null) {
      _companyController.text = _user!.company ?? '';
      _locationController.text = _user!.location ?? '';
      _loadDomainsFromTasks();
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadDomainsFromTasks() async {
    if (_user == null) return;
    setState(() => _loadingDomains = true);
    try {
      // Logic: Extract unique domains from all tasks created by this client
      final List<Task> tasks = await _taskService.getMyTasks();
      final domains = <String>{};
      for (final t in tasks) {
        if (t.domain != null && t.domain!.isNotEmpty) domains.add(t.domain!);
      }

      if (!mounted) return;
      setState(() {
        _domainsFromTasks = domains.toList()..sort();
      });
    } catch (e) {
      debugPrint('Domain load error: $e');
    } finally {
      if (mounted) setState(() => _loadingDomains = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    final tempCompany = _companyController.text.trim();
    final tempLocation = _locationController.text.trim();

    if (tempCompany.isEmpty || tempLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company and location are required')));
      return;
    }

    setState(() => _loading = true);
    try {
      final u = _user!;
      u.company = tempCompany;
      u.location = tempLocation;
      AuthService.currentUser = u;

      if (!mounted) return;
      setState(() { _user = u; _editing = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated'), backgroundColor: primaryPurple));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const Scaffold(body: Center(child: Text('User session not found')));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0, backgroundColor: cardColor,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [primaryPurple, secondaryPurple]).createShader(bounds),
          child: const Text('Account Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white)),
        ),
        actions: [
          if (!_editing) IconButton(icon: const Icon(Icons.edit_note_rounded, color: primaryPurple), onPressed: () => setState(() => _editing = true)),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _headerCard(user),
              const SizedBox(height: 16),
              _companyLocationCard(),
              const SizedBox(height: 16),
              _domainsCard(),
              const SizedBox(height: 16),
              _statusCard(user),
              const SizedBox(height: 24),
              if (_editing) _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard(User user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))]),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: primaryPurple.withOpacity(0.1),
            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryPurple)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark)),
                Text(user.email, style: const TextStyle(fontSize: 13, color: textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyLocationCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryPurple.withOpacity(0.05))),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Organizational Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 16),
          TextField(controller: _companyController, enabled: _editing, decoration: _inputDeco('Company Name', Icons.business)),
          const SizedBox(height: 12),
          TextField(controller: _locationController, enabled: _editing, decoration: _inputDeco('Primary Location', Icons.location_on)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label, prefixIcon: Icon(icon, color: primaryPurple, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primaryPurple.withOpacity(0.1))),
    );
  }

  Widget _domainsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity Domains', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Domains identified from your project requirements.', style: TextStyle(fontSize: 11, color: textMuted)),
          const SizedBox(height: 14),
          if (_loadingDomains) const Center(child: CircularProgressIndicator())
          else if (_domainsFromTasks.isEmpty) const Text('No domains found yet.', style: TextStyle(fontSize: 12, color: textMuted))
          else Wrap(spacing: 8, runSpacing: 8, children: _domainsFromTasks.map((d) => Chip(label: Text(d, style: const TextStyle(fontSize: 11)), backgroundColor: primaryPurple.withOpacity(0.05))).toList()),
        ],
      ),
    );
  }

  Widget _statusCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Account Status', style: TextStyle(fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: user.isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(user.isApproved ? 'Approved' : 'Pending Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: user.isApproved ? Colors.green : Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: _loading 
        ? const Center(child: CircularProgressIndicator()) 
        : ElevatedButton(
            onPressed: _saveProfile,
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            child: const Text('Save Account Changes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
    );
  }
}