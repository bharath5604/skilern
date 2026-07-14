import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'admin_pending_payments_screen.dart';
import 'admin_tasks_screen.dart';
import 'admin_users_screen.dart';
import '../../services/socketservice.dart'; 

// =============================================================================
// GLOBAL DESIGN TOKENS (Fixed to prevent scoping errors)
// =============================================================================
const Color kPrimaryRed = Color(0xFFE53935);
const Color kBlueColor = Color(0xFF2563EB);
const Color kGreenColor = Color(0xFF059669);
const Color kAmberColor = Color(0xFFD97706);
const Color kBgGray = Color(0xFFF0F4FF);
const Color kTextDark = Color(0xFF0F172A);
const Color kTextMuted = Color(0xFF64748B);
const Color kBorderGray = Color(0xFFE2E8F0);

const Color kCardBg = Color(0xFFFFFFFF);
const Color kAccentIndigo = Color(0xFF4F46E5);
const Color kAccentPurple = Color(0xFF7C3AED);
const Color kAccentTeal = Color(0xFF0D9488);
const Color kSurfaceBlue = Color(0xFFEFF6FF);
const Color kSurfaceGreen = Color(0xFFECFDF5);
const Color kSurfaceAmber = Color(0xFFFFFBEB);
const Color kSurfacePurple = Color(0xFFF5F3FF);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final AdminService adminService = AdminService();

  bool loading = false;

  Map<String, dynamic>? overview;
  Map<String, dynamic>? taskStats;
  List<Map<String, dynamic>> topStudents = [];
  List<Map<String, dynamic>> growthStats = [];

  String selectedMetric = 'tasks';

  late AnimationController animController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();
    animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    fadeAnimation = CurvedAnimation(parent: animController, curve: Curves.easeOut);
    slideAnimation = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOutCubic),
    );

    loadAll();

    // ============================================================
    // MODIFICATION: REAL-TIME DYNAMIC LISTENERS
    // ============================================================
    SocketService.connect();
    SocketService.joinAdminRoom();

    // Trigger full reload on any of these platform-wide events
    SocketService.on('admin_stats_update', (_) => _refreshIfMounted());
    SocketService.on('task_created', (_) => _refreshIfMounted());
    SocketService.on('user_registered', (_) => _refreshIfMounted());
    SocketService.on('task_update', (_) => _refreshIfMounted());

    // Security Check: Auto-logout if Admin is banned or deleted
    SocketService.on('user_status_update', (data) {
      if (mounted) {
        final bool isApproved = data['isApproved'] ?? true;
        if (!isApproved) {
          AuthService.clearSession();
          Navigator.pushReplacementNamed(context, '/landing');
        }
      }
    });
  }

  void _refreshIfMounted() {
    if (mounted && !loading) {
      loadAll();
    }
  }

  @override
  void dispose() {
    // CLEAN UP
    SocketService.off('admin_stats_update');
    SocketService.off('task_created');
    SocketService.off('user_registered');
    SocketService.off('task_update');
    SocketService.off('user_status_update');
    animController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  void goUsers() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
  void goTasks() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTasksScreen()));
  void goReviewQueue() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPendingPaymentsScreen()));

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, val) => MapEntry(key.toString(), val));
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> asListOfMap(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.map<Map<String, dynamic>>((item) => asMap(item)).toList();
  }

  int findCountByStatus(List<Map<String, dynamic>> list, List<String> statuses) {
    int total = 0;
    final normalized = statuses.map((e) => e.toLowerCase()).toSet();
    for (final item in list) {
      final id = (item['_id'] ?? '').toString().toLowerCase();
      if (normalized.contains(id)) total += toInt(item['count']);
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------

  Future<void> loadAll() async {
    if (mounted) setState(() => loading = true);
    try {
      final results = await Future.wait([
        adminService.getOverviewStats(),
        adminService.getTaskStats(),
        adminService.getTopStudents(),
        adminService.getGrowthStats(metric: selectedMetric),
      ]);

      if (!mounted) return;
      setState(() {
        overview = asMap(results[0]);
        taskStats = asMap(results[1]);
        topStudents = asListOfMap(results[2]);
        growthStats = asListOfMap(results[3]);
        loading = false;
      });
      animController.forward(from: 0);
    } catch (e) {
      debugPrint('Dashboard API Error: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> reloadGrowth() async {
    try {
      final res = await adminService.getGrowthStats(metric: selectedMetric);
      if (mounted) setState(() => growthStats = asListOfMap(res));
    } catch (e) { debugPrint(e.toString()); }
  }

  // ---------------------------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    if (user == null || user.role != 'admin') {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    final uMap = asMap(overview?['users']);
    final tMap = asMap(overview?['tasks']);
    final byTaskStatus = asListOfMap(taskStats?['byStatus']);

    final funnelOpen = findCountByStatus(byTaskStatus, ['open', 'request_sent']);
    final funnelActive = findCountByStatus(byTaskStatus, ['assigned', 'under_review']);
    final funnelDone = findCountByStatus(byTaskStatus, ['completed']);

    return Scaffold(
      backgroundColor: kBgGray,
      appBar: _buildAppBar(),
      body: loading && overview == null
          ? _buildLoadingState()
          : RefreshIndicator(
              color: kAccentIndigo,
              onRefresh: loadAll,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(
                  position: slideAnimation,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _buildTopMenu(),
                      const SizedBox(height: 18),
                      _buildHeroHeader(
                        totalUsers: toInt(uMap['total']),
                        totalTasksCom: toInt(tMap['completed']),
                      ),
                      const SizedBox(height: 18),
                      _buildCommunitySection(uMap),
                      const SizedBox(height: 18),
                      _buildFunnelSection(funnelOpen, funnelActive, funnelDone),
                      const SizedBox(height: 18),
                      _buildTrendsSection(),
                      const SizedBox(height: 18),
                      _buildTopStudentsSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kAccentIndigo, kAccentPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              color: kTextDark,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kBorderGray),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: kPrimaryRed, size: 20),
            onPressed: () => AuthService.logout().then(
              (_) => Navigator.pushReplacementNamed(context, '/landing'),
            ),
            tooltip: 'Logout',
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kAccentIndigo, kAccentPurple]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Updating dynamic dashboard...', style: TextStyle(color: kTextMuted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTopMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderGray),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MenuAction(label: 'Users', icon: Icons.people_rounded, onTap: goUsers, color: kBlueColor, surface: kSurfaceBlue),
          _buildMenuDivider(),
          _MenuAction(label: 'Tasks', icon: Icons.assignment_rounded, onTap: goTasks, color: kAmberColor, surface: kSurfaceAmber),
          _buildMenuDivider(),
          _MenuAction(label: 'Review Queue', icon: Icons.fact_check_rounded, onTap: goReviewQueue, color: kGreenColor, surface: kSurfaceGreen),
        ],
      ),
    );
  }

  Widget _buildMenuDivider() {
    return Container(width: 1, height: 32, color: kBorderGray);
  }

  Widget _buildHeroHeader({required int totalUsers, required int totalTasksCom}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: kAccentIndigo.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          // PRESERVING ORIGINAL DECORATIVE ORBS
          Positioned(
            right: -10,
            top: -15,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'TOTAL USERS',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalUsers',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('Active accounts', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
                ]),
              ),
              Container(
                width: 1,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withOpacity(0.15),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'COMPLETED',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalTasksCom',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('Projects done', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunitySection(Map<String, dynamic> uMap) {
    return _ModernSectionCard(
      title: 'Community',
      subtitle: 'Platform members',
      icon: Icons.groups_rounded,
      iconColor: kBlueColor,
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'Students',
              value: toInt(uMap['students']).toString(),
              icon: Icons.school_rounded,
              color: kBlueColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              label: 'Clients',
              value: toInt(uMap['clients']).toString(),
              icon: Icons.business_center_rounded,
              color: kGreenColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelSection(int open, int active, int done) {
    return _ModernSectionCard(
      title: 'Operational Funnel',
      subtitle: 'Task pipeline stages',
      icon: Icons.filter_alt_rounded,
      iconColor: kAmberColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          BadgeMetric(title: 'Open', value: open.toString(), color: kBlueColor),
          const _FunnelArrow(),
          BadgeMetric(title: 'Active', value: active.toString(), color: kAmberColor),
          const _FunnelArrow(),
          BadgeMetric(title: 'Done', value: done.toString(), color: kGreenColor),
        ],
      ),
    );
  }

  Widget _buildTrendsSection() {
    return _ModernSectionCard(
      title: 'Activity Trends',
      subtitle: 'Platform growth over time',
      icon: Icons.trending_up_rounded,
      iconColor: kAccentIndigo,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: kBgGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderGray),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedMetric,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMuted),
                style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w600, fontSize: 13),
                items: ['tasks', 'students'].map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Row(
                      children: [
                        Icon(
                          m == 'tasks' ? Icons.assignment_rounded : Icons.school_rounded,
                          size: 16,
                          color: kAccentIndigo,
                        ),
                        const SizedBox(width: 8),
                        Text(m == 'tasks' ? 'Task Activity' : 'Student Growth'),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => selectedMetric = v);
                    reloadGrowth();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: GrowthLineChart(data: growthStats)),
        ],
      ),
    );
  }

  Widget _buildTopStudentsSection() {
    return _ModernSectionCard(
      title: 'Top Students',
      subtitle: 'Ranked by tasks completed',
      icon: Icons.emoji_events_rounded,
      iconColor: kAmberColor,
      child: topStudents.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 36, color: kBorderGray),
                    SizedBox(height: 8),
                    Text('No ranking data yet', style: TextStyle(color: kTextMuted, fontSize: 13)),
                  ],
                ),
              ),
            )
          : Column(
              children: topStudents.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return _TopStudentTile(rank: i + 1, student: s);
              }).toList(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// UI SUB-COMPONENTS
// ---------------------------------------------------------------------------

class _MenuAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color surface;

  const _MenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kTextDark,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _ModernSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderGray),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: kTextDark,
                          letterSpacing: -0.2)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color, letterSpacing: -0.5)),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class BadgeMetric extends StatelessWidget {
  final String title, value;
  final Color color;

  const BadgeMetric({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class _FunnelArrow extends StatelessWidget {
  const _FunnelArrow();
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kBorderGray);
  }
}

class _TopStudentTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> student;

  const _TopStudentTile({required this.rank, required this.student});

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFEAB308);
    if (rank == 2) return const Color(0xFF94A3B8);
    if (rank == 3) return const Color(0xFFCD7F32);
    return kTextMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rank == 1 ? const Color(0xFFFFFBEB) : kBgGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rank == 1 ? const Color(0xFFFDE68A) : kBorderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _rankColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] ?? 'Student',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark),
                ),
                Text(
                  student['location'] ?? 'Remote',
                  style: const TextStyle(fontSize: 11, color: kTextMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kGreenColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${student['tasksCompleted'] ?? 0} done',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: kGreenColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GrowthLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const GrowthLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 32, color: kBorderGray),
            SizedBox(height: 8),
            Text('Trend data loading...', style: TextStyle(color: kTextMuted, fontSize: 13)),
          ],
        ),
      );
    }

    final spots = data.asMap().entries.map((e) {
      final count = double.tryParse(e.value['count']?.toString() ?? '0') ?? 0;
      return FlSpot(e.key.toDouble(), count);
    }).toList();

    return LineChart(LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: kAccentIndigo,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [kAccentIndigo.withOpacity(0.15), kAccentIndigo.withOpacity(0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        )
      ],
      titlesData: const FlTitlesData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: kBorderGray, strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: kBorderGray),
      ),
    ));
  }
}