import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:io' show Platform;
import '../data/local/hive_db.dart';

class WidgetService {
  static const String appWidgetProvider = 'WorkHoursWidgetProvider';
  static const String clockInOutAction = 'clockInOut';
  static const String updateWidgetAction = 'updateWidget';

  static bool get isWidgetSupported => Platform.isAndroid || Platform.isIOS;

  static Future<void> initialize() async {
    if (!isWidgetSupported) {
      debugPrint('ℹ️ Widget service not supported on this platform');
      return;
    }

    try {
      await HomeWidget.setAppGroupId('group.com.workhours.widget');
      debugPrint('✅ Widget service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing widget service: $e');
    }
  }

  static Future<void> updateWidget() async {
    if (!isWidgetSupported) return;

    try {
      final isClockedIn = HiveDb.isClockedIn();
      final currentDuration = HiveDb.getCurrentDuration();
      final formattedDuration = _formatDuration(currentDuration);

      await HomeWidget.saveWidgetData('isClockedIn', isClockedIn);
      await HomeWidget.saveWidgetData('currentDuration', formattedDuration);
      await HomeWidget.updateWidget(
        iOSName: appWidgetProvider,
        androidName: appWidgetProvider,
      );
      debugPrint('✅ Widget updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating widget: $e');
    }
  }

  static String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    return '$hours:$minutes';
  }

  static Future<void> handleWidgetAction(String action) async {
    if (!isWidgetSupported) return;

    try {
      switch (action) {
        case clockInOutAction:
          if (HiveDb.isClockedIn()) {
            await HiveDb.clockOut(DateTime.now());
          } else {
            await HiveDb.clockIn(DateTime.now());
          }
          await updateWidget();
          break;
        case updateWidgetAction:
          await updateWidget();
          break;
        default:
          debugPrint('⚠️ Unknown widget action: $action');
      }
    } catch (e) {
      debugPrint('❌ Error handling widget action: $e');
    }
  }
}
