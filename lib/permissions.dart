import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> checkAndRequestPermissions(BuildContext? context) async {
    bool allGranted = true;

    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        final manageStatus = await Permission.manageExternalStorage.request();
        if (!manageStatus.isGranted) {
          allGranted = false;
          if (context != null) {
            _showPermissionDialog(
              context,
              'Manage All Files Permission',
              'We need access to your files to export/import backups.',
            );
          }
        }
      }
    }

    // Request Notification permission
    if (await Permission.notification.status.isDenied) {
      final notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        allGranted = false;
        if (context != null) {
          _showPermissionDialog(
            context,
            'Notification Permission',
            'This app needs notification permission to send you reminders about your work hours.',
          );
        }
      }
    }

    // Request Exact Alarm permission
    if (await Permission.scheduleExactAlarm.status.isDenied) {
      final alarmStatus = await Permission.scheduleExactAlarm.request();
      if (!alarmStatus.isGranted) {
        allGranted = false;
        if (context != null) {
          _showPermissionDialog(
            context,
            'Exact Alarm Permission',
            'This app needs exact alarm permission to schedule accurate reminders.',
          );
        }
      }
    }

    return allGranted;
  }

  static void _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
