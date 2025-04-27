import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // Add if missing
import 'dart:convert'; // Add this at the top if missing
import 'dart:io';
import 'package:excel/excel.dart'; // Add this import
import 'package:file_picker/file_picker.dart'; // If you plan to import from user file
import 'package:permission_handler/permission_handler.dart';

// Helper function (can be moved to a utility file if preferred)
String _formatDurationForWidgetDb(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final sign = totalMinutes >= 0 ? '+' : '-';
  return '$sign${hours.abs()}h ${minutes.abs()}m';
}

class HiveDb {
  static final Box _workHoursBox = Hive.box('work_hours');
  static final Box _settingsBox = Hive.box('settings');

  // Work Hours Operations
  static Future<void> clockIn(DateTime time) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(time);
      await _workHoursBox.put(dateKey, {
        'in': time.toIso8601String(),
        'out': null,
        'duration': null,
        'offDay': false,
      });
      await _syncTodayEntry();
    } catch (e) {
      debugPrint('Error in clockIn: $e');
      rethrow;
    }
  }
  static Future<void> importDataFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) {
        debugPrint('⚠️ No file selected.');
        return;
      }

      final filePath = result.files.single.path!;
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables['WorkHours'];
      if (sheet == null) {
        debugPrint('❌ No "WorkHours" sheet found.');
        return;
      }

      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final rawDate = row[0]?.value.toString();

        String? dateKey;
        if (rawDate is DateTime) {
          dateKey = DateFormat('yyyy-MM-dd').format(rawDate as DateTime);
        } else if (rawDate is String) {
          final parsed = DateTime.tryParse(rawDate);
          if (parsed != null) {
            dateKey = DateFormat('yyyy-MM-dd').format(parsed);
          } else if (rawDate.length >= 10) {
            dateKey = rawDate.substring(0, 10); // fallback if already formatted like yyyy-MM-dd
          }
        }

        final clockInStr = row[1]?.value?.toString();
        final clockOutStr = row[2]?.value?.toString();

        int durationMinutes = 0;
        if (clockInStr != null && clockOutStr != null) {
          final clockIn = DateTime.tryParse(clockInStr);
          final clockOut = DateTime.tryParse(clockOutStr);
          if (clockIn != null && clockOut != null) {
            durationMinutes = clockOut.difference(clockIn).inMinutes;
            if (durationMinutes < 0) durationMinutes = 0;
          }
        } else {
          durationMinutes = int.tryParse(row[3]?.value.toString() ?? '0') ?? 0;
        }

        if (dateKey != null) {
          await Hive.box('work_hours').put(dateKey, {
            'in': clockInStr,
            'out': clockOutStr,
            'duration': durationMinutes,
            'offDay': (row[4]?.value?.toString() ?? '').toLowerCase() == 'yes',
          });
        } else {
          debugPrint('⚠️ Skipping row $i: could not parse date.');
        }
      }

      debugPrint('✅ Imported work hours from Excel.');
    } catch (e) {
      debugPrint('❌ Error importing from Excel: $e');
    }
  }



  static Future<void> exportDataToExcel() async {
    try {
      final entries = getAllEntries();
      final excel = Excel.createExcel(); // Creates a new Excel file
      final sheet = excel['WorkHours']; // Sheet name

      // Add Header
      sheet.appendRow(['Date', 'Clock In', 'Clock Out', 'Duration (minutes)', 'Off Day']);

      // Add entries
      entries.forEach((date, entry) {
        sheet.appendRow([
          date,
          entry['in'] ?? '',
          entry['out'] ?? '',
          entry['duration'] ?? 0,
          entry['offDay'] == true ? 'Yes' : 'No',
        ]);
      });

      // Let user pick the folder
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        debugPrint('⚠️ User canceled directory selection.');
        return;
      }

      final path = '$selectedDirectory/work_hours_backup.xlsx';

      final fileBytes = excel.encode();
      final file = File(path);

      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        debugPrint('✅ Exported work hours to Excel: $path');
      } else {
        debugPrint('⚠️ Failed to generate Excel file.');
      }
    } catch (e) {
      debugPrint('❌ Error exporting to Excel: $e');
    }
  }







  static Future<void> clockOut(DateTime time, DateTime clockInTime) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(time);
      final workedDuration = time.difference(clockInTime).inMinutes;

      // Validate that clock out time is after clock in time
      if (workedDuration < 0) {
        throw Exception('Clock out time cannot be before clock in time');
      }

      final existing = _workHoursBox.get(dateKey);
      int previousDuration = 0;

      if (existing != null && existing['duration'] != null) {
        previousDuration = (existing['duration'] as num).toInt();
      }

      await _workHoursBox.put(dateKey, {
        'in': clockInTime.toIso8601String(),
        'out': time.toIso8601String(),
        'duration': previousDuration + workedDuration,
        'offDay': existing?['offDay'] ?? false,
      });
      await _syncTodayEntry();
    } catch (e) {
      debugPrint('Error in clockOut: $e');
      rethrow;
    }
  }

  static Future<void> markOffDay(DateTime date) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      await _workHoursBox.delete(dateKey); // First delete any old entry

      await _workHoursBox.put(dateKey, {
        'in': null,
        'out': null,
        'duration': getDailyTargetMinutes(),
        'offDay': true,
      });

      await _syncTodayEntry();
      debugPrint('✅ Marked $dateKey as Off Day.');
    } catch (e) {
      debugPrint('Error in markOffDay: $e');
      rethrow;
    }
  }


  static Map<String, dynamic>? getDayEntry(DateTime date) {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dynamic value = _workHoursBox.get(dateKey);
      if (value == null) return null;
      return Map<String, dynamic>.from(value as Map);
    } catch (e) {
      debugPrint('Error in getDayEntry: $e');
      return null;
    }
  }

  static Future<void> deleteEntry(String dateKey) async {
    try {
      await _workHoursBox.delete(dateKey);
    } catch (e) {
      debugPrint('Error in deleteEntry: $e');
      rethrow;
    }
  }

  static Future<void> deleteAllEntries() async {
    try {
      await _workHoursBox.clear();
    } catch (e) {
      debugPrint('Error in deleteAllEntries: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> getAllEntries() {
    try {
      final Map<dynamic, dynamic> rawMap = _workHoursBox.toMap();
      return Map<String, dynamic>.from(rawMap);
    } catch (e) {
      debugPrint('Error in getAllEntries: $e');
      return {};
    }
  }

  static Map<String, dynamic> getStatsForRange(DateTime start, DateTime end) {
    try {
      int totalMinutes = 0;
      int workDays = 0;
      int offDays = 0;
      final dailyTarget = getDailyTargetMinutes();

      for (var day = start;
          day.isBefore(end.add(const Duration(days: 1)));
          day = day.add(const Duration(days: 1))) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final entry = _workHoursBox.get(dateKey);

        if (entry != null) {
          if (entry['offDay'] == true) {
            totalMinutes += dailyTarget;
            offDays++;
          } else if (entry['duration'] != null) {
            totalMinutes += (entry['duration'] as num).toInt();
            workDays++;
          }
        }
      }

      return {
        'totalMinutes': totalMinutes,
        'workDays': workDays,
        'offDays': offDays,
      };
    } catch (e) {
      debugPrint('Error in getStatsForRange: $e');
      return {
        'totalMinutes': 0,
        'workDays': 0,
        'offDays': 0,
      };
    }
  }

  // Settings Operations
  static bool getIsDarkMode() {
    try {
      return _settingsBox.get('isDarkMode', defaultValue: false);
    } catch (e) {
      debugPrint('Error in getIsDarkMode: $e');
      return false;
    }
  }

  static Future<void> setIsDarkMode(bool value) async {
    try {
      await _settingsBox.put('isDarkMode', value);
    } catch (e) {
      debugPrint('Error in setIsDarkMode: $e');
      rethrow;
    }
  }

  static List<bool> getWorkDays() {
    try {
      return _settingsBox.get('workDays', defaultValue: List.generate(7, (index) => index < 5));
    } catch (e) {
      debugPrint('Error in getWorkDays: $e');
      return List.generate(7, (index) => index < 5);
    }
  }

  static Future<void> setWorkDays(List<bool> days) async {
    try {
      await _settingsBox.put('workDays', days);
    } catch (e) {
      debugPrint('Error in setWorkDays: $e');
      rethrow;
    }
  }

  static int getDailyTargetHours() {
    try {
      return _settingsBox.get('dailyTargetHours', defaultValue: 8);
    } catch (e) {
      debugPrint('Error in getDailyTargetHours: $e');
      return 8;
    }
  }

  static Future<void> setDailyTargetHours(int hours) async {
    try {
      if (hours < 1 || hours > 24) return;
      await _settingsBox.put('dailyTargetHours', hours);
    } catch (e) {
      debugPrint('Error in setDailyTargetHours: $e');
      rethrow;
    }
  }

  static TimeOfDay getClockInReminderTime() {
    try {
      final hour = _settingsBox.get('clockInReminderHour', defaultValue: 9);
      final minute = _settingsBox.get('clockInReminderMinute', defaultValue: 0);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      debugPrint('Error in getClockInReminderTime: $e');
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  static Future<void> setClockInReminderTime(TimeOfDay time) async {
    try {
      await _settingsBox.put('clockInReminderHour', time.hour);
      await _settingsBox.put('clockInReminderMinute', time.minute);
    } catch (e) {
      debugPrint('Error in setClockInReminderTime: $e');
      rethrow;
    }
  }

  static TimeOfDay getClockOutReminderTime() {
    try {
      final hour = _settingsBox.get('clockOutReminderHour', defaultValue: 17);
      final minute = _settingsBox.get('clockOutReminderMinute', defaultValue: 0);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      debugPrint('Error in getClockOutReminderTime: $e');
      return const TimeOfDay(hour: 17, minute: 0);
    }
  }

  static Future<void> setClockOutReminderTime(TimeOfDay time) async {
    try {
      await _settingsBox.put('clockOutReminderHour', time.hour);
      await _settingsBox.put('clockOutReminderMinute', time.minute);
    } catch (e) {
      debugPrint('Error in setClockOutReminderTime: $e');
      rethrow;
    }
  }

  static int getDailyTargetMinutes() {
    return getDailyTargetHours() * 60;
  }

  static int getWeeklyTargetMinutes() {
    try {
      final workDays = getWorkDays();
      final workDaysCount = workDays.where((day) => day).length;
      return workDaysCount * getDailyTargetMinutes();
    } catch (e) {
      debugPrint('Error in getWeeklyTargetMinutes: $e');
      return 40 * 60; // Default to 40 hours (5 days * 8 hours)
    }
  }

  static int getMonthlyTargetMinutes() {
    try {
      return getWeeklyTargetMinutes() * 4;
    } catch (e) {
      debugPrint('Error in getMonthlyTargetMinutes: $e');
      return 160 * 60; // Default to 160 hours (40 hours * 4 weeks)
    }
  }

  // Listeners
  static ValueListenable<Box> getWorkHoursListenable() {
    return _workHoursBox.listenable();
  }

  static ValueListenable<Box> getSettingsListenable() {
    return _settingsBox.listenable();
  }

  static Future<void> _syncTodayEntry() async {
    try {
      final now = DateTime.now();
      final todayEntry = getDayEntry(now);
      
      String clockInText = "In: --:--";
      String clockOutText = "Out: --:--";
      bool isClockedIn = false;
      DateTime? clockInTimeForClockOut; // Store clock-in time if needed for clock-out action
      
      if (todayEntry != null) {
        final inTimeStr = todayEntry['in'] as String?;
        final outTimeStr = todayEntry['out'] as String?;
        
        if (inTimeStr != null) {
          final inTime = DateTime.parse(inTimeStr);
          clockInText = "In: ${DateFormat.Hm().format(inTime)}";
          clockInTimeForClockOut = inTime; // Store for potential clock-out action
          isClockedIn = true;
        }
        if (outTimeStr != null) {
          final outTime = DateTime.parse(outTimeStr);
          clockOutText = "Out: ${DateFormat.Hm().format(outTime)}";
          isClockedIn = false; // Explicitly set to false if clocked out
        } else if (inTimeStr != null) {
           // If clocked in but not out
           clockOutText = "Out: Pending";
           isClockedIn = true;
        }
      }

      // Calculate overtime
      final overtimeMinutes = calculateOvertimeUntilYesterday();
      final overtimeText = "Overtime: ${_formatDurationForWidgetDb(overtimeMinutes)}";

      // Save text data for widget
      await HomeWidget.saveWidgetData<String>('_clockInText', clockInText);
      await HomeWidget.saveWidgetData<String>('_clockOutText', clockOutText);
      await HomeWidget.saveWidgetData<String>('_overtimeText', overtimeText);
      
      // Update the widget (this now implicitly handles click registration via the callback)
      await HomeWidget.updateWidget(
          name: 'HomeWidgetProvider', 
          androidName: 'HomeWidgetProvider',
          iOSName: 'HomeWidgetProvider' 
      );

      debugPrint("HomeWidget data saved and update triggered.");

    } catch (e) {
      debugPrint('Error syncing today entry for widget: $e');
    }
  }

  // Public method to trigger widget update
  static Future<void> updateWidget() async {
    await _syncTodayEntry();
  }

  // New method to calculate overtime/undertime up to yesterday
  static int calculateOvertimeUntilYesterday() {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final allEntries = getAllEntries(); // Get all entries {dateKey: entryMap}
      if (allEntries.isEmpty) return 0; // No entries yet

      // Find the earliest entry date
      DateTime firstDate = DateTime.now();
      for (var dateKey in allEntries.keys) {
        try {
          final entryDate = DateFormat('yyyy-MM-dd').parse(dateKey);
          if (entryDate.isBefore(firstDate)) {
            firstDate = entryDate;
          }
        } catch (e) {
          debugPrint('Skipping invalid date key: $dateKey');
        }
      }
      
      // Ensure firstDate is not after yesterday
      if (firstDate.isAfter(yesterday)) {
          return 0; // No entries before today
      }

      int totalWorkedMinutes = 0;
      int totalTargetMinutes = 0;
      final workDaysSetting = getWorkDays(); // [true, true, true, true, true, false, false]
      final dailyTarget = getDailyTargetMinutes();

      // Iterate from the first recorded day up to yesterday
      for (var day = firstDate; 
           day.isBefore(yesterday) || day.isAtSameMomentAs(yesterday); 
           day = day.add(const Duration(days: 1))) {
        
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final entry = allEntries[dateKey];
        
        // Check if it was a configured work day (adjusting for DateTime.weekday: Mon=1, Sun=7)
        int weekdayIndex = day.weekday - 1; // 0=Mon, 6=Sun
        bool isWorkDay = workDaysSetting[weekdayIndex];

        if (isWorkDay) {
            totalTargetMinutes += dailyTarget;
        }
        
        if (entry != null) {
          final duration = entry['duration'] as num?;
          final isOffDay = entry['offDay'] as bool? ?? false;

          if (isOffDay) {
            // If marked as off-day, count it as meeting the target for that day
            // Note: This assumes off-days count towards target, adjust if needed
             if (!isWorkDay) { 
                // If it wasn't a configured workday but marked as off, don't add worked time
             } else {
                 totalWorkedMinutes += dailyTarget; 
             }
          } else if (duration != null) {
            totalWorkedMinutes += duration.toInt();
          }
        } else {
           // If no entry exists for a configured work day, assume 0 worked minutes for that day
           // Target minutes are already added above if it's a workday
        }
      }

      return totalWorkedMinutes - totalTargetMinutes;
    } catch (e) {
      debugPrint('Error in calculateOvertimeUntilYesterday: $e');
      return 0; // Return 0 in case of error
    }
  }
}
