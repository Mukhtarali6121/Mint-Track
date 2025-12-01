import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Local notifications are not supported on web
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    // Handle notification tap - you can navigate to specific screens here
    debugPrint('Notification tapped: ${notificationResponse.payload}');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    // Local notifications are not supported on web
    if (kIsWeb) return false;
    
    // Request notification permission
    final status = await Permission.notification.request();
    
    if (status.isGranted) {
      // For Android 13+ (API level 33+), also request exact alarm permission
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
      return true;
    }
    return false;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    // Local notifications are not supported on web
    if (kIsWeb) return false;
    
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Show a simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Local notifications are not supported on web
    if (kIsWeb) return;
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'expense_tracker_channel',
      'Expense Tracker Notifications',
      channelDescription: 'Notifications for expense tracking reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Schedule a daily notification at 9:00 PM
  /// Schedule a daily notification at 9:00 PM
  Future<void> scheduleDailyNotification() async {
    // Local notifications are not supported on web
    if (kIsWeb) return;
    
    // Cancel any existing daily notification
    await cancelNotification(1);

    final scheduledTime = _nextInstanceOfNinePM();
    debugPrint('Scheduling daily notification for: $scheduledTime');
    debugPrint('Current time: ${tz.TZDateTime.now(tz.local)}');

    // Schedule new daily notification at 9:00 PM
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      1, // notification ID
      '💰 Daily Expense Reminder',
      'Don\'t forget to track your expenses today! Keep your finances organized.',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expense_tracker_channel',
          'Expense Tracker Notifications',
          channelDescription: 'Daily reminders to track expenses',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'daily_reminder',

      // -----------------
      //  THE FIX IS HERE
      // -----------------
      // This tells the plugin to repeat the notification daily at the specified time.
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Verify the notification was scheduled
    final pendingNotifications = await getPendingNotifications();
    debugPrint('Pending notifications: ${pendingNotifications.length}');
    for (final notification in pendingNotifications) {
      debugPrint('Pending notification: ${notification.id} - ${notification.title}');
    }
  }

  /// Get the next instance of 9:00 PM
  tz.TZDateTime _nextInstanceOfNinePM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      21, // 9:00 PM
    );

    // If 9:00 PM has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Show a test notification immediately
  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    await showNotification(
      id: 999,
      title: '🔔 Notification Test',
      body: 'Notifications are working perfectly! You\'ll receive daily reminders at 9:00 PM.',
      payload: 'test_notification',
    );
  }

  /// Schedule a test notification for 1 minute from now (for testing)
  Future<void> scheduleTestNotificationInOneMinute() async {
    if (kIsWeb) return;
    
    final now = tz.TZDateTime.now(tz.local);
    final testTime = now.add(const Duration(minutes: 1));
    
    debugPrint('Scheduling test notification for: $testTime');
    debugPrint('Current time: $now');

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      999, // notification ID
      '🧪 Test Notification',
      'This is a test notification scheduled for 1 minute from now.',
      testTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expense_tracker_channel',
          'Expense Tracker Notifications',
          channelDescription: 'Test notifications',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'test_scheduled_notification',
    );

    // Verify the notification was scheduled
    final pendingNotifications = await getPendingNotifications();
    debugPrint('Pending notifications after test scheduling: ${pendingNotifications.length}');
  }

  /// Reschedule daily notification (useful when app starts)
  Future<void> rescheduleDailyNotification() async {
    if (kIsWeb) return;
    
    debugPrint('Rescheduling daily notification...');
    await scheduleDailyNotification();
  }

  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (kIsWeb) return [];
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

}
