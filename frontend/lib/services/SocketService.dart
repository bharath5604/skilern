// lib/services/socket_service.dart
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../env.dart';

/// The central real-time bridge for SKILEN.
/// This service manages the WebSocket connection and room subscriptions.
class SocketService {
  static IO.Socket? socket;

  /// Initializes the connection to the Node.js server.
  /// Uses WebSocket transport only for better performance and battery life.
  static void connect() {
    if (socket != null && socket!.connected) {
      debugPrint('SocketService: Already connected.');
      return;
    }

    debugPrint('SocketService: Connecting to ${Env.apiBaseUrl}...');

    socket = IO.io(Env.apiBaseUrl, 
      IO.OptionBuilder()
        .setTransports(['websocket']) // Force WebSocket to avoid polling overhead
        .enableAutoConnect() 
        .enableReconnection()          // Automatically reconnect if connection drops
        .setReconnectionAttempts(99)   // Try to reconnect 99 times before failing
        .setReconnectionDelay(1000)    // Wait 1 second between attempts
        .build()
    );

    // Standard lifecycle listeners for debugging
    socket!.onConnect((_) {
      debugPrint('SocketService: ✅ Connected to server');
    });

    socket!.onDisconnect((reason) {
      debugPrint('SocketService: ❌ Disconnected - Reason: $reason');
    });

    socket!.onConnectError((data) {
      debugPrint('SocketService: ⚠️ Connection Error: $data');
    });
  }

  // ============================================================
  // ROOM MANAGEMENT (MODIFIED FOR THREAD-SPECIFIC PRIVACY)
  // ============================================================

  /// Join a room dedicated to a specific task thread.
  /// 
  /// MODIFICATION: Added the optional [studentId] parameter.
  /// - If [studentId] is provided: Joins the Admin-Student vetting room.
  /// - If [studentId] is null: Joins, {String? studentId}, {String? studentId} the Admin-Client negotiation room.
  static void joinTaskRoom(String taskId, {String? studentId}) {
    if (taskId.isEmpty) return;

    // Logic: Split the global task room into sub-rooms
    // Ensure that students never hear client messages and vice-versa.
    final String roomName = (studentId != null && studentId.trim().isNotEmpty)
        ? '${taskId}_student_${studentId.trim()}'
        : '${taskId}_client';

    socket?.emit('join_task', roomName); 
    debugPrint('SocketService: Joined Specific Thread Room -> $roomName');
  }
  

  /// Join a private room dedicated to the current user.
  /// Use this on the Dashboard or Profile screens to receive:
  /// - 'feedback_update' (Live rating updates)
  /// - 'payout_processed' (Wallet updates)
  /// - 'user_status_update' (Account approval/ban signals)
  static void joinUserRoom(String userId) {
    if (userId.isEmpty) return;
    socket?.emit('join_user', userId);
    debugPrint('SocketService: Joined User Private Room -> $userId');
  }

  /// Special room for Admins to receive platform-wide alerts.
  static void joinAdminRoom() {
    socket?.emit('join_user', 'admin_room');
    debugPrint('SocketService: Admin joined broadcast room');
  }

  // ============================================================
  // EVENT HANDLING
  // ============================================================

  /// Utility to quickly subscribe to any socket event.
  /// Example: SocketService.on('new_message', (data) => _handleMsg(data));
  static void on(String event, Function(dynamic) handler) {
    socket?.on(event, handler);
  }

  /// Utility to unsubscribe from an event when a screen is disposed.
  /// Always call this in your widget's dispose() method to prevent memory leaks.
  static void off(String event) {
    socket?.off(event);
  }

  /// Completely close the connection.
  static void disconnect() {
    socket?.disconnect();
    socket = null;
    debugPrint('SocketService: Connection closed manually.');
  }
}