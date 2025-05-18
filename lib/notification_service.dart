import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'hive_db.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
        // Handle notification tap if needed
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions for Android 13 and above
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted =
          await androidImplementation.requestNotificationsPermission();
      debugPrint('Android notification permission granted: $granted');
    } // No explicit permission request needed for Darwin here, handled in init settings
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(
      NotificationResponse notificationResponse) {
    debugPrint(
        'Notification tapped in background: ${notificationResponse.payload}');
    // Handle background notification tap if needed
  }

  static Future<void> scheduleNotifications() async {
    // Cancel existing notifications
    await _notifications.cancelAll();
    debugPrint('Cancelled all existing notifications');

    // Get work days from settings
    final workDays = HiveDb.getWorkDays();
    debugPrint('Work days: ${_formatWorkDays(workDays)}');

    // Schedule clock in reminder
    final clockInTime = HiveDb.getClockInReminderTime();
    final clockInEnabled = HiveDb.getClockInReminderEnabled();
    debugPrint('Clock in reminder time: ${_formatTimeOfDay(clockInTime)}, enabled: $clockInEnabled');
    
    if (clockInEnabled) {
      await _scheduleWorkDayNotifications(
        id: 1,
        title: 'Time to Clock In',
        body: 'Don\'t forget to clock in for your work day!',
        hour: clockInTime.hour,
        minute: clockInTime.minute,
        workDays: workDays,
      );
    } else {
      debugPrint('Clock in reminders are disabled, skipping scheduling');
    }

    // Schedule clock out reminder
    final clockOutTime = HiveDb.getClockOutReminderTime();
    final clockOutEnabled = HiveDb.getClockOutReminderEnabled();
    debugPrint('Clock out reminder time: ${_formatTimeOfDay(clockOutTime)}, enabled: $clockOutEnabled');
    
    if (clockOutEnabled) {
      await _scheduleWorkDayNotifications(
        id: 2,
        title: 'Time to Clock Out',
        body: 'Don\'t forget to clock out for your work day!',
        hour: clockOutTime.hour,
        minute: clockOutTime.minute,
        workDays: workDays,
      );
    } else {
      debugPrint('Clock out reminders are disabled, skipping scheduling');
    }
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final format = DateFormat.jm(); // Use locale-specific time format
    return format.format(dt);
  }

  static Future<void> _scheduleWorkDayNotifications({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<bool> workDays,
  }) async {
    // Cancel any existing notifications with this ID prefix
    // Note: This cancels all notifications for this type (clock-in/clock-out)
    // Consider a more granular cancellation if needed
    // await _notifications.cancel(id);

    // Get the current date
    final now = tz.TZDateTime.now(tz.local);
    debugPrint('Current time: $now');

    // Schedule for each work day
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      if (workDays[dayIndex]) {
        // Calculate the next occurrence of this day
        final tz.TZDateTime nextOccurrence =
            _getNextOccurrenceOfDay(dayIndex, hour, minute);
        debugPrint(
            'Next occurrence for ${_getDayName(dayIndex)}: $nextOccurrence');

        // Create a unique ID for each day's notification
        final notificationId = id * 10 + dayIndex;

        // Schedule the notification
        try {
          await _notifications.zonedSchedule(
            notificationId,
            title,
            body,
            nextOccurrence,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'work_hours_channel', // Ensure this channel is created if needed
                'Work Hours Reminders',
                channelDescription: 'Notifications for work hours reminders',
                importance: Importance.high,
                priority: Priority.high,
                enableVibration: true,
                enableLights: true,
                playSound: true,
                icon: '@mipmap/launcher_icon',
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
              macOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e) {
          debugPrint('Error scheduling notification $notificationId: $e');
        }

        debugPrint(
            'Scheduled $title for ${_getDayName(dayIndex)} at $hour:$minute (ID: $notificationId)');
      }
    }
  }

  static tz.TZDateTime _getNextOccurrenceOfDay(
      int dayIndex, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Adjust day index to match DateTime weekday (Monday=1, Sunday=7)
    final int targetWeekday = (dayIndex == 6) ? DateTime.sunday : dayIndex + 1;

    // If the scheduled time is in the past for today, move to the next week
    while (
        scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static String _getDayName(int dayIndex) {
    // Use DateTime constants for weekdays
    switch (dayIndex) {
      case 0:
        return 'Monday'; // DateTime.monday == 1
      case 1:
        return 'Tuesday';
      case 2:
        return 'Wednesday';
      case 3:
        return 'Thursday';
      case 4:
        return 'Friday';
      case 5:
        return 'Saturday';
      case 6:
        return 'Sunday'; // DateTime.sunday == 7
      default:
        return 'Unknown';
    }
  }

  static String _formatWorkDays(List<bool> workDays) {
    final List<String> days = [];
    for (int i = 0; i < workDays.length; i++) {
      if (workDays[i]) {
        days.add(_getDayName(i));
      }
    }
    return days.join(', ');
  }

  static Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'work_hours_channel',
      'Work Hours Reminders',
      channelDescription: 'Notifications for work hours reminders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      0,
      'Test Notification',
      'This is a test notification from Work Hours app',
      notificationDetails,
    );
    debugPrint('Test notification shown');
  }
}
