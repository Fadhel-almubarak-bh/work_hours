import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../data/local/hive_db.dart';

class WidgetService {
  static const String appWidgetProvider = 'WorkHoursWidgetProvider';
  static const String clockInOutAction = 'clockInOut';
  static const String updateWidgetAction = 'updateWidget';

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.com.workhours.widget');
      debugPrint('✅ Widget service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing widget service: $e');
    }
  }

  static Future<void> updateWidget() async {
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
  }
}
