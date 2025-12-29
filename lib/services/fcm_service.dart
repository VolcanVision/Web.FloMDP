import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
}

/// FCM Service for handling push notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  int? _userId; // The bigint user ID from public.users table

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS and Android 13+)
    await _requestPermission();

    // Initialize local notifications for foreground messages
    await _initializeLocalNotifications();

    // Get FCM token
    await _getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveTokenToDatabase(newToken);
      debugPrint('FCM Token refreshed: $newToken');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'scm_notifications',
        'SCM Notifications',
        description: 'Notifications for SCM App events',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      if (_fcmToken != null) {
        await _saveTokenToDatabase(_fcmToken!);
      }
      
      return _fcmToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Get the user ID from public.users table based on auth.users.id
  Future<int?> _getUserId() async {
    if (_userId != null) return _userId;
    
    try {
      final supabase = SupabaseService().client;
      final authUser = supabase.auth.currentUser;
      
      if (authUser == null) return null;
      
      // Query public.users to get the bigint user_id matching auth_id
      final result = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUser.id)
          .maybeSingle();
      
      if (result != null && result['id'] != null) {
        _userId = result['id'] as int;
        return _userId;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting user ID: $e');
      return null;
    }
  }

  /// Save FCM token to Supabase database
  /// Uses existing schema: fcm_tokens(id, user_id, fcm_token, device_info, is_active, created_at, updated_at)
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final supabase = SupabaseService().client;
      
      // Get the bigint user_id from public.users
      final userId = await _getUserId();
      
      if (userId == null) {
        debugPrint('No user found in public.users, cannot save FCM token');
        return;
      }

      // Check if token already exists for this user
      final existing = await supabase
          .from('fcm_tokens')
          .select('id')
          .eq('user_id', userId)
          .eq('fcm_token', token)
          .maybeSingle();

      if (existing != null) {
        // Update existing token
        await supabase
            .from('fcm_tokens')
            .update({
              'is_active': true,
              'device_info': _getDeviceInfo(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
      } else {
        // Deactivate old tokens for this user on this device type
        await supabase
            .from('fcm_tokens')
            .update({'is_active': false})
            .eq('user_id', userId)
            .eq('device_info', _getDeviceInfo());
        
        // Insert new token
        await supabase.from('fcm_tokens').insert({
          'user_id': userId,
          'fcm_token': token,
          'device_info': _getDeviceInfo(),
          'is_active': true,
        });
      }

      debugPrint('FCM token saved to database for user $userId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Get device info string
  String _getDeviceInfo() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.messageId}');

    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'SCM Notification',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'scm_notifications',
      'SCM Notifications',
      channelDescription: 'Notifications for SCM App events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap from local notification
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate to relevant screen based on payload
  }

  /// Handle notification tap from FCM
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification opened app: ${message.data}');
    // TODO: Navigate to relevant screen based on message data
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    try {
      final supabase = SupabaseService().client;
      final userId = await _getUserId();
      
      if (userId != null && _fcmToken != null) {
        // Mark token as inactive instead of deleting
        await supabase
            .from('fcm_tokens')
            .update({'is_active': false})
            .eq('user_id', userId)
            .eq('fcm_token', _fcmToken!);
      }
      
      await _messaging.deleteToken();
      _fcmToken = null;
      _userId = null;
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  /// Subscribe to a topic (e.g., 'admin', 'accounts', 'production')
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }
  
  /// Call this after user login to save their FCM token
  Future<void> onUserLogin() async {
    _userId = null; // Reset cached user ID
    if (_fcmToken != null) {
      await _saveTokenToDatabase(_fcmToken!);
    }
  }
}
