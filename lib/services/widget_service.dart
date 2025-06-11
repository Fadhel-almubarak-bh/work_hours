import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:io' show Platform;

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
}
