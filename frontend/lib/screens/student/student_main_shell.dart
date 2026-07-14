import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/socketservice.dart'; 
import '../../services/task_service.dart'; 
import '../../models/user.dart';
import '../student/student_profile_screen.dart';
import '../student/student_workspace_screen.dart';
import '../student/student_chats_screen.dart';
import '../student/student_dashboard_screen.dart';

class StudentMainShell extends StatefulWidget {
  final int initialIndex;

  const StudentMainShell({
    Key? key,
    this.initialIndex = 2, // Defaults to Home Tab
  }) : super(key: key);

  @override
  State<StudentMainShell> createState() => _StudentMainShellState();
}

class _StudentMainShellState extends State<StudentMainShell>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late User _user;
  int _unreadCount = 0; // MODIFICATION: Real-time unread message counter

  late AnimationController _fabController;
  late Animation<double> _fabScale;
  late AnimationController _pageController;

  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color backgroundColor = Color(0xFFF5F7FB);

  @override
  void initState() {
    super.initState();
    
    // Safety check for user session
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }
    
    _user = currentUser;
    _currentIndex = widget.initialIndex;

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fabScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack),
    );
    
    _pageController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fabController.forward();
    _pageController.forward();

    _initializeRealTimeSession();
    _fetchInitialUnreadCount();
  }

  /// Hits the API to see if there are any unread messages waiting since last session
  Future<void> _fetchInitialUnreadCount() async {
    try {
      final tasks = await TaskService().getChatTasksForStudent();
      if (mounted) {
        setState(() {
          // Check for tasks where rating is -1 (our placeholder for 'has unread')
          // Or however your backend identifies unread status
          _unreadCount = tasks.where((t) => t.status == 'unread_pending').length; 
        });
      }
    } catch (_) {}
  }

  /// Sets up real-time monitoring for account security and notifications
  void _initializeRealTimeSession() {
    SocketService.connect();
    
    // Join the student's unique private room
    SocketService.joinUserRoom(_user.id);

    // ============================================================
    // MODIFICATION 1: REAL-TIME ACCOUNT SECURITY (KILL SIGNAL)
    // If Admin deletes or bans user, logout is instant.
    // ============================================================
    SocketService.on('user_status_update', (data) {
      if (mounted) {
        final bool isApproved = data['isApproved'] ?? true;
        final bool isDeleted = data['deleted'] ?? false;

        if (!isApproved || isDeleted) {
          _handleForcedLogout(isDeleted ? "Account Deleted" : "Account Suspended");
        }
      }
    });

    // ============================================================
    // MODIFICATION 2: DYNAMIC CHAT NOTIFICATION DOT
    // Increment badge count when a message arrives in the background
    // ============================================================
    SocketService.on('new_message', (data) {
      if (mounted && _currentIndex != 3) { // 3 is the Chat tab
        setState(() {
          _unreadCount++; 
        });
      }
    });
  }

  @override
  void dispose() {
    // MODIFICATION: CLEAN UP LISTENERS
    SocketService.off('user_status_update');
    SocketService.off('new_message');
    _fabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Logic to wipe session and redirect to landing
  Future<void> _handleForcedLogout(String reason) async {
    await AuthService.clearSession();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Security Alert: $reason'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService.clearSession();
    Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      // Clear the red dot the moment they click into the Chat tab
      if (index == 3) {
        _unreadCount = 0;
      }
    });
  }

  // --- HOME TAB UI BUILDER ---
  Widget _buildHome() {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false, 
            backgroundColor: primaryPurple,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
              title: const Text('Welcome Back!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryPurple, secondaryPurple, primaryPurple.withOpacity(0.85)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(right: -30, top: -30, child: Icon(Icons.work_outline, size: 180, color: Colors.white.withOpacity(0.08))),
                    Positioned(left: -20, bottom: 20, child: Icon(Icons.school_outlined, size: 120, color: Colors.white.withOpacity(0.08))),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
                      border: Border.all(color: primaryPurple.withOpacity(0.05)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [primaryPurple, secondaryPurple]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.handshake_outlined, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ready to work, ${_user.name}?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
                              const SizedBox(height: 4),
                              const Text('Admin assignments will appear in your workspace live.', style: TextStyle(fontSize: 12, color: textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Navigation Hub', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textDark, letterSpacing: 0.5)),
                  const SizedBox(height: 16),

                  _AnimatedHomeTipTile(
                    icon: Icons.person_outline,
                    gradientColors: const [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    title: 'Profile Settings',
                    subtitle: 'Update your bank details & skills',
                    onTap: () => _onTabTapped(0), 
                  ),
                  const SizedBox(height: 12),
                  _AnimatedHomeTipTile(
                    icon: Icons.layers_outlined,
                    gradientColors: const [Color(0xFFFF9800), Color(0xFFFF5722)],
                    title: 'Active Workspace',
                    subtitle: 'Accept tasks and submit work',
                    onTap: () => _onTabTapped(1), 
                  ),
                  const SizedBox(height: 12),
                  _AnimatedHomeTipTile(
                    icon: Icons.forum_outlined,
                    gradientColors: const [Color(0xFF009688), Color(0xFF4CAF50)],
                    title: 'Inbound Chats',
                    subtitle: 'Communicate with administrators',
                    onTap: () => _onTabTapped(3), 
                  ),
                  const SizedBox(height: 12),
                  _AnimatedHomeTipTile(
                    icon: Icons.auto_graph_outlined,
                    gradientColors: const [Color(0xFF3F51B5), Color(0xFF2196F3)],
                    title: 'Performance & Reviews',
                    subtitle: 'Track your reputation and score',
                    onTap: () => _onTabTapped(4), 
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get _pages => [
    const StudentProfileScreen(),
    const StudentWorkspaceScreen(),
    _buildHome(),
    const StudentChatsScreen(),
    const StudentDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryPurple,
          unselectedItemColor: textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          onTap: _onTabTapped,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
            const BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Workspace'),
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            
            // ============================================================
            // MODIFICATION: DYNAMIC NOTIFICATION BADGE ON CHAT
            // ============================================================
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text('$_unreadCount', style: const TextStyle(fontSize: 8)),
                backgroundColor: Colors.red,
                child: const Icon(Icons.chat_bubble_outline),
              ), 
              activeIcon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text('$_unreadCount', style: const TextStyle(fontSize: 8)),
                backgroundColor: Colors.red,
                child: const Icon(Icons.chat_bubble),
              ), 
              label: 'Chat'
            ),

            const BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Feedback'),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHomeTipTile extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AnimatedHomeTipTile({
    Key? key,
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _StudentMainShellState.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: _StudentMainShellState.textMuted, height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}