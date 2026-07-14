import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart'; // IMPORTED for live verification
import '../../models/user.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({Key? key}) : super(key: key);

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// The entry point logic that determines if a user stays logged in or is kicked out.
  Future<void> _bootstrap() async {
    try {
      // 1. Attempt to restore the token and user object from secure storage
      final hasSession = await AuthService.loadSession();
      
      if (!mounted) return;

      if (!hasSession || AuthService.currentUser == null) {
        debugPrint('Init: No session found, redirecting to login.');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // ============================================================
      // MODIFICATION: LIVE DATABASE VERIFICATION
      // Ensures the account hasn't been deleted from MongoDB
      // ============================================================
      debugPrint('Init: Verifying account status with server...');
      
      // We call getMe() to get the freshest data from the DB
      final User freshUser = await _userService.getMe();
      
      // Sync the global AuthService with the fresh data
      AuthService.currentUser = freshUser;

      // 2. Check if the Admin has banned/deactivated this account
      if (!freshUser.isApproved) {
        debugPrint('Init: Account not approved, clearing session.');
        await AuthService.clearSession();
        if (!mounted) return;
        _showSecuritySnack('Your account is currently suspended.');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Debug: confirm restored token and role
      debugPrint('Init success: role=${freshUser.role}, id=${freshUser.id}');

      // 3. Role-Based Routing to main dashboards
      if (freshUser.role == 'student') {
        Navigator.pushReplacementNamed(context, '/studentMain');
      } else if (freshUser.role == 'client') {
        Navigator.pushReplacementNamed(context, '/clientDashboard');
      } else if (freshUser.role == 'admin') {
        Navigator.pushReplacementNamed(context, '/adminDashboard');
      } else {
        // Fallback for unexpected roles
        await AuthService.clearSession();
        Navigator.pushReplacementNamed(context, '/login');
      }

    } catch (e) {
      // ============================================================
      // MODIFICATION: ERROR HANDLING (HANDLES DELETED ACCOUNTS)
      // If getMe() fails (401/404), it means the user was deleted from DB.
      // ============================================================
      debugPrint('Init: Bootstrap failed (Account likely deleted or token invalid) - $e');
      
      await AuthService.clearSession();
      
      if (!mounted) return;
      
      // If the error was a real account issue, show a snackbar
      if (e.toString().contains('no longer exists') || e.toString().contains('Unauthorized')) {
        _showSecuritySnack('Your session is invalid or account was removed.');
      }
      
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  /// Helper to show a consistent error message during bootstrap failures
  void _showSecuritySnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
            ),
            SizedBox(height: 16),
            Text(
              'Securing your session...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}