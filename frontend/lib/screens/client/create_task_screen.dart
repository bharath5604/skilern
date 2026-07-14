import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
// REMOVED: import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/domains.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../services/file_service.dart'; // MODIFICATION: IMPORT VPS FILE SERVICE
import '../../models/task.dart' as models;

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({Key? key}) : super(key: key);

  @override
  State<CreateTaskScreen> createState() => CreateTaskScreenState();
}

class CreateTaskScreenState extends State<CreateTaskScreen> {
  // ============================================================
  // FORM & CONTROLLERS
  // ============================================================
  final _formKey = GlobalKey<FormState>(); 

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  // MODIFICATION: Removed _budgetController
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final TaskService _taskService = TaskService();

  bool _loading = false;
  bool _loadingDomains = false;
  bool _hasAcceptedTermsForCurrentSubmission = false;
  bool _showSkillError = false; 

  // Edit Mode Variables
  bool _isEditing = false;
  String? _editingTaskId;
  List<String> _existingUrls = [];
  List<String> _existingNames = [];

  final List<String> _allSkills = [
    'Flutter', 'React', 'Node.js', 'Python', 'Java', 'Machine Learning',
    'Data Science', 'UI/UX Design', 'HTML', 'CSS', 'Javascript', 'DevOps',
    'Databases', 'Drawing', 'Editing', 'Writing', 'Bug Fixing'
  ];

  List<String> _dynamicDomains = [];
  final List<PlatformFile> _pickedFiles = [];
  final List<String> _selectedSkills = [];
  String? _selectedDomain;

  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const int _maxFileSizeBytes = 15 * 1024 * 1024; // Updated to 15MB
  static const int _maxFiles = 5;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    final location = _extractUserLocation(user);
    _locationController.text = location.isNotEmpty ? location : 'Vijayawada';
    _allSkills.sort();
    _fetchDomains();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Object? rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs is Map && rawArgs.containsKey('task') && !_isEditing) {
      final taskData = rawArgs['task'];
      if (taskData is models.Task) {
        _isEditing = true;
        _editingTaskId = taskData.id;
        _titleController.text = taskData.title;
        _descController.text = taskData.description;
        // MODIFICATION: Budget is not populated here anymore
        _deadlineController.text = taskData.deadline ?? '';
        _locationController.text = taskData.location ?? '';
        _selectedDomain = taskData.domain;
        _selectedSkills.clear();
        _selectedSkills.addAll(taskData.requiredSkills);
        _existingUrls = List.from(taskData.attachments);
        _existingNames = List.from(taskData.attachmentNames);
      }
    }
  }

  Future<void> _fetchDomains() async {
    setState(() => _loadingDomains = true);
    try {
      final list = await _taskService.getExistingDomains();
      setState(() {
        _dynamicDomains = {...kSkilernDomains, ...list}.toList()..sort();
      });
    } catch (e) {
      setState(() => _dynamicDomains = List.from(kSkilernDomains)..sort());
    } finally {
      setState(() => _loadingDomains = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _deadlineController.dispose();
    _locationController.dispose();
    _taskService.dispose();
    super.dispose();
  }

  String _extractUserLocation(dynamic user) {
    try {
      final dynamic raw = user?.location;
      if (raw == null) return '';
      return raw.toString().trim();
    } catch (_) { return ''; }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      _deadlineController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  void _addSkillToProject(String rawSkill) {
    if (rawSkill.trim().isEmpty) return;
    String cleaned = rawSkill.trim().split(' ').map((str) {
      if (str.isEmpty) return "";
      return str[0].toUpperCase() + str.substring(1).toLowerCase();
    }).join(' ');

    setState(() {
      if (!_selectedSkills.contains(cleaned)) {
        _selectedSkills.add(cleaned);
        _showSkillError = false;
      }
      if (!_allSkills.contains(cleaned)) {
        _allSkills.add(cleaned);
        _allSkills.sort();
      }
    });
  }

  void _showAddCustomDomainDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Custom Domain', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Video Editing, Architecture'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
            onPressed: () {
              final domain = ctrl.text.trim();
              if (domain.isNotEmpty) {
                setState(() {
                  if (!_dynamicDomains.contains(domain)) {
                    _dynamicDomains.add(domain);
                    _dynamicDomains.sort();
                  }
                  _selectedDomain = domain;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final remaining = _maxFiles - (_pickedFiles.length + _existingUrls.length);
    if (remaining <= 0) {
      _showSnackBar('You can attach up to $_maxFiles files only');
      return;
    }
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null || result.files.isEmpty) return;

    final List<PlatformFile> accepted = [];
    for (final file in result.files) {
      if (file.size > _maxFileSizeBytes) {
        _showSnackBar('${file.name} exceeds 15MB limit');
        continue;
      }
      accepted.add(file);
      if (accepted.length >= remaining) break;
    }
    if (mounted) setState(() { _pickedFiles.addAll(accepted); });
  }

  void _removePickedFile(PlatformFile file) => setState(() { _pickedFiles.remove(file); });
  
  void _removeExistingFile(int index) => setState(() {
    _existingUrls.removeAt(index);
    _existingNames.removeAt(index);
  });

  // ============================================================
  // MODIFICATION: UPLOAD TO SECURE VPS VAULT
  // ============================================================
  Future<List<Map<String, String>>> _uploadFilesToVPS() async {
    final List<Map<String, String>> uploaded = [];
    for (final file in _pickedFiles) {
      try {
        final String vpsSecureUrl = await FileService.uploadToVault(file, file.name);
        uploaded.add({'url': vpsSecureUrl, 'name': file.name});
      } catch (e) {
        debugPrint("File upload failed: $e");
        rethrow;
      }
    }
    return uploaded;
  }

  Future<bool> _showTermsAndConditionsDialog() async {
    bool accepted = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [primaryPurple, secondaryPurple]), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.gavel_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('SKILERN Agreement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('By assigning work through SKILERN, you agree to:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      _buildTermItem('1. Payment Obligation', 'Client agrees to fulfill the task payment directly to Admin QR code or Razorpay upon approval.'),
                      _buildTermItem('2. Deliverable Quality', 'Task is marked complete only when deliverables meet the description.'),
                      _buildTermItem('3. Withdrawal Policy', 'Cancellation allowed only within 24 hours of matching.'),
                      _buildTermItem('4. Platform Rights', 'SKILERN reserves the right to moderate all project communications.'),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: accepted,
                        activeColor: primaryPurple,
                        onChanged: (value) => setDialogState(() => accepted = value ?? false),
                        title: const Text('I have read and agree to the SKILERN terms.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel', style: TextStyle(color: textMuted))),
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [primaryPurple, secondaryPurple])),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0),
                    onPressed: accepted ? () => Navigator.of(dialogContext).pop(true) : null,
                    child: Text(_isEditing ? 'Agree & Update' : 'Agree & Post Task'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    return result == true;
  }

  Widget _buildTermItem(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryPurple)),
          Text(body, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  void _showAddCustomSkillDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Search or Add Skill', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Suggest correct spellings to ensure student matching.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                return _allSkills.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                _addSkillToProject(selection);
                Navigator.pop(ctx);
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                controller.addListener(() => ctrl.text = controller.text);
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'e.g. Photoshop, SEO...', prefixIcon: Icon(Icons.search)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
            onPressed: () {
              _addSkillToProject(ctrl.text);
              Navigator.pop(ctx);
            }, 
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_loading) return;

    final bool isValid = _formKey.currentState!.validate();
    
    if (!isValid || _selectedSkills.isEmpty || _selectedDomain == null) {
      setState(() => _showSkillError = _selectedSkills.isEmpty);
      _showSnackBar('Please complete the highlighted project requirements');
      return;
    }

    final agreed = _isEditing ? true : await _showTermsAndConditionsDialog();
    if (!agreed) return;

    setState(() { _loading = true; _hasAcceptedTermsForCurrentSubmission = true; });

    try {
      List<String> finalUrls = List.from(_existingUrls);
      List<String> finalNames = List.from(_existingNames);
      
      if (_pickedFiles.isNotEmpty) {
        // MODIFICATION: Call VPS Secure Upload helper
        final meta = await _uploadFilesToVPS();
        finalUrls.addAll(meta.map((e) => e['url']!).toList());
        finalNames.addAll(meta.map((e) => e['name']!).toList());
      }

      final title = _titleController.text.trim();
      final desc = _descController.text.trim();
      final deadline = _deadlineController.text.trim();

      if (_isEditing) {
        await _taskService.updateTask(
          taskId: _editingTaskId!,
          title: title,
          description: desc,
          deadline: deadline,
          location: _locationController.text.trim(),
          domain: _selectedDomain!,
          requiredSkills: _selectedSkills,
          attachments: finalUrls,
          attachmentNames: finalNames,
        );
        _showSnackBar('Task updated successfully');
      } else {
        await _taskService.createTask(
          title: title,
          description: desc,
          deadline: deadline,
          acceptedTerms: true,
          location: _locationController.text.trim(),
          domain: _selectedDomain!,
          requiredSkills: _selectedSkills,
          company: AuthService.currentUser?.company ?? '',
          attachments: finalUrls,
          attachmentNames: finalNames,
        );
        _showSnackBar('Task created successfully');
      }

      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () => Navigator.pop(context, true));
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() { _loading = false; _hasAcceptedTermsForCurrentSubmission = false; });
    }
  }

  void _showSnackBar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: primaryPurple, behavior: SnackBarBehavior.floating));
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: textMuted, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: primaryPurple, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      filled: true, fillColor: Colors.white,
      errorStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0, backgroundColor: Colors.white, centerTitle: false,
        title: Text(_isEditing ? 'Modify Project' : 'Post Requirement', style: const TextStyle(fontWeight: FontWeight.w700, color: primaryPurple)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryPurple), onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey, 
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController, 
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => (v == null || v.isEmpty) ? 'Project title is required' : (v.length < 5 ? 'Title is too short' : null),
                decoration: _fieldDecoration('Task Title', icon: Icons.title)
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _descController, 
                      maxLines: 4, 
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) => (v == null || v.isEmpty) ? 'Description is required' : (v.length < 20 ? 'Please provide more details' : null),
                      decoration: const InputDecoration(hintText: 'Describe deliverables in detail...', border: InputBorder.none)
                    ),
                    const Divider(),
                    if (_existingNames.isNotEmpty) ...[
                      const Align(alignment: Alignment.centerLeft, child: Text('Current Attachments:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: List.generate(_existingNames.length, (i) => Chip(
                        label: Text(_existingNames[i], style: const TextStyle(fontSize: 10)),
                        onDeleted: () => _removeExistingFile(i),
                        backgroundColor: Colors.blue.withOpacity(0.05),
                      ))),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        ElevatedButton.icon(onPressed: _pickFiles, icon: const Icon(Icons.attach_file, size: 18), label: const Text('Attach Files')),
                        const SizedBox(width: 12),
                        Text('${_pickedFiles.length + _existingUrls.length}/$_maxFiles selected', style: const TextStyle(fontSize: 12, color: textMuted)),
                      ],
                    ),
                    if (_pickedFiles.isNotEmpty)
                      Wrap(spacing: 8, children: _pickedFiles.map((f) => Chip(label: Text(f.name), onDeleted: () => _removePickedFile(f))).toList()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // MODIFICATION: Budget field removed, Row now only contains Deadline
              TextFormField(
                controller: _deadlineController, 
                readOnly: true, 
                onTap: _pickDeadline, 
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => (v == null || v.isEmpty) ? 'Deadline is required' : null,
                decoration: _fieldDecoration('Completion Deadline', icon: Icons.calendar_today)
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _loadingDomains 
                      ? const LinearProgressIndicator() 
                      : DropdownButtonFormField<String>(
                          value: _selectedDomain,
                          isExpanded: true,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => (v == null) ? 'Select a domain' : null,
                          hint: const Text("Select Project Domain", style: TextStyle(fontSize: 13)),
                          items: _dynamicDomains.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) => setState(() => _selectedDomain = v),
                          decoration: _fieldDecoration('Domain'),
                        ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: primaryPurple, size: 36),
                    onPressed: _showAddCustomDomainDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: _fieldDecoration('Required Skills', icon: Icons.bolt),
                      child: GestureDetector(
                        onTap: _showAddCustomSkillDialog,
                        child: Text(
                          _selectedSkills.isEmpty ? "Tap to add skills" : "Add more skills...",
                          style: TextStyle(fontSize: 13, color: _selectedSkills.isEmpty ? textMuted : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle,color: primaryPurple, size: 36),
                    onPressed: _showAddCustomSkillDialog,
                  ),
                ],
              ),
              if (_showSkillError) 
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: Text("At least one skill is required", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _selectedSkills.map((s) => Chip(
                  label: Text(s, style: const TextStyle(color: primaryPurple, fontSize: 11)),
                  backgroundColor: primaryPurple.withOpacity(0.08),
                  onDeleted: () => setState(() => _selectedSkills.remove(s))
                )).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: _loading 
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [primaryPurple, secondaryPurple])),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0),
                        onPressed: _handleSubmit,
                        child: Text(_isEditing ? 'Confirm Changes' : 'Post Project', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}