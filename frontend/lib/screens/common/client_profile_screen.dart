import 'package:flutter/material.dart';
import '../../services/client_service.dart';

class ClientProfileScreen extends StatefulWidget {
  final String clientId;

  const ClientProfileScreen({Key? key, required this.clientId})
      : super(key: key);

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  static const Color primaryRed = Color(0xFFE53935);

  final ClientService service = ClientService();

  Map<String, dynamic>? data;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final res = await service.getPublicProfile(widget.clientId);
      if (!mounted) return;

      setState(() => data = _normalizeMap(res));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load client: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractRecentTasks(dynamic recentTasksRaw) {
    if (recentTasksRaw is! List) return <Map<String, dynamic>>[];

    return recentTasksRaw
        .map<Map<String, dynamic>>((item) {
          if (item is Map<String, dynamic>) return item;
          if (item is Map) {
            return item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
          return <String, dynamic>{};
        })
        .where((task) => task.isNotEmpty)
        .toList();
  }

  String _safeText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryRed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatusChip(String status) {
    final normalized = status.trim().toLowerCase();

    Color color;
    String label;

    switch (normalized) {
      case 'open':
        color = Colors.blueGrey;
        label = 'Open';
        break;
      case 'assigned':
        color = primaryRed;
        label = 'Assigned';
        break;
      case 'under_review':
        color = const Color(0xFFFB8C00);
        label = 'Under review';
        break;
      case 'completed':
        color = const Color(0xFF2E7D32);
        label = 'Completed';
        break;
      case 'declined':
        color = Colors.redAccent;
        label = 'Declined';
        break;
      default:
        color = Colors.grey;
        label = status.isEmpty ? 'Unknown' : status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = data;

    final company = _safeText(profile?['company']);
    final name = _safeText(profile?['name']);
    final email = _safeText(profile?['email']);
    final location = _safeText(profile?['location']);
    final domain = _safeText(profile?['domain']);
    final description = _safeText(profile?['description']);
    final recentTasks = _extractRecentTasks(profile?['recentTasks']);

    final displayTitle = company.isNotEmpty ? company : name;
    final displaySubtitle =
        company.isNotEmpty && name.isNotEmpty ? name : email;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Client Profile'),
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null || profile.isEmpty
              ? const Center(
                  child: Text(
                    'No client data found',
                    style: TextStyle(fontSize: 14),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFEBEE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.business,
                                    color: primaryRed,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayTitle.isEmpty
                                            ? 'Client'
                                            : displayTitle,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (displaySubtitle.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          displaySubtitle,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Client details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildInfoTile(
                                  icon: Icons.email_outlined,
                                  label: 'Email',
                                  value: email,
                                ),
                                _buildInfoTile(
                                  icon: Icons.location_on_outlined,
                                  label: 'Location',
                                  value: location,
                                ),
                                _buildInfoTile(
                                  icon: Icons.work_outline,
                                  label: 'Domain',
                                  value: domain,
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Note: Payments for tasks are currently handled directly between client and student (outside the app).',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recent tasks',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (recentTasks.isEmpty)
                                  const Text(
                                    'No recent tasks.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  )
                                else
                                  ...recentTasks.map((task) {
                                    final title = _safeText(task['title']);
                                    final status = _safeText(task['status']);
                                    final rating = task['rating'];
                                    final ratingText = rating == null ||
                                            rating.toString().trim().isEmpty
                                        ? 'Not rated'
                                        : rating.toString();

                                    return Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAFAFA),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title.isEmpty
                                                      ? 'Untitled task'
                                                      : title,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildTaskStatusChip(status),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Rating: $ratingText',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}