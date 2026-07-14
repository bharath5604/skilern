import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/socketservice.dart'; // MODIFICATION: IMPORT SOCKETS
import 'admin_task_detail_screen.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({Key? key}) : super(key: key);

  @override
  AdminTasksScreenState createState() => AdminTasksScreenState();
}

class AdminTasksScreenState extends State<AdminTasksScreen> {
  final AdminService adminService = AdminService();
  List<Map<String, dynamic>> tasks = [];
  bool loading = false;

  // Filter State
  String? selectedLocation;
  String? selectedDomain;
  String? selectedStatus;

  // Filter Options
  List<dynamic> locations = [];
  List<dynamic> domains = [];

  static const List<String> _statusOptions = <String>[
    'open',
    'assigned',
    'under_review',
    'completed',
    'declined',
  ];

  static const Color _primaryRed = Color(0xFFE53935);
  static const Color _backgroundGray = Color(0xFFF4F5F9);
  static const Color _cardWhite = Colors.white;
  static const Color _borderGray = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _initializeDataAndSockets();
  }

  // ============================================================
  // MODIFICATION: REAL-TIME DYNAMIC SYNC
  // ============================================================
  Future<void> _initializeDataAndSockets() async {
    // Initial fetch of filters and task list
    await _loadFiltersAndTasks();

    // Connect to Socket server
    SocketService.connect();
    SocketService.joinAdminRoom();

    // Listen for new tasks (Registered and Guest)
    SocketService.on('task_created', (_) => loadTasks(isSilent: true));
    SocketService.on('emergency_task_created', (_) => loadTasks(isSilent: true));
    
    // Listen for lifecycle updates (Vetting, completion, etc.)
    SocketService.on('task_update', (_) => loadTasks(isSilent: true));
    SocketService.on('admin_stats_update', (_) => loadTasks(isSilent: true));
  }

  @override
  void dispose() {
    // MODIFICATION: CLEAN UP SOCKETS
    SocketService.off('task_created');
    SocketService.off('emergency_task_created');
    SocketService.off('task_update');
    SocketService.off('admin_stats_update');
    super.dispose();
  }

  Future<void> _loadFiltersAndTasks() async {
    setState(() => loading = true);
    try {
      final filterData = await adminService.getTaskFilters();
      if (!mounted) return;

      setState(() {
        locations = List.from(filterData['locations'] ?? const []);
        domains = List.from(filterData['domains'] ?? const []);
      });

      await loadTasks();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to load filters');
        setState(() => loading = false);
      }
    }
  }

  /// Fetches tasks. [isSilent] allows updating the list without showing the spinner.
  Future<void> loadTasks({bool isSilent = false}) async {
    if (mounted && !isSilent) setState(() => loading = true);
    try {
      final list = await adminService.getTasks(
        location: selectedLocation,
        domain: selectedDomain,
        status: selectedStatus,
      );
      if (!mounted) return;
      setState(() => tasks = list);
    } catch (e) {
      if (!mounted) _showSnackBar('Failed to sync tasks');
    } finally {
      if (mounted && !isSilent) setState(() => loading = false);
    }
  }

  void _clearAllFilters() {
    setState(() {
      selectedLocation = null;
      selectedDomain = null;
      selectedStatus = null;
    });
    loadTasks();
  }

  bool get _hasActiveFilters =>
      selectedLocation != null ||
      selectedDomain != null ||
      selectedStatus != null;

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Registry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: _cardWhite,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_hasActiveFilters)
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
              onPressed: _clearAllFilters,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: _primaryRed,
            onPressed: loading ? null : () => loadTasks(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      backgroundColor: _backgroundGray,
      body: Column(
        children: [
          // ============================================================
          // MODIFICATION: RESPONSIVE FILTER BAR
          // ============================================================
          Container(
            color: _cardWhite,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: isDesktop 
              ? _buildDesktopFilters() // ALL IN ONE ROW
              : _buildMobileFilters(),  // STACKED DESIGN
          ),

          if (tasks.isNotEmpty && !loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('${tasks.length} projects found', 
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),

          Expanded(
            child: loading && tasks.isEmpty
                ? const Center(child: CircularProgressIndicator(color: _primaryRed))
                : tasks.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: _primaryRed,
                        onRefresh: loadTasks,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final t = tasks[index];
                            final bool isGuest = t['isGuestTask'] == true;
                            
                            final guest = t['guestInfo'] is Map ? t['guestInfo'] : {};
                            final client = t['client'] is Map ? t['client'] : {};

                            final String clientName = isGuest 
                                ? "${guest['name'] ?? 'Guest'}" 
                                : (client['name'] ?? 'Registered Client');
                            
                            final String company = isGuest 
                                ? "Emergency Lead" 
                                : (client['company'] ?? 'Individual');

                            return _TaskCard(
                              title: (t['title'] ?? 'Untitled').toString(),
                              domain: (t['domain'] ?? 'General').toString(),
                              location: (t['location'] ?? 'N/A').toString(),
                              status: (t['status'] ?? 'open').toString(),
                              clientName: clientName,
                              company: company,
                              budget: t['budget'] != null ? '₹${t['budget']}' : 'TBD',
                              isGuest: isGuest,
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => AdminTaskDetailScreen(task: t)),
                                );
                                if (changed == true) loadTasks();
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

  // --- DESKTOP VIEW: SINGLE ROW ---
  Widget _buildDesktopFilters() {
    return Row(
      children: [
        Expanded(
          child: _DropdownFilter(
            label: 'Location',
            icon: Icons.location_on_outlined,
            value: selectedLocation,
            items: locations,
            onChanged: (val) {
              setState(() => selectedLocation = val);
              loadTasks();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DropdownFilter(
            label: 'Domain',
            icon: Icons.category_outlined,
            value: selectedDomain,
            items: domains,
            onChanged: (val) {
              setState(() => selectedDomain = val);
              loadTasks();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatusFilter(
            value: selectedStatus,
            onChanged: (val) {
              setState(() => selectedStatus = val);
              loadTasks();
            },
          ),
        ),
      ],
    );
  }

  // --- MOBILE VIEW: CURRENT DESIGN ---
  Widget _buildMobileFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DropdownFilter(
                label: 'Location',
                icon: Icons.location_on_outlined,
                value: selectedLocation,
                items: locations,
                onChanged: (val) {
                  setState(() => selectedLocation = val);
                  loadTasks();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DropdownFilter(
                label: 'Domain',
                icon: Icons.category_outlined,
                value: selectedDomain,
                items: domains,
                onChanged: (val) {
                  setState(() => selectedDomain = val);
                  loadTasks();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatusFilter(
          value: selectedStatus,
          onChanged: (val) {
            setState(() => selectedStatus = val);
            loadTasks();
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No projects found matching filters', 
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UI SUB-WIDGETS
// ---------------------------------------------------------------------------

class _StatusFilter extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _StatusFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Workflow Status',
        prefixIcon: const Icon(Icons.flag_outlined, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All Statuses')),
        ...AdminTasksScreenState._statusOptions.map(
          (s) => DropdownMenuItem<String>(value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12))),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<dynamic> items;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({required this.label, required this.icon, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        ...items.map(
          (v) => DropdownMenuItem<String>(value: v.toString(), child: Text(v.toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title, domain, location, status, clientName, company, budget;
  final bool isGuest;
  final VoidCallback onTap;

  const _TaskCard({required this.title, required this.domain, required this.location, required this.status, required this.clientName, required this.company, required this.budget, required this.onTap, required this.isGuest});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return Colors.blue;
      case 'assigned': return Colors.orange;
      case 'under_review': return Colors.indigo;
      case 'completed': return Colors.green;
      case 'declined': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sColor = _statusColor(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGuest)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Text("EMERGENCY", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.orange)),
                  ),
                Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: sColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("$clientName • $company", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoPill(Icons.location_on_outlined, location, Colors.grey),
                    _infoPill(Icons.payments_outlined, budget, Colors.green),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}