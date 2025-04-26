import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> checkAndRequestPermissions(BuildContext? context) async {
    bool allGranted = true;

    // Check notification permission
    if (await Permission.notification.status.isDenied) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
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

    // Check exact alarm permission
    if (await Permission.scheduleExactAlarm.status.isDenied) {
      final status = await Permission.scheduleExactAlarm.request();
      if (status.isDenied) {
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