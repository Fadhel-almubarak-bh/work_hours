import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../data/local/hive_db.dart';
import '../data/repositories/work_hours_repository.dart';
import '../data/models/work_entry.dart';

class WindowsTrayService {
  static final SystemTray _systemTray = SystemTray();
  static final Menu _menu = Menu();
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final WorkHoursRepository _repository = WorkHoursRepository();
  static bool _isInitialized = false;
  static String? _iconPath;

  static Future<void> initialize() async {
    if (!Platform.isWindows || _isInitialized) return;

    try {
      // Initialize repository
      await _repository.initialize();

      // Copy icon to temporary directory for notifications
      final tempDir = await getTemporaryDirectory();
      _iconPath = '${tempDir.path}/work_hours.png';
      final byteData = await rootBundle.load('assets/work_hours.png');
      final file = File(_iconPath!);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Initialize notifications
      final windowsSettings = WindowsInitializationSettings(
        appName: 'Work Hours',
        appUserModelId: 'com.workhours.app',
        guid: 'work-hours-app-guid',
      );
      final initSettings = InitializationSettings(windows: windowsSettings);
      await _notifications.initialize(initSettings);

      // Initialize system tray
      await _systemTray.initSystemTray(
        title: "Work Hours",
        iconPath: _iconPath!,
      );

      // Create menu items
      await _menu.buildFrom([
        MenuItemLabel(
          label: 'Clock In/Out',
          onClicked: (menuItem) => _handleClockInOut(),
        ),
        MenuItemLabel(
          label: 'Show Current Status',
          onClicked: (menuItem) => _showCurrentStatus(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Exit',
          onClicked: (menuItem) => _handleExit(),
        ),
      ]);

      // Set the context menu
      await _systemTray.setContextMenu(_menu);

      // Set tooltip
      await _systemTray.setToolTip("Work Hours Tracker");

      // Update tray icon and tooltip periodically
      _startPeriodicUpdate();

      _isInitialized = true;
      debugPrint('✅ Windows tray service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Windows tray service: $e');
    }
  }

  static void _startPeriodicUpdate() {
    // Update every minute
    Future.delayed(const Duration(minutes: 1), () {
      _updateTrayStatus();
      _startPeriodicUpdate();
    });
  }

  static Future<void> _updateTrayStatus() async {
    if (!Platform.isWindows || !_isInitialized) return;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entry = await _repository.getWorkEntry(today);
      
      final isClockedIn = entry != null && entry.clockIn != null && entry.clockOut == null;
      final duration = isClockedIn ? now.difference(entry!.clockIn!).inMinutes : 0;
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      
      final status = isClockedIn 
          ? 'Clocked In - ${hours}h ${minutes}m'
          : 'Clocked Out';
      
      await _systemTray.setToolTip("Work Hours: $status");
    } catch (e) {
      debugPrint('❌ Error updating tray status: $e');
    }
  }

  static Future<void> _handleClockInOut() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entry = await _repository.getWorkEntry(today);
      
      if (entry == null || entry.clockOut != null) {
        // Clock in
        await _repository.saveWorkEntry(WorkEntry(
          date: now,
          clockIn: now,
          duration: 0,
          isOffDay: false,
        ));
      } else {
        // Clock out
        await _repository.saveWorkEntry(entry.copyWith(
          clockOut: now,
          duration: now.difference(entry.clockIn!).inMinutes,
        ));
      }
      await _updateTrayStatus();
    } catch (e) {
      debugPrint('❌ Error handling clock in/out: $e');
    }
  }

  static Future<void> _showCurrentStatus() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entry = await _repository.getWorkEntry(today);
      
      final isClockedIn = entry != null && entry.clockIn != null && entry.clockOut == null;
      final duration = isClockedIn ? now.difference(entry!.clockIn!).inMinutes : 0;
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      
      final status = isClockedIn 
          ? 'Currently Clocked In\nDuration: ${hours}h ${minutes}m'
          : 'Currently Clocked Out';
      
      await _notifications.show(
        0,
        "Work Hours Status",
        status,
        NotificationDetails(
          windows: WindowsNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error showing current status: $e');
    }
  }

  static Future<void> _handleExit() async {
    try {
      await _systemTray.destroy();
      exit(0);
    } catch (e) {
      debugPrint('❌ Error handling exit: $e');
    }
  }

  static Future<void> dispose() async {
    if (!Platform.isWindows || !_isInitialized) return;
    
    try {
      await _systemTray.destroy();
      _isInitialized = false;
    } catch (e) {
      debugPrint('❌ Error disposing Windows tray service: $e');
    }
  }
} 