import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 

import '../../services/auth_service.dart';
import '../../services/file_service.dart'; // VPS Secure Upload

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  // ============================================================
  // FORM & CONTROLLERS
  // ============================================================
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();
  final _locationController = TextEditingController(); 

  final _companyController = TextEditingController();

  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();

  final AuthService _authService = AuthService();

  String _role = "student";
  bool _loading = false;
  bool _obscure = true;

  // Identity Proof State
  PlatformFile? _idCardFile;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color deepBg = Color(0xFF1A1A2E);

  // Master List for Autocomplete
  List<String> _allSkills = [
    'Flutter', 'React', 'Node.js', 'Python', 'Java',
    'Machine Learning', 'Data Science', 'UI/UX Design',
    'HTML', 'CSS', 'Javascript','DevOps', 'Databases', 'Editing', 'Writing'
  ];
  final Set<String> _selectedSkills = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart));

    _animController.forward();
    _allSkills.sort();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _companyController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATION & NORMALIZATION LOGIC
  // ============================================================

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Minimum 8 characters required';
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>])');
    if (!regex.hasMatch(value)) return 'Use Upper, Lower, Number, Symbol';
    return null;
  }

  String? _validateIFSC(String? value) {
    if (value == null || value.isEmpty) return 'IFSC is required';
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(value.toUpperCase())) return 'Invalid format (e.g. SBIN0001234)';
    return null;
  }

  String? _validateAccount(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (!RegExp(r'^\d{9,18}$').hasMatch(value)) return 'Enter 9-18 digits';
    return null;
  }

  void _addNewSkillToLocalState(String rawSkill) {
    if (rawSkill.trim().isEmpty) return;
    String cleaned = rawSkill.trim().split(' ').map((str) {
      if (str.isEmpty) return "";
      return str[0].toUpperCase() + str.substring(1).toLowerCase();
    }).join(' ');

    setState(() {
      if (!_selectedSkills.contains(cleaned)) _selectedSkills.add(cleaned);
      if (!_allSkills.contains(cleaned)) { _allSkills.add(cleaned); _allSkills.sort(); }
    });
  }

  Future<void> _pickIdCard() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null) {
      setState(() => _idCardFile = result.files.first);
    }
  }

  // ============================================================
  // SIGNUP OTP VERIFICATION DIALOG
  // ============================================================
  Future<void> _showOtpDialog(String email) async {
    final TextEditingController otpController = TextEditingController();
    bool verifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text("Gmail Verification", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("A 6-digit verification code was sent to $email. Please enter it below:"),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: "000000",
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: verifying ? null : () => Navigator.pop(ctx), 
              child: const Text("Cancel", style: TextStyle(color: Colors.grey))
            ),
            SizedBox(
              width: 120,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
                onPressed: verifying ? null : () async {
                  if (otpController.text.length < 6) return;
                  setDialogState(() => verifying = true);
                  
                  try {
                    final res = await _authService.verifySignupOTP(email, otpController.text);
                    if (res['success'] == true) {
                      Navigator.pop(ctx);
                      showSnack("Verification Success! You can now login.");
                      Navigator.pushReplacementNamed(context, "/login");
                    } else {
                      showSnack(res['message'] ?? "Invalid Code");
                    }
                  } catch (e) {
                    showSnack("Error: $e");
                  } finally {
                    setDialogState(() => verifying = false);
                  }
                }, 
                child: verifying 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text("Verify", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SIGNUP SUBMISSION (PHASE 1: REQUEST OTP)
  // ============================================================

  Future<void> _signup() async {
    if (_loading) return;
    
    if (!_formKey.currentState!.validate()) {
      showSnack("Please correct the highlighted errors");
      return;
    }

    if (_role == "student") {
      if (_selectedSkills.isEmpty) { showSnack("Select at least one skill"); return; }
      if (_idCardFile == null) { showSnack("Student ID Card image is required"); return; }
    }

    setState(() => _loading = true);

    try {
      String idUrl = "";
      if (_idCardFile != null) {
        // VPS Secure Upload
        idUrl = await FileService.uploadToVault(_idCardFile!, _idCardFile!.name);
      }

      final email = _emailController.text.trim();

      // Trigger Phase 1: Request OTP
      final res = await _authService.signup(
        _nameController.text.trim(),
        email,
        _passwordController.text,
        _role,
        mobile: _mobileController.text.trim(),
        location: _locationController.text.trim(),
        idCardUrl: idUrl, 
        company: _companyController.text.trim(),
        skills: _selectedSkills.toList(),
        accountHolder: _accountHolderController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        ifsc: _ifscController.text.trim().toUpperCase(),
      );

      setState(() => _loading = false);

      if (res["success"] == true) {
        // Success: Prompt user for OTP
        _showOtpDialog(email);
      } else {
        showSnack(res["message"] ?? "Signup failed");
      }
    } catch (e) {
      showSnack("Error: ${e.toString()}");
      setState(() => _loading = false);
    }
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: primaryPurple,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ============================================================
  // UI BUILDERS
  // ============================================================

  Widget _buildManagedField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters, 
    bool isObscure = false,
    String? Function(String?)? validator,
    Widget? suffix,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        textCapitalization: textCapitalization,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryPurple),
          suffixIcon: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: primaryPurple, width: 2),
          ),
          errorStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _role == "student";

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [deepBg, primaryPurple, secondaryPurple],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Container(
                    width: 450,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black26)],
                    ),
                    child: Column(
                      children: [
                        const Text("Join Skilern",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryPurple)),
                        const SizedBox(height: 25),
                        
                        _buildManagedField(
                          controller: _nameController, 
                          label: "Full Name", 
                          icon: Icons.person,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        
                        _buildManagedField(
                          controller: _emailController, 
                          label: "Email Address", 
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@')) ? 'Invalid email' : null,
                        ),
                        
                        _buildManagedField(
                          controller: _mobileController, 
                          label: "Mobile Number", 
                          icon: Icons.phone, 
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) => (v == null || v.length != 10) ? 'Enter 10-digit mobile' : null,
                        ),
                        
                        _buildManagedField(
                          controller: _passwordController, 
                          label: "Secure Password", 
                          icon: Icons.lock,
                          isObscure: _obscure,
                          validator: _validatePassword,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),

                        _buildManagedField(
                          controller: _locationController, 
                          label: "Current City", 
                          icon: Icons.location_on,
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),

                        const SizedBox(height: 10),
                        roleSelector(),

                        if (isStudent) ...[
                          _buildIdUploadSection(), 
                          bankFields(),
                          skillSelector(),
                        ],
                        if (!isStudent) ...[
                          const SizedBox(height: 20),
                          _buildManagedField(
                            controller: _companyController, 
                            label: "Company Name", 
                            icon: Icons.business,
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ],

                        const SizedBox(height: 30),
                        _loading ? const CircularProgressIndicator() : signupButton(),
                        const SizedBox(height: 20),
                        InkWell(
                          onTap: () => Navigator.pushReplacementNamed(context, "/login"),
                          child: const Text("Already have an account? Sign In",
                              style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => Navigator.pushReplacementNamed(context, "/landing"),
                          child: const Text("Back to landing", style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdUploadSection() {
    return Container(
      margin: const EdgeInsets.only(top: 15, bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _idCardFile == null ? Colors.red.withOpacity(0.02) : Colors.green.withOpacity(0.02),
        border: Border.all(color: _idCardFile == null ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.3)), 
        borderRadius: BorderRadius.circular(15)
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _idCardFile == null ? "Student ID Proof (Required)" : "Selected: ${_idCardFile!.name}", 
              style: TextStyle(fontSize: 12, color: _idCardFile == null ? Colors.red : Colors.green, fontWeight: FontWeight.bold)
            )
          ),
          IconButton(
            icon: Icon(_idCardFile == null ? Icons.upload_file : Icons.check_circle, color: _idCardFile == null ? primaryPurple : Colors.green), 
            onPressed: _pickIdCard
          ),
        ],
      ),
    );
  }

  Widget roleSelector() {
    return Row(
      children: [
        Expanded(child: roleCard("student")),
        const SizedBox(width: 10),
        Expanded(child: roleCard("client")),
      ],
    );
  }

  Widget roleCard(String role) {
    final selected = _role == role;
    return InkWell(
      onTap: () => setState(() => _role = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [primaryPurple, secondaryPurple])
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade300),
          boxShadow: selected ? [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 8)] : [],
        ),
        child: Center(
          child: Text(role.toUpperCase(),
              style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget skillSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 30),
        const Text("Skills & Expertise", style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _showAddCustomSkillDialog,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text("Search or Add Skills"),
          style: ElevatedButton.styleFrom(backgroundColor: primaryPurple.withOpacity(0.1), foregroundColor: primaryPurple),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: _selectedSkills.map((s) => Chip(
            label: Text(s, style: const TextStyle(color: primaryPurple, fontSize: 11)),
            backgroundColor: primaryPurple.withOpacity(0.1),
            onDeleted: () => setState(() => _selectedSkills.remove(s)),
          )).toList(),
        ),
      ],
    );
  }

  void _showAddCustomSkillDialog() {
    final TextEditingController typeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Technical Skill'),
        content: Autocomplete<String>(
          optionsBuilder: (textValue) => _allSkills.where((s) => s.toLowerCase().contains(textValue.text.toLowerCase())),
          onSelected: (s) { _addNewSkillToLocalState(s); Navigator.pop(ctx); },
          fieldViewBuilder: (ctx, ctrl, node, onFieldSubmitted) {
            ctrl.addListener(() => typeController.text = ctrl.text);
            return TextField(controller: ctrl, focusNode: node, autofocus: true, decoration: const InputDecoration(hintText: "Search e.g. Editing..."));
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { _addNewSkillToLocalState(typeController.text); Navigator.pop(ctx); }, child: const Text('Add')),
        ],
      ),
    );
  }

  Widget bankFields() {
    return Column(
      children: [
        const Divider(height: 40),
        const Text("Bank Payout Information", style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple)),
        const SizedBox(height: 15),
        _buildManagedField(
          controller: _accountHolderController, 
          label: "A/C Holder Name", 
          icon: Icons.person_outline,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        _buildManagedField(
          controller: _accountNumberController, 
          label: "Bank Account Number", 
          icon: Icons.credit_card, 
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly], 
          validator: _validateAccount,
        ),
        _buildManagedField(
          controller: _ifscController, 
          label: "IFSC Code", 
          icon: Icons.account_balance, 
          textCapitalization: TextCapitalization.characters,
          validator: _validateIFSC,
        ),
      ],
    );
  }

  Widget signupButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: _signup,
        child: const Text("Create Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}