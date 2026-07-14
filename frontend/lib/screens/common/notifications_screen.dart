import 'package:flutter/material.dart';
import '../../services/notification_service_api.dart';
import '../../services/socketservice.dart'; // MODIFICATION: IMPORT SOCKET SERVICE
import '../../services/auth_service.dart';   // MODIFICATION: FOR USER ID

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationServiceApi service = NotificationServiceApi.instance;

  List<Map<String, dynamic>> notifications = [];
  bool loading = false;
  bool markingAllRead = false;
  DateTime? lastFetched;

  static const Color primary = Color(0xFFDC2626);
  static const Color bg = Color(0xFFF6F7FB);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color unreadBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _initializeNotificationSync();
  }

  // ============================================================
  // MODIFICATION: REAL-TIME DYNAMIC SYNC
  // ============================================================
  Future<void> _initializeNotificationSync() async {
    // 1. Initial data fetch from MongoDB
    await _loadNotifications();

    // 2. Connect to VPS Socket Server
    SocketService.connect();
    
    final currentUid = AuthService.userId;
    if (currentUid != null) {
      // Join private room to hear specific alerts
      SocketService.joinUserRoom(currentUid);
    }

    // 3. Listen for "New Notification" signal from MongoDB via Sockets
    SocketService.on('new_notification', (data) {
      if (mounted) {
        debugPrint("Notifications: Real-time alert received from VPS.");
        setState(() {
          // Logic: Convert dynamic data to Map and insert at the top of the list
          final Map<String, dynamic> newNotif = Map<String, dynamic>.from(data);
          
          // Check for duplicate (if refresh was triggered simultaneously)
          final String newId = (newNotif['_id'] ?? '').toString();
          bool exists = notifications.any((n) => (n['_id'] ?? '').toString() == newId);
          
          if (!exists) {
            notifications.insert(0, newNotif);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // MODIFICATION: CLEAN UP SOCKET LISTENER
    SocketService.off('new_notification');
    super.dispose();
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (mounted && !refresh) {
      setState(() => loading = true);
    }

    try {
      final list = await service.getNotifications(
        since: refresh ? lastFetched : null,
      );

      if (!mounted) return;

      setState(() {
        if (refresh && lastFetched != null) {
          final existingIds = notifications
              .map((n) => (n['_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet();

          final freshItems = list.where((n) {
            final id = (n['_id'] ?? '').toString();
            return id.isEmpty || !existingIds.contains(id);
          }).toList();

          notifications = [...freshItems, ...notifications];
        } else {
          notifications = List<Map<String, dynamic>>.from(list);
        }

        lastFetched = DateTime.now().toUtc();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load notifications: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    if (markingAllRead) return;

    final ids = notifications
        .where((n) => !(n['isRead'] ?? false))
        .map((n) => (n['_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    if (ids.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications are already marked as read'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => markingAllRead = true);

    try {
      await service.markAsRead(ids);

      if (!mounted) return;

      setState(() {
        for (final n in notifications) {
          n['isRead'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark as read: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => markingAllRead = false);
      }
    }
  }

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _formatDate(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return '';

    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final amPm = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year  $hour:$minute $amPm';
  }

  IconData _notificationIcon(bool isRead, String title, String body) {
    final text = '$title $body'.toLowerCase();

    if (text.contains('payment') || text.contains('wallet')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (text.contains('task') || text.contains('invite')) {
      return Icons.work_outline_rounded;
    }
    if (text.contains('message') || text.contains('chat')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (text.contains('approve') || text.contains('approved')) {
      return Icons.verified_outlined;
    }
    if (text.contains('reject') || text.contains('declined')) {
      return Icons.cancel_outlined;
    }

    return isRead
        ? Icons.notifications_none_rounded
        : Icons.notifications_active_rounded;
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 100),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: const [
              CircleAvatar(
                radius: 30,
                backgroundColor: Color(0x14DC2626),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: primary,
                  size: 30,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'No notifications yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Real-time alerts for tasks, payments, and chats will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final title = _safeText(n['title'], fallback: 'Notification');
    final body = _safeText(n['body']);
    final createdAtText = _formatDate(n['createdAt']);
    final isRead = n['isRead'] == true;
    final icon = _notificationIcon(isRead, title, body);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead ? border : unreadBlue.withOpacity(0.22),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isRead
                ? const Color(0xFFF3F4F6)
                : unreadBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: isRead ? textMuted : unreadBlue,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textDark,
                  fontSize: 14.5,
                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                ),
              ),
            ),
            if (!isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: unreadBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body.isNotEmpty ? body : createdAtText,
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 12.8,
                  height: 1.45,
                ),
              ),
              if (createdAtText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  createdAtText,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        notifications.where((n) => !(n['isRead'] ?? false)).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: markingAllRead ? null : _markAllRead,
            icon: markingAllRead
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.done_all_rounded),
                      if (unreadCount > 0)
                        Positioned(
                          right: -4,
                          top: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: loading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              color: primary,
              onRefresh: () => _loadNotifications(refresh: true),
              child: notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                      children: [
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: unreadBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: unreadBlue.withOpacity(0.14),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.notifications_active_rounded,
                                  color: unreadBlue,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: unreadBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...notifications.map(_buildNotificationCard),
                      ],
                    ),
            ),
    );
  }
}