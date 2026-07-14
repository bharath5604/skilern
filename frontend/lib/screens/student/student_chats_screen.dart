import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../services/auth_service.dart';
import '../../services/socketservice.dart'; 
import '../common/task_chat_screen.dart';

class StudentChatsScreen extends StatefulWidget {
  const StudentChatsScreen({Key? key}) : super(key: key);

  @override
  State<StudentChatsScreen> createState() => _StudentChatsScreenState();
}

class _StudentChatsScreenState extends State<StudentChatsScreen> {
  final TaskService _taskService = TaskService();

  bool _loading = false;
  
  // Logic: Store tasks in a list of maps to handle unread metadata
  List<Map<String, dynamic>> _chatData = []; 

  static const Color primaryPurple = Color(0xFF6A11CB);
  static const Color secondaryPurple = Color(0xFF2575FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color backgroundColor = Color(0xFFF5F7FB);

  @override
  void initState() {
    super.initState();
    _initializeRealTimeInbox();
  }

  /// Sets up real-time sync and initial data load
  Future<void> _initializeRealTimeInbox() async {
    // 1. Initial Load
    await _loadChatTasks();

    // ============================================================
    // MODIFICATION: REAL-TIME DYNAMIC SYNC
    // ============================================================
    SocketService.connect();
    
    final currentUid = AuthService.userId;
    if (currentUid != null) {
      // Logic: Join the Student's unique private room.
      // This is crucial for hearing about NEW threads created by Admins.
      SocketService.joinUserRoom(currentUid);
    }
    
    // Listen for new messages platform-wide targeting this user
    SocketService.on('new_message', (data) {
      if (mounted) {
        debugPrint("Chat List: New message/thread detected, refreshing list...");
        // Silent reload ensures the new card pops up at the top instantly
        _loadChatTasks(isSilent: true); 
      }
    });
  }

  @override
  void dispose() {
    // MODIFICATION: CLEAN UP
    SocketService.off('new_message');
    super.dispose();
  }

  /// Fetches tasks. [isSilent] prevents showing the full-screen spinner during live updates.
  Future<void> _loadChatTasks({bool isSilent = false}) async {
    if (mounted && !isSilent) setState(() => _loading = true);

    try {
      // Hits /api/tasks/chat-tasks
      final List<Task> tasks = await _taskService.getChatTasksForStudent();

      if (!mounted) return;
      setState(() {
        _chatData = tasks.map((t) => {
          'task': t,
          // Unread logic: If task is under_review or assigned and has no rating, 
          // we treat it as an active conversation context.
          'unreadCount': 0 // Placeholder: backend can eventually send real counts
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync conversations: $e'),
          backgroundColor: primaryPurple,
        ),
      );
    } finally {
      if (mounted && !isSilent) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(Task task) async {
    // Navigate to chat and wait for return
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskChatScreen(
          taskId: task.id,
          taskTitle: task.title,
          peerStudentId: AuthService.userId, // Passing self as peer for thread isolation
        ),
      ),
    );

    // After returning from a chat, we refresh to clear states if needed
    if (mounted) {
      _loadChatTasks(isSilent: true);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return Colors.blue;
      case 'assigned': return secondaryPurple;
      case 'under_review': return Colors.orange;
      case 'completed': return Colors.green;
      case 'declined': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'under_review': return 'Vetting';
      case 'assigned': return 'Active';
      case 'completed': return 'Closed';
      default:
        if (status.isEmpty) return 'Unknown';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryPurple),
          onPressed: () {
            // Navigate back to the Home index of the main shell
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/studentMain', 
              (route) => false, 
              arguments: 2 
            );
          },
        ),
        title: const Text(
          'Message Inbox',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textDark),
        ),
        actions: [
           IconButton(
             onPressed: () => _loadChatTasks(), 
             icon: const Icon(Icons.refresh_rounded, color: primaryPurple)
           ),
           const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: primaryPurple,
        onRefresh: () => _loadChatTasks(),
        child: _loading && _chatData.isEmpty
            ? const Center(child: CircularProgressIndicator(color: primaryPurple))
            : _chatData.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _chatData.length,
                    itemBuilder: (context, index) {
                      final item = _chatData[index];
                      return _buildChatTile(item['task'], index, item['unreadCount'] ?? 0);
                    },
                  ),
      ),
    );
  }

  Widget _buildChatTile(Task task, int index, int unreadCount) {
    final statusColor = _statusColor(task.status);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 40)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryPurple.withOpacity(0.1), secondaryPurple.withOpacity(0.05)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: primaryPurple, size: 24),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title, 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis, 
                style: const TextStyle(fontSize: 14, color: textDark, fontWeight: FontWeight.w700)
              ),
              const SizedBox(height: 4),
              if (task.rating > 0)
                Row(
                  children: List.generate(5, (i) => Icon(
                    Icons.star,
                    size: 14,
                    color: i < task.rating ? Colors.amber : Colors.grey[300],
                  )),
                )
              else
                Text("Chat regarding project requirement", style: TextStyle(fontSize: 11, color: textMuted)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _statusLabel(task.status),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor),
                ),
              ),
              const SizedBox(height: 6),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
            ],
          ),
          onTap: () => _openChat(task),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Your inbox is empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMuted)),
          const SizedBox(height: 8),
          const Text('Wait for Admins to contact you for matching tasks.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}