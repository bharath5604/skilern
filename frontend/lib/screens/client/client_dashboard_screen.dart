import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/socketservice.dart'; // IMPORTED

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _initializeSecurityListener();
  }

  // ============================================================
  // MODIFICATION: REAL-TIME SECURITY (KILL SIGNAL)
  // ============================================================
  void _initializeSecurityListener() {
    final user = AuthService.currentUser;
    if (user == null) return;

    SocketService.connect();
    // Join the unique private room for this client
    SocketService.joinUserRoom(user.id);

    // Listen for account status changes (Banned or Deleted)
    SocketService.on('user_status_update', (data) {
      if (mounted) {
        final bool isApproved = data['isApproved'] ?? true;
        final bool isDeleted = data['deleted'] ?? false;

        // If Admin toggles 'Approved' to false OR deletes the record
        if (!isApproved || isDeleted) {
          _handleForcedLogout(isDeleted ? "Account Deleted" : "Account Suspended");
        }
      }
    });
  }

  @override
  void dispose() {
    // MODIFICATION: CLEAN UP
    SocketService.off('user_status_update');
    super.dispose();
  }

  /// Automatically clears session and redirects if account is removed by Admin
  Future<void> _handleForcedLogout(String reason) async {
    await AuthService.clearSession();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Security Alert: $reason by Administrator.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [primaryPurple, secondaryPurple],
            ).createShader(bounds),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await AuthService.clearSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/landing', (route) => false);
  }

  int _gridCount(double width) {
    if (width >= 1300) return 4;
    if (width >= 900) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth >= 900;
    final crossAxisCount = _gridCount(screenWidth);

    final actions = <_DashboardAction>[
      _DashboardAction(
        title: 'Create Task',
        subtitle: 'Post a new task requirement',
        icon: Icons.post_add,
        primaryColor: primaryPurple,
        secondaryColor: secondaryPurple,
        routeName: '/createTask',
      ),
      _DashboardAction(
        title: 'My Tasks',
        subtitle: 'Track created and assigned work',
        icon: Icons.list_alt,
        primaryColor: const Color(0xFF2196F3),
        secondaryColor: const Color(0xFF1976D2),
        routeName: '/myTasks',
      ),
      _DashboardAction(
        title: 'Admin Chat',
        subtitle: 'Contact admin or support',
        icon: Icons.support_agent,
        primaryColor: const Color(0xFF009688),
        secondaryColor: const Color(0xFF00796B),
        routeName: '/clientChats',
      ),
      _DashboardAction(
        title: 'Profile',
        subtitle: 'View and update account details',
        icon: Icons.person,
        primaryColor: const Color(0xFF3F51B5),
        secondaryColor: const Color(0xFF303F9F),
        routeName: '/clientProfile',
      ),
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: isWeb
          ? null
          : AppBar(
              backgroundColor: surfaceColor,
              elevation: 0.6,
              titleSpacing: 16,
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [primaryPurple, secondaryPurple],
                ).createShader(bounds),
                child: const Text('SKILERN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
              ),
              actions: [
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout, color: Colors.black87),
                  onPressed: () => _logout(context),
                ),
              ],
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (isWeb)
              Container(
                width: 260,
                color: surfaceColor,
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    _sideItem(icon: Icons.dashboard_outlined, title: 'Dashboard', selected: true, primaryPurple: primaryPurple),
                    _sideItem(icon: Icons.post_add, title: 'Create Task', onTap: () => Navigator.pushNamed(context, '/createTask'), primaryPurple: primaryPurple),
                    _sideItem(icon: Icons.list_alt, title: 'My Tasks', onTap: () => Navigator.pushNamed(context, '/myTasks'), primaryPurple: primaryPurple),
                    _sideItem(icon: Icons.support_agent, title: 'Admin Chat', onTap: () => Navigator.pushNamed(context, '/clientChats'), primaryPurple: primaryPurple),
                    _sideItem(icon: Icons.person_outline, title: 'Profile', onTap: () => Navigator.pushNamed(context, '/clientProfile'), primaryPurple: primaryPurple),
                    const Spacer(),
                    const Divider(height: 1),
                    _sideItem(icon: Icons.logout, title: 'Logout', iconColor: primaryPurple, textColor: primaryPurple, onTap: () => _logout(context), primaryPurple: primaryPurple),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWeb)
                    Container(
                      height: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      color: surfaceColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Welcome, ${user?.name ?? "Client"}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textDark)),
                          const Icon(Icons.verified_user, color: Colors.green, size: 24),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(isWeb ? 32 : 16),
                      children: [
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.white, primaryPurple.withOpacity(0.04)]),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Colors.black12)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 56, width: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [primaryPurple.withOpacity(0.15), secondaryPurple.withOpacity(0.08)]),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.handshake_outlined, color: primaryPurple, size: 28),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Manage tasks and track conversations with vetted students all in one place.',
                                    style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GridView.builder(
                          itemCount: isWeb ? actions.length : actions.length + 1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                            childAspectRatio: isWeb ? 1.18 : 1.05,
                          ),
                          itemBuilder: (context, index) {
                            if (!isWeb && index == actions.length) {
                              return _DashboardCard(
                                title: 'Logout',
                                subtitle: 'Sign out from account',
                                icon: Icons.logout,
                                primaryColor: primaryPurple,
                                secondaryColor: secondaryPurple,
                                onTap: () => _logout(context),
                              );
                            }
                            final item = actions[index];
                            return _DashboardCard(
                              title: item.title,
                              subtitle: item.subtitle,
                              icon: item.icon,
                              primaryColor: item.primaryColor,
                              secondaryColor: item.secondaryColor,
                              onTap: () => Navigator.pushNamed(context, item.routeName),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideItem({required IconData icon, required String title, VoidCallback? onTap, bool selected = false, Color? iconColor, Color? textColor, required Color primaryPurple}) {
    final color = textColor ?? (selected ? primaryPurple : Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: selected ? primaryPurple.withOpacity(0.08) : Colors.transparent,
        leading: Icon(icon, color: iconColor ?? color, size: 22),
        title: Text(title, style: TextStyle(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
        onTap: onTap,
      ),
    );
  }
}

class _DashboardAction {
  final String title, subtitle, routeName; final IconData icon; final Color primaryColor, secondaryColor;
  const _DashboardAction({required this.title, required this.subtitle, required this.icon, required this.primaryColor, required this.secondaryColor, required this.routeName});
}

class _DashboardCard extends StatelessWidget {
  final String title, subtitle; final IconData icon; final Color primaryColor, secondaryColor; final VoidCallback onTap;
  const _DashboardCard({required this.title, required this.subtitle, required this.icon, required this.primaryColor, required this.secondaryColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: primaryColor.withOpacity(0.08)), boxShadow: [BoxShadow(blurRadius: 16, offset: const Offset(0, 6), color: primaryColor.withOpacity(0.08))]),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor.withOpacity(0.12), secondaryColor.withOpacity(0.06)]), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: primaryColor, size: 28)),
            const Spacer(),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(colors: [primaryColor, _ClientDashboardScreenState.secondaryPurple]).createShader(bounds),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
          ],
        ),
      ),
    );
  }
}