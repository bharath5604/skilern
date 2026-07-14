import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/student/task_feed_screen.dart';
import 'screens/student/student_profile_screen.dart';
import 'screens/student/student_main_shell.dart';
import 'screens/student/student_workspace_screen.dart';
import 'screens/common/task_chat_screen.dart';
import 'screens/common/unified_preview_screen.dart'; 
import 'screens/client/create_task_screen.dart';
import 'screens/client/my_tasks_screen.dart';
import 'screens/client/client_dashboard_screen.dart';
import 'screens/client/client_profile_screen.dart';
import 'screens/client/client_chats_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_tasks_screen.dart';
import 'screens/admin/admin_pending_payments_screen.dart';
import 'screens/admin/admin_user_detail_screen.dart'; 
import 'screens/common/landing_screen.dart';
import 'screens/common/init_screen.dart';

import 'services/auth_service.dart';
import 'services/notification_service.dart'; 
import 'services/socketservice.dart'; 
import 'models/user.dart';

/// Background message handler for Firebase Cloud Messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('Background message received: ${message.messageId}');
  } catch (e) {
    debugPrint('Background Firebase init failed: $e');
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // 2. Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Load saved auth session (Auto-Login)
    final bool hasSession = await AuthService.loadSession();

    // Global Socket Initialization
    if (hasSession && AuthService.isLoggedIn) {
      SocketService.connect();
      
      final String? uid = AuthService.userId;
      final String? uRole = AuthService.role;

      if (uid != null) {
        SocketService.joinUserRoom(uid);
        if (uRole?.toLowerCase() == 'admin') {
          SocketService.joinAdminRoom();
        }
      }
    }
  } catch (e) {
    debugPrint("Critical App Bootstrap Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Determines initial route based on current auth session and user role.
  String _initialRoute() {
    final User? user = AuthService.currentUser;
    final String? token = AuthService.token;

    if (token != null && user != null) {
      if (!user.isApproved) return '/login'; 

      switch (user.role.toLowerCase()) {
        case 'student': return '/studentMain';
        case 'client': return '/clientDashboard';
        case 'admin': return '/adminDashboard';
        default: return '/landing';
      }
    }
    return '/landing';
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFE53935); 
    const Color backgroundColor = Color(0xFFF8FAFC);

    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey, 
      debugShowCheckedModeBanner: false,
      title: 'Skilern',
      initialRoute: _initialRoute(),
      
      onGenerateRoute: (settings) {
        if (settings.name == '/taskChat') {
          return _buildTaskChatRoute(settings);
        }
        if (settings.name == '/adminUserDetail') {
          return _buildUserDetailRoute(settings);
        }
        return null; 
      },

      routes: {
        '/init': (context) => const InitScreen(),
        '/landing': (context) => const LandingScreen(),

        // Auth
        '/login': (context) => LoginScreen(),
        '/signup': (context) => const SignupScreen(),

        // Student
        '/studentMain': (context) => const StudentMainShell(),
        '/taskFeed': (context) => const TaskFeedScreen(),
        '/studentProfile': (context) => const StudentProfileScreen(),
        '/studentWorkspace': (context) => const StudentWorkspaceScreen(),

        // Client
        '/clientDashboard': (context) => const ClientDashboardScreen(),
        '/createTask': (context) => const CreateTaskScreen(),
        '/myTasks': (context) => const MyTasksScreen(),
        '/clientProfile': (context) => const ClientProfileScreen(),
        '/clientChats': (context) => const ClientChatsScreen(),

        // Admin
        '/adminDashboard': (context) => const AdminDashboardScreen(),
        '/adminUsers': (context) => const AdminUsersScreen(),
        '/adminTasks': (context) => const AdminTasksScreen(),
        '/adminPayments': (context) => const AdminPendingPaymentsScreen(),

        // ============================================================
        // MODIFICATION: COMPLIANCE ROUTES (FOR PLAY STORE URLS)
        // ============================================================
        '/privacy': (context) => const PolicyPage(title: "Privacy Policy", content: _privacyContent),
        '/terms': (context) => const PolicyPage(title: "Terms and Conditions", content: _termsContent),
        '/refunds': (context) => const PolicyPage(title: "Refund Policy", content: _refundContent),
        '/delivery': (context) => const PolicyPage(title: "Shipping & Delivery Policy", content: _deliveryContent),
      },

      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
      ),
    );
  }

  Route<dynamic> _buildUserDetailRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is String && args.isNotEmpty) {
      return MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: args));
    }
    return MaterialPageRoute(builder: (_) => const _RouteErrorScreen(title: "Profile Error", message: "User ID missing."));
  }

  Route<dynamic> _buildTaskChatRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is Map) {
      final map = Map<String, dynamic>.from(args);
      final taskId = map['taskId']?.toString() ?? '';
      if (taskId.isNotEmpty) {
        return MaterialPageRoute(
          builder: (_) => TaskChatScreen(
            taskId: taskId,
            taskTitle: map['taskTitle']?.toString() ?? 'Task Chat',
            peerStudentId: map['peerStudentId']?.toString(),
          ),
        );
      }
    }
    return MaterialPageRoute(builder: (_) => const _RouteErrorScreen(title: 'Chat Unavailable', message: 'Task ID is missing.'));
  }
}

// =============================================================================
// LEGAL CONTENT STRINGS (Global)
// =============================================================================

const String _privacyContent = """
At Skilern, we take your privacy seriously. We only collect information needed to facilitate task matching and payments. 
1. Collection: We collect name, email, and mobile numbers.
2. Usage: Data is used for platform operations and Razorpay processing.
3. Security: We use JWT encryption and private VPS storage for all deliverables.
4. Sharing: We do not sell data to third parties.
""";

const String _termsContent = """
By using Skilern, you agree to:
1. Roles: Clients post tasks, Students complete them, and Admins facilitate.
2. Workflow: All tasks must follow the Skilern lifecycle (Preview -> Approval -> Payout).
3. Conduct: Plagiarism is strictly forbidden.
4. Payments: All financial transactions must occur through the platform's escrow system.
""";

const String _refundContent = """
1. Guarantee: Clients preview work before paying. Reject work if it fails requirements.
2. Finality: No refunds are issued once files are approved and downloaded.
3. Double Charges: Duplicate payments are refunded within 5-7 working days.
""";

const String _deliveryContent = """
1. Digital Services: Skilern provides digital deliverables only.
2. Access: Files are released in the dashboard immediately after Admin confirms payment.
3. Support: For broken files, contact support for a fix within 48 hours.
""";

class _RouteErrorScreen extends StatelessWidget {
  final String title, message;
  const _RouteErrorScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/landing'), child: const Text('Back to Home')),
            ],
          ),
        ),
      ),
    );
  }
}