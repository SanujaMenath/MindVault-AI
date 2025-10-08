import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.notification.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      await Permission.notification.request();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      _log('🔔 Notification tapped with payload: ${response.payload}');
    }
  }

  Future<void> scheduleReminder({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
}) async {
  final notificationTime = scheduledTime.subtract(const Duration(minutes: 10));
  final now = DateTime.now();

  // If it's already too late for the 10-min reminder, schedule for the event time itself
  final finalTime =
      notificationTime.isAfter(now) ? notificationTime : scheduledTime;

  // Avoid scheduling notifications in the past
  if (finalTime.isBefore(now)) {
    _log('⚠️ Skipped scheduling — time is already in the past: $finalTime');
    return;
  }

  await _notifications.zonedSchedule(
    id,
    'Reminder: $title',
    body.isNotEmpty ? body : '⏰ Your reminder is starting soon!',
    tz.TZDateTime.from(finalTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel',
        'Reminders',
        channelDescription: 'Notifications for upcoming reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
    payload: id.toString(),
  );

  _log('✅ Scheduled reminder for: ${finalTime.toLocal()}');
}


  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    _log('🗑️ Cancelled notification: $id');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    _log('🧹 Cancelled all notifications');
  }

  void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'NotificationService');
    }
  }
}
