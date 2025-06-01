import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:io' show Platform;
import '../data/local/hive_db.dart';

class WidgetService {
  static const String appWidgetProvider = 'MyHomeWidgetProvider';
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
      debugPrint('🔍 [WIDGET_DEBUG] Handling widget action: $action');
      
      switch (action) {
        case 'clock_in':
          if (!HiveDb.isClockedIn()) {
            debugPrint('🔍 [WIDGET_DEBUG] Clocking in...');
            await HiveDb.clockIn(DateTime.now());
            debugPrint('✅ [WIDGET_DEBUG] Clocked in successfully');
            
            // Update widget data
            await HomeWidget.saveWidgetData('isClockedIn', true);
            await HomeWidget.saveWidgetData('clockIn', DateTime.now().toString());
            await HomeWidget.saveWidgetData('clockOut', null);
            debugPrint('✅ [WIDGET_DEBUG] Widget data updated for clock in');
          } else {
            debugPrint('⚠️ [WIDGET_DEBUG] Already clocked in');
          }
          break;
          
        case 'clock_out':
          if (HiveDb.isClockedIn()) {
            debugPrint('🔍 [WIDGET_DEBUG] Clocking out...');
            await HiveDb.clockOut(DateTime.now());
            debugPrint('✅ [WIDGET_DEBUG] Clocked out successfully');
            
            // Update widget data
            await HomeWidget.saveWidgetData('isClockedIn', false);
            await HomeWidget.saveWidgetData('clockOut', DateTime.now().toString());
            debugPrint('✅ [WIDGET_DEBUG] Widget data updated for clock out');
          } else {
            debugPrint('⚠️ [WIDGET_DEBUG] Not clocked in');
          }
          break;
          
        case updateWidgetAction:
          debugPrint('🔍 [WIDGET_DEBUG] Updating widget...');
          await updateWidget();
          debugPrint('✅ [WIDGET_DEBUG] Widget updated');
          break;
          
        default:
          debugPrint('⚠️ [WIDGET_DEBUG] Unknown widget action: $action');
      }
      
      // Force widget update
      await HomeWidget.updateWidget(
        iOSName: appWidgetProvider,
        androidName: appWidgetProvider,
      );
      debugPrint('✅ [WIDGET_DEBUG] Widget update triggered');
      
    } catch (e) {
      debugPrint('❌ [WIDGET_DEBUG] Error handling widget action: $e');
      debugPrint('❌ [WIDGET_DEBUG] Error details: ${e.toString()}');
    }
  }
}
