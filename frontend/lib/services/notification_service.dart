import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auth_service.dart';
import 'notification_service_api.dart';

/// Central service for handling Background Push Notifications (FCM).
/// This works in tandem with the Socket-based MongoDB messenger for a complete VPS experience.
class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final ValueNotifier<Map<String, dynamic>?> lastMessage =
      ValueNotifier<Map<String, dynamic>?>(null);

  final ValueNotifier<bool> initialized = ValueNotifier<bool>(false);

  /// Global Navigator Key to allow service-level navigation
  /// MUST be assigned to MaterialApp in main.dart
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  bool _isInitializing = false;

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'default_channel',
    'General Alerts',
    description: 'Real-time task and payment updates',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (initialized.value || _isInitializing) return;
    _isInitializing = true;

    try {
      await _requestPermission();
      await _configureForegroundPresentation();
      await _initLocalNotifications();
      await _setupNotificationChannel();
      await _setupForegroundListener();
      await _setupNotificationTapHandlers();
      await _registerCurrentTokenIfPossible();
      await _listenForTokenRefresh();

      initialized.value = true;
      debugPrint('NotificationService: FCM Background delivery active');
    } catch (e, st) {
      debugPrint('NotificationService init failed: $e');
      debugPrint('$st');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<NotificationSettings> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  Future<void> _configureForegroundPresentation() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false, // We show local notification manually in foreground
      badge: true,
      sound: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload?.trim() ?? '';
      if (payload.isNotEmpty) _handleEncodedPayload(payload);
    }
  }

  Future<void> _setupNotificationChannel() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_defaultChannel);
  }

  Future<void> _setupForegroundListener() async {
    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  Future<void> _setupNotificationTapHandlers() async {
    await _openedAppSub?.cancel();
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleRemoteMessageTap(initialMessage);
  }

  Future<void> _registerCurrentTokenIfPossible() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && AuthService.token != null) {
        await NotificationServiceApi.instance.registerFcmToken(token);
      }
    } catch (e) {
      debugPrint('Token sync error: $e');
    }
  }

  Future<void> _listenForTokenRefresh() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      if (AuthService.token != null) {
        await NotificationServiceApi.instance.registerFcmToken(newToken);
      }
    });
  }

  Future<void> refreshTokenRegistration() async => await _registerCurrentTokenIfPossible();

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = _mergeNotificationAndData(message);
    lastMessage.value = data;
    final remoteNotification = message.notification;
    if (remoteNotification == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _defaultChannel.id, _defaultChannel.name,
        channelDescription: _defaultChannel.description,
        importance: Importance.max, priority: Priority.high, playSound: true
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    await _localNotifications.show(
      _notificationIdFor(message), 
      remoteNotification.title, 
      remoteNotification.body, 
      details, 
      payload: jsonEncode(data)
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload?.trim() ?? '';
    if (payload.isNotEmpty) _handleEncodedPayload(payload);
  }

  void _handleEncodedPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) _handlePayloadData(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('Payload error: $e');
    }
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    _handlePayloadData(_mergeNotificationAndData(message));
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION ROUTING (ALIGNED WITH SKILEN BUSINESS LOGIC)
  // ---------------------------------------------------------------------------
  void _handlePayloadData(Map<String, dynamic> data) {
    lastMessage.value = data;
    final String? type = data['type']?.toString();
    final String? taskId = data['taskId']?.toString() ?? data['task_id']?.toString();
    final String? studentId = data['studentId']?.toString();

    if (navigatorKey.currentState == null) {
      debugPrint("NotificationService: Navigator state is null, cannot redirect.");
      return;
    }

    // 1. New Message: Open the Chat instantly
    if (type == 'chat_message' && taskId != null) {
      navigatorKey.currentState!.pushNamed('/taskChat', arguments: {
        'taskId': taskId,
        'taskTitle': data['title'] ?? 'Task Chat',
        'peerStudentId': studentId,
      });
      return;
    }

    // 2. Student Workflow: Open the Workspace Tab
    // Ref: StudentMainShell Index 1 is Workspace
    if (type == 'task_request' || type == 'task_assigned' || type == 'task_declined') {
      navigatorKey.currentState!.pushNamedAndRemoveUntil('/studentMain', (route) => false, arguments: 1);
      return;
    }

    // 3. Financial/Reputation: Open the Feedback/Dashboard Tab
    // Ref: StudentMainShell Index 4 is Feedback
    if (type == 'payment_received' || type == 'withdrawal_update') {
      navigatorKey.currentState!.pushNamedAndRemoveUntil('/studentMain', (route) => false, arguments: 4);
      return;
    }

    // 4. Client Notification: Open My Tasks Screen
    if (type == 'task_submitted' || type == 'payment_needed') {
      navigatorKey.currentState!.pushNamed('/myTasks');
      return;
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _normalizeDataMap(Map<dynamic, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic> _mergeNotificationAndData(RemoteMessage message) {
    final normalized = _normalizeDataMap(message.data);
    final notification = message.notification;
    return {
      ...normalized,
      if (notification?.title != null) 'title': notification!.title,
      if (notification?.body != null) 'body': notification!.body,
      if (message.messageId != null) 'messageId': message.messageId,
      if (message.sentTime != null) 'sentTime': message.sentTime!.millisecondsSinceEpoch,
    };
  }

  int _notificationIdFor(RemoteMessage message) {
    return message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.hashCode;
  }

  Future<void> clearLastMessage() async => lastMessage.value = null;

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _openedAppSub?.cancel();
    initialized.value = false;
  }
}