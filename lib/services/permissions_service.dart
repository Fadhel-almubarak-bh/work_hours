import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Cache the Android version to avoid repeated checks
  static int? _androidSdkVersion;
  
  // Flag to ensure we don't show multiple dialogs simultaneously
  static bool _isShowingDialog = false;

  static Future<bool> checkAndRequestPermissions(BuildContext? context) async {
    bool allGranted = true;
    
    debugPrint('🔍 Starting permission check...');

    if (Platform.isAndroid) {
      debugPrint('🔍 Checking Android storage permissions...');
      
      // Get Android version
      final sdkVersion = await _getAndroidSdkVersion();
      debugPrint('📱 Android SDK version: $sdkVersion');
      
      // Handle storage permissions based on Android version
      if (sdkVersion >= 33) { // Android 13+
        debugPrint('📱 Using Android 13+ (API 33+) permission model');
        
        // For Android 13+, we need to use the new READ_MEDIA permissions
        final photosStatus = await Permission.photos.status;
        debugPrint('📊 Current photos permission status: $photosStatus');
        
        if (!photosStatus.isGranted) {
          debugPrint('🔄 Requesting photos permission...');
          final requestStatus = await Permission.photos.request();
          
          if (!requestStatus.isGranted) {
            allGranted = false;
            debugPrint('❌ Photos permission denied');
            if (context != null && context.mounted && !_isShowingDialog) {
              await _showPermissionDialog(
                context,
                'Storage Permission Required',
                'This app needs permission to access photos for Excel export/import. Please open settings and grant the permission.',
                false,
              );
            }
          }
        }
        
        // Also need documents access for Excel files
        final documentsStatus = await Permission.videos.status; // Used as proxy
        if (!documentsStatus.isGranted) {
          final requestStatus = await Permission.videos.request();
          if (!requestStatus.isGranted) {
            debugPrint('⚠️ Documents permission not available');
            // Not critical, so we can continue
          }
        }
      } else if (sdkVersion >= 30) { // Android 11-12
        debugPrint('📱 Using Android 11-12 (API 30-32) permission model');
        
        // For Android 11/12, we'll use the limited storage access
        final storageStatus = await Permission.storage.status;
        debugPrint('📊 Current storage permission status: $storageStatus');
        
        if (!storageStatus.isGranted) {
          debugPrint('🔄 Requesting basic storage permission...');
          final requestStatus = await Permission.storage.request();
          
          if (!requestStatus.isGranted) {
            allGranted = false;
            debugPrint('⚠️ Basic storage permission denied, but app may still work with system file picker');
            
            // Show a dialog that explains the user might need to select storage location manually
            if (context != null && context.mounted && !_isShowingDialog) {
              await _showPermissionDialog(
                context,
                'Storage Access Limited',
                'On newer Android versions, you\'ll need to manually select files and folders when importing or exporting. This is due to Android\'s security model.',
                false,
              );
            }
          }
        }
      } else { // Android 10 and below
        debugPrint('📱 Using pre-Android 11 permission model');
        
        // For Android 10 and below, we need READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE
        final storageStatus = await Permission.storage.status;
        debugPrint('📊 Current storage permission status: $storageStatus');
        
        if (!storageStatus.isGranted) {
          debugPrint('🔄 Requesting storage permission...');
          
          if (storageStatus.isPermanentlyDenied) {
            debugPrint('⚠️ Permission permanently denied, showing settings dialog');
            if (context != null && context.mounted && !_isShowingDialog) {
              await _showPermissionDialog(
                context,
                'Storage Permission Required',
                'This app needs storage permission to import and export Excel files. Please open settings and grant the permission.',
                true,
              );
            }
            allGranted = false;
          } else {
            final requestStatus = await Permission.storage.request();
            debugPrint('📊 Storage permission request result: $requestStatus');
            
            if (!requestStatus.isGranted) {
              allGranted = false;
              debugPrint('❌ Storage permission denied');
              
              if (context != null && context.mounted && !_isShowingDialog) {
                await _showPermissionDialog(
                  context,
                  'Storage Permission Required',
                  'This app needs storage permission to import and export Excel files.',
                  true,
                );
              }
            } else {
              debugPrint('✅ Storage permission granted');
            }
          }
        } else {
          debugPrint('✅ Storage permission already granted');
        }
      }
    }

    // Request Notification permission
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      debugPrint('📊 Notification permission not granted, requesting...');
      final requestedStatus = await Permission.notification.request();
      if (!requestedStatus.isGranted) {
        allGranted = false;
        debugPrint('❌ Notification permission denied');
        if (context != null && context.mounted && !_isShowingDialog) {
          await _showPermissionDialog(
            context,
            'Notification Permission',
            'This app needs notification permission to send you reminders about your work hours.',
            false,
          );
        }
      }
    }

    // Request Exact Alarm permission
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (!alarmStatus.isGranted) {
      debugPrint('📊 Exact alarm permission not granted, requesting...');
      final requestedStatus = await Permission.scheduleExactAlarm.request();
      if (!requestedStatus.isGranted) {
        allGranted = false;
        debugPrint('❌ Exact alarm permission denied');
        if (context != null && context.mounted && !_isShowingDialog) {
          await _showPermissionDialog(
            context,
            'Exact Alarm Permission',
            'This app needs exact alarm permission to schedule accurate reminders.',
            false,
          );
        }
      }
    }

    return allGranted;
  }

  static Future<void> _showPermissionDialog(
    BuildContext context,
    String title,
    String content,
    bool urgent,
  ) async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;
    
    try {
      await showDialog(
        context: context,
        barrierDismissible: !urgent,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(content),
              if (urgent)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: const Text(
                    'This permission is required for the app to function correctly.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
            ],
          ),
          actions: [
            if (!urgent)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Later'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } finally {
      _isShowingDialog = false;
    }
  }
  
  // Get Android SDK version with caching
  static Future<int> _getAndroidSdkVersion() async {
    if (_androidSdkVersion != null) {
      return _androidSdkVersion!;
    }
    
    if (!Platform.isAndroid) {
      return 0;
    }
    
    try {
      const platform = MethodChannel('work_hours/system_info');
      final sdkInt = await platform.invokeMethod<int>('getAndroidSdkVersion');
      _androidSdkVersion = sdkInt ?? 30; // Default to Android 11 if null
      return _androidSdkVersion!;
    } catch (e) {
      debugPrint('Error detecting Android SDK version: $e');
      // Fallback to a reasonable default
      _androidSdkVersion = 30; // Android 11
      return _androidSdkVersion!;
    }
  }
}
