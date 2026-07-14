import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/user.dart';

class LoginScreen extends StatefulWidget {
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool _loading = false;
  bool _obscure = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // New Purple Palette from Image
  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color deepBg = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Slightly longer for smoother feel
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController, 
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut)
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =========================================================
  // FORGOT PASSWORD FLOW
  // =========================================================

  Future<void> _handleForgotPassword() async {
    final TextEditingController resetEmailCtrl =
        TextEditingController(text: _emailController.text);

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password', style: TextStyle(color: primaryPurple)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your registered email to receive a 6-digit OTP code.'),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email Address', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
            onPressed: () => Navigator.pop(ctx, resetEmailCtrl.text.trim()),
            child: const Text('Send OTP', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    setState(() => _loading = true);
    try {
      final res = await authService.forgotPassword(email);
      setState(() => _loading = false);

      if (res['success'] == true || res['message'].toString().contains('sent')) {
        _showResetDialog(email);
      } else {
        _showSnackBar(res['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _showResetDialog(String email) async {
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('A code was sent to $email'),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                  labelText: '6-Digit OTP', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'New Password', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
              onPressed: () async {
                if (otpCtrl.text.length < 6 || newPassCtrl.text.length < 6) return;

                final res = await authService.resetPassword(
                    email, otpCtrl.text, newPassCtrl.text);
                if (res['success'] == true) {
                  Navigator.pop(ctx);
                  _showSnackBar('Password reset successful! Please login.');
                } else {
                  _showSnackBar(res['message'] ?? 'Reset failed');
                }
              },
              child: const Text('Reset Password', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: primaryPurple,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // =========================================================
  // LOGIN LOGIC
  // =========================================================

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnackBar('Email and password are required');
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (res['token'] != null && AuthService.currentUser != null) {
        final User user = AuthService.currentUser!;

        if (!user.isApproved) {
          _showSnackBar('Account not approved by admin');
          if (mounted) setState(() => _loading = false);
          return;
        }

        try {
          await NotificationService.instance.init();
        } catch (_) {}

        if (user.role == 'student') {
          Navigator.pushReplacementNamed(context, '/studentMain');
        } else if (user.role == 'client') {
          Navigator.pushReplacementNamed(context, '/clientDashboard');
        } else if (user.role == 'admin') {
          Navigator.pushReplacementNamed(context, '/adminDashboard');
        }
      } else {
        _showSnackBar(res['message'] ?? 'Login failed');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth > 800 ? 500.0 : double.infinity;

    return Scaffold(
      body: Container(
        // Animated-style gradient background matching the image
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [deepBg, primaryPurple, secondaryPurple],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SizedBox(
                    width: containerWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5))
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(
                                      Icons.auto_awesome,
                                      color: primaryPurple,
                                      size: 30),
                                ),
                              ),
                            ),
                            // const SizedBox(width: 12),
                            // const Text(
                            //   'Skilen',
                            //   style: TextStyle(
                            //       fontSize: 28,
                            //       fontWeight: FontWeight.w800,
                            //       color: Colors.white,
                            //       letterSpacing: 1.2),
                            // ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Text('Welcome back',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 8),
                        const Text('Sign in to continue bidding on tasks',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 20,
                                  offset: Offset(0, 10))
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email_outlined,
                                      color: primaryPurple),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                        color: primaryPurple, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: primaryPurple),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility, color: Colors.grey),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                        color: primaryPurple, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _handleForgotPassword,
                                  child: const Text('Forgot password?',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: primaryPurple,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _loading
                                  ? const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          primaryPurple))
                                  : SizedBox(
                                      width: double.infinity,
                                      height: 55,
                                      child: ElevatedButton(
                                        onPressed: _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryPurple,
                                          foregroundColor: Colors.white,
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15)),
                                        ),
                                        child: const Text('Login',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/signup'),
                          child: const Text("Don't have an account? Sign up",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/landing'),
                          child: const Text("Back to landing",
                              style: TextStyle(color: Colors.white70)),
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
}