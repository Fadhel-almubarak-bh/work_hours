import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:io' show Platform;
import '../data/local/hive_db.dart';

class WidgetService {
  static const String appWidgetProvider = 'MyHomeWidgetProvider';
  static const String clockInOutAction = 'clockInOut';
  static const String updateWidgetAction = 'updateWidget';
  
  // Method channel for widget actions
  static const MethodChannel _widgetActionsChannel = MethodChannel('com.example.work_hours/actions');

  static bool get isWidgetSupported => Platform.isAndroid || Platform.isIOS;

  static Future<void> initialize() async {
    if (!isWidgetSupported) {
      debugPrint('[home_widget] Widget service not supported on this platform');
      return;
    }

    try {
      await HomeWidget.setAppGroupId('group.com.workhours.widget');
      
      // Set up method channel handler for widget actions
      debugPrint('[home_widget] 🔍 Setting up method channel handler for widget actions');
      _widgetActionsChannel.setMethodCallHandler(_handleWidgetAction);
      debugPrint('[home_widget] ✅ Method channel handler set up successfully');
      
      debugPrint('[home_widget] ✅ Widget service initialized successfully');
    } catch (e) {
      debugPrint('[home_widget] ❌ Error initializing widget service: $e');
    }
  }
  
  // Handle widget actions from Android
  static Future<dynamic> _handleWidgetAction(MethodCall call) async {
    debugPrint('[home_widget] 🔍 Widget action received: ${call.method}');
    debugPrint('[home_widget] 🔍 Method call arguments: ${call.arguments}');
    
    try {
      switch (call.method) {
        case 'clockInOut':
          debugPrint('[home_widget] 🔍 Processing clock in/out toggle action');
          await _handleClockInOut();
          debugPrint('[home_widget] ✅ Clock in/out toggle action completed successfully');
          break;
        case 'clockIn':
          debugPrint('[home_widget] 🔍 Processing clock in action');
          await _handleClockIn();
          debugPrint('[home_widget] ✅ Clock in action completed successfully');
          break;
        case 'clockOut':
          debugPrint('[home_widget] 🔍 Processing clock out action');
          await _handleClockOut();
          debugPrint('[home_widget] ✅ Clock out action completed successfully');
          break;
        default:
          debugPrint('[home_widget] ⚠️ Unknown widget action: ${call.method}');
          throw PlatformException(
            code: 'UNKNOWN_ACTION',
            message: 'Unknown widget action: ${call.method}',
          );
      }
    } catch (e, stackTrace) {
      debugPrint('[home_widget] ❌ Error handling widget action: $e');
      debugPrint('[home_widget] ❌ Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Handle clock in/out toggle
  static Future<void> _handleClockInOut() async {
    debugPrint('[home_widget] 🔍 _handleClockInOut called');
    try {
      final isClockedIn = HiveDb.isClockedIn();
      debugPrint('[home_widget] 🔍 Current status - isClockedIn: $isClockedIn');
      
      if (isClockedIn) {
        debugPrint('[home_widget] 🔍 Attempting to clock out');
        await HiveDb.clockOut(DateTime.now());
        debugPrint('[home_widget] ✅ Successfully clocked out via widget');
      } else {
        debugPrint('[home_widget] 🔍 Attempting to clock in');
        await HiveDb.clockIn(DateTime.now());
        debugPrint('[home_widget] ✅ Successfully clocked in via widget');
      }
      
      debugPrint('[home_widget] 🔍 Updating widget display');
      await _updateWidgetDisplay();
      debugPrint('[home_widget] ✅ _handleClockInOut completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[home_widget] ❌ Error in clock in/out toggle: $e');
      debugPrint('[home_widget] ❌ Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Handle clock in
  static Future<void> _handleClockIn() async {
    try {
      if (!HiveDb.isClockedIn()) {
        await HiveDb.clockIn(DateTime.now());
        debugPrint('[home_widget] ✅ Successfully clocked in via widget');
        await _updateWidgetDisplay();
      } else {
        debugPrint('[home_widget] ⚠️ Already clocked in, ignoring clock in action');
      }
    } catch (e) {
      debugPrint('[home_widget] ❌ Error in clock in: $e');
      rethrow;
    }
  }
  
  // Handle clock out
  static Future<void> _handleClockOut() async {
    try {
      if (HiveDb.isClockedIn()) {
        await HiveDb.clockOut(DateTime.now());
        debugPrint('[home_widget] ✅ Successfully clocked out via widget');
        await _updateWidgetDisplay();
      } else {
        debugPrint('[home_widget] ⚠️ Not clocked in, ignoring clock out action');
      }
    } catch (e) {
      debugPrint('[home_widget] ❌ Error in clock out: $e');
      rethrow;
    }
  }
  
  // Update widget display
  static Future<void> _updateWidgetDisplay() async {
    debugPrint('[home_widget] 🔍 _updateWidgetDisplay called');
    try {
      debugPrint('[home_widget] 🔍 Getting current status');
      
      // Get current status
      final isClockedIn = HiveDb.isClockedIn();
      final currentDuration = HiveDb.getCurrentDuration();
      
      // Format duration
      final hours = currentDuration.inHours;
      final minutes = currentDuration.inMinutes.remainder(60);
      final seconds = currentDuration.inSeconds.remainder(60);
      final durationText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      debugPrint('[home_widget] 🔍 Status - isClockedIn: $isClockedIn, duration: $durationText');
      
      // Update widget data
      debugPrint('[home_widget] 🔍 Saving widget data');
      await HomeWidget.saveWidgetData('_isClockedIn', isClockedIn);
      await HomeWidget.saveWidgetData('_durationText', durationText);
      await HomeWidget.saveWidgetData('_lastUpdate', DateTime.now().toIso8601String());
      
      // Update widget UI
      debugPrint('[home_widget] 🔍 Updating widget UI');
      await HomeWidget.updateWidget(
        androidName: 'MyHomeWidgetProvider',
        iOSName: 'MyHomeWidgetProvider',
      );
      
      debugPrint('[home_widget] ✅ Widget display updated successfully');
    } catch (e, stackTrace) {
      debugPrint('[home_widget] ❌ Error updating widget display: $e');
      debugPrint('[home_widget] ❌ Stack trace: $stackTrace');
    }
  }
  
  // Test method to verify widget functionality
  static Future<void> testWidgetFunctionality() async {
    try {
      debugPrint('[home_widget] 🧪 Testing widget functionality...');
      
      // Test HiveDb methods
      final isClockedIn = HiveDb.isClockedIn();
      final currentDuration = HiveDb.getCurrentDuration();
      
      debugPrint('[home_widget] 🧪 Current status - isClockedIn: $isClockedIn, duration: $currentDuration');
      
      // Test widget data saving
      await HomeWidget.saveWidgetData('_testData', 'test_value');
      final testData = await HomeWidget.getWidgetData<String>('_testData');
      debugPrint('[home_widget] 🧪 Widget data test - saved: test_value, retrieved: $testData');
      
      // Test widget update
      await HomeWidget.updateWidget(
        androidName: 'MyHomeWidgetProvider',
        iOSName: 'MyHomeWidgetProvider',
      );
      
      debugPrint('[home_widget] 🧪 ✅ Widget functionality test completed successfully');
    } catch (e) {
      debugPrint('[home_widget] 🧪 ❌ Widget functionality test failed: $e');
    }
  }
  
  // Test method to manually trigger clock in/out from Flutter app
  static Future<void> testClockInOut() async {
    try {
      debugPrint('[home_widget] 🧪 Manually testing clock in/out from Flutter app...');
      await _handleClockInOut();
      debugPrint('[home_widget] 🧪 ✅ Manual clock in/out test completed successfully');
    } catch (e) {
      debugPrint('[home_widget] 🧪 ❌ Manual clock in/out test failed: $e');
    }
  }
}
