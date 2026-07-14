import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/socketservice.dart'; 
import 'admin_user_detail_screen.dart'; // UPDATED IMPORT

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  AdminUsersScreenState createState() => AdminUsersScreenState();
}

class AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService adminService = AdminService();
  List<Map<String, dynamic>> users = [];
  bool loading = false;
  
  String roleFilter = '';
  final TextEditingController locationController = TextEditingController();
  final TextEditingController domainController = TextEditingController();

  static const Color primaryRed = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _initializeRealTimeUsers();
  }

  /// Sets up socket listeners and initial data load
  Future<void> _initializeRealTimeUsers() async {
    await loadUsers();

    // ============================================================
    // MODIFICATION: REAL-TIME DYNAMIC SYNC
    // ============================================================
    SocketService.connect();
    SocketService.joinAdminRoom();

    // Listen for new signups platform-wide
    SocketService.on('user_registered', (_) {
      if (mounted) loadUsers(isSilent: true);
    });

    // Listen for any user updating their profile (Bank info, skills, etc.)
    SocketService.on('user_profile_updated', (_) {
      if (mounted) loadUsers(isSilent: true);
    });
  }

  @override
  void dispose() {
    // CLEAN UP
    SocketService.off('user_registered');
    SocketService.off('user_profile_updated');
    locationController.dispose();
    domainController.dispose();
    super.dispose();
  }

  /// Fetches user list. [isSilent] prevents full-screen spinner during live updates.
  Future<void> loadUsers({bool isSilent = false}) async {
    if (mounted && !isSilent) setState(() => loading = true);
    try {
      final res = await adminService.getUsers(
        role: roleFilter.isEmpty ? null : roleFilter,
        location: locationController.text.trim().isEmpty
            ? null
            : locationController.text.trim(),
        domain: domainController.text.trim().isEmpty
            ? null
            : domainController.text.trim(),
      );

      // Hide admins from the list for security/cleanliness
      final filtered = res.where((u) => (u['role'] ?? '') != 'admin').toList();

      if (!mounted) return;
      setState(() => users = filtered);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    } finally {
      if (mounted && !isSilent) setState(() => loading = false);
    }
  }

  Future<void> _toggleApproval(Map<String, dynamic> user) async {
    final id = user['_id'];
    final newVal = !(user['isApproved'] ?? true);
    try {
      final res = await adminService.updateUserApproval(id, newVal);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Status Updated')),
      );
      await loadUsers(isSilent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user: $e')),
      );
    }
  }

  Future<void> _confirmToggleApproval(Map<String, dynamic> user) async {
    final bool current = user['isApproved'] ?? true;
    final String action = current ? 'ban (deactivate)' : 'activate';
    final String role = (user['role'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${action[0].toUpperCase()}${action.substring(1)} $role'),
        content: Text('Are you sure you want to $action ${user['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (ok == true) await _toggleApproval(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Community Management', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => loadUsers())
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildFiltersCard(),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const Center(child: Text('No users found.', style: TextStyle(fontSize: 13, color: Colors.black54)))
                    : RefreshIndicator(
                        onRefresh: loadUsers,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final u = users[index];
                            return _UserCard(
                              user: u,
                              onToggleApproval: () => _confirmToggleApproval(u),
                              onTap: () {
                                // ============================================================
                                // MODIFICATION: DYNAMIC DETAIL NAVIGATION FOR ALL ROLES
                                // ============================================================
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminUserDetailScreen(
                                      userId: u['_id'],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vetting Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _roleChip('All', roleFilter.isEmpty),
              _roleChip('student', roleFilter == 'student'),
              _roleChip('client', roleFilter == 'client'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'City/Location', isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (_) => loadUsers(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: domainController,
                  decoration: const InputDecoration(labelText: 'Expertise/Domain', isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (_) => loadUsers(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: loadUsers,
                icon: const Icon(Icons.search),
                style: IconButton.styleFrom(backgroundColor: primaryRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label, bool selected) {
    return ChoiceChip(
      label: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black87)),
      selected: selected,
      selectedColor: primaryRed,
      onSelected: (_) {
        setState(() { roleFilter = label == 'All' ? '' : label; });
        loadUsers();
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggleApproval;
  final VoidCallback? onTap;

  const _UserCard({required this.user, required this.onToggleApproval, this.onTap});

  @override
  Widget build(BuildContext context) {
    final String name = user['name'] ?? 'Unknown';
    final String email = user['email'] ?? '';
    final String role = user['role'] ?? '';
    final String location = user['location'] ?? 'Remote';
    final bool isApproved = user['isApproved'] ?? true;

    final bool isStudent = role == 'student';
    final Color roleColor = isStudent ? Colors.indigo : Colors.teal;
    final Color statusColor = isApproved ? Colors.green : Colors.redAccent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isApproved ? Colors.white : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withOpacity(0.1),
              child: Icon(isStudent ? Icons.school : Icons.business, color: roleColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(role.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: roleColor)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(location, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(isApproved ? 'ACTIVE' : 'BANNED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                const SizedBox(height: 4),
                Switch.adaptive(
                  value: isApproved,
                  activeColor: Colors.green,
                  onChanged: (_) => onToggleApproval(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}