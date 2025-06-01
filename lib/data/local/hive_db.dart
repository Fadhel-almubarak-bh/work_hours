import 'dart:io';
import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // Add if missing
import 'dart:convert'; // Add this at the top if missing
import 'package:excel/excel.dart'; // Add this import
import 'package:file_picker/file_picker.dart'; // If you plan to import from user file
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../models/work_entry.dart'; // Add this import

// Helper function (can be moved to a utility file if preferred)
String _formatDurationForWidgetDb(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final sign = totalMinutes >= 0 ? '+' : '-';
  return '$sign${hours.abs()}h ${minutes.abs()}m';
}

class HiveDb {
  static Box? _workHoursBox;
  static Box? _settingsBox;

  static Box get _workHoursBoxInstance {
    if (_workHoursBox == null) {
      _workHoursBox = Hive.box('work_hours');
    }
    return _workHoursBox!;
  }

  static Box get _settingsBoxInstance {
    if (_settingsBox == null) {
      _settingsBox = Hive.box('settings');
    }
    return _settingsBox!;
  }

  static Future<void> initialize() async {
    _workHoursBox = await Hive.openBox('work_hours');
    _settingsBox = await Hive.openBox('settings');
  }

  // Work Hours Operations
  static Future<void> clockIn(DateTime time) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(time);
      
      // Check if there's any existing entry for this day
      final existing = _workHoursBoxInstance.get(dateKey);
      final String? description = existing?['description'] as String?;
      
      await _workHoursBoxInstance.put(dateKey, {
        'in': time.toIso8601String(),
        'out': null,
        'duration': null,
        'offDay': false,
        'description': description, // Preserve any existing description
      });
      await _syncTodayEntry();
    } catch (e) {
      debugPrint('Error in clockIn: $e');
      rethrow;
    }
  }

  static Map<String, dynamic>? getDayEntry(DateTime date) {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dynamic value = _workHoursBoxInstance.get(dateKey);
      if (value == null) return null;
      return Map<String, dynamic>.from(value as Map);
    } catch (e) {
      debugPrint('Error in getDayEntry: $e');
      return null;
    }
  }

  static int getDailyTargetMinutes() {
    final settings = getSettings();
    return (settings['dailyTargetHours'] as num?)?.toInt() ?? 8 * 60;
  }

  static int getWeeklyTargetMinutes() {
    final settings = getSettings();
    final dailyTarget = getDailyTargetMinutes();
    final workDaysPerWeek = (settings['workDaysPerWeek'] as num?)?.toInt() ?? 5;
    return dailyTarget * workDaysPerWeek;
  }

  static int getMonthlyTargetMinutes() {
    final settings = getSettings();
    final dailyTarget = getDailyTargetMinutes();
    final workDaysPerMonth = (settings['workDaysPerMonth'] as num?)?.toInt() ?? 22;
    return dailyTarget * workDaysPerMonth;
  }


  static int getCurrentMonthExpectedMinutes() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final settings = getSettings();
    final workDaysPerMonth = (settings['workDaysPerMonth'] as num?)?.toInt() ?? 22;
    final dailyTarget = getDailyTargetMinutes();
    return dailyTarget * workDaysPerMonth;
  }

  static int getLastMonthExpectedMinutes() {
    final now = DateTime.now();
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    final settings = getSettings();
    final workDaysPerMonth = (settings['workDaysPerMonth'] as num?)?.toInt() ?? 22;
    final dailyTarget = getDailyTargetMinutes();
    return dailyTarget * workDaysPerMonth;
  }

  static int getMonthlyOvertime() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final totalMinutes = getTotalMinutesForRange(monthStart, monthEnd);
    final expectedMinutes = getCurrentMonthExpectedMinutes();
    return totalMinutes - expectedMinutes;
  }

  static int getLastMonthOvertime() {
    final now = DateTime.now();
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    final totalMinutes = getTotalMinutesForRange(lastMonthStart, lastMonthEnd);
    final expectedMinutes = getLastMonthExpectedMinutes();
    return totalMinutes - expectedMinutes;
  }

  static int getTotalMinutesForRange(DateTime start, DateTime end) {
    final workHours = getWorkHours();
    int totalMinutes = 0;

    for (var i = 0; i <= end.difference(start).inDays; i++) {
      final date = start.add(Duration(days: i));
      final entry = getDayEntry(date);
      if (entry != null) {
        if (entry['offDay'] == true) {
          totalMinutes += getDailyTargetMinutes();
        } else if (entry['duration'] != null) {
          totalMinutes += (entry['duration'] as num).toInt();
        }
      }
    }

    return totalMinutes;
  }

  static Map<String, dynamic> getStatsForRange(DateTime start, DateTime end) {
    int totalMinutes = 0;
    int workDays = 0;
    int offDays = 0;

    for (var i = 0; i <= end.difference(start).inDays; i++) {
      final date = start.add(Duration(days: i));
      final entry = getDayEntry(date);
      if (entry != null) {
        if (entry['offDay'] == true) {
          offDays++;
          totalMinutes += getDailyTargetMinutes();
        } else if (entry['duration'] != null) {
          workDays++;
          totalMinutes += (entry['duration'] as num).toInt();
        }
      }
    }

    return {
      'totalMinutes': totalMinutes,
      'workDays': workDays,
      'offDays': offDays,
    };
  }

  static Map<String, Map<String, dynamic>> getAllEntries() {
    try {
      final entries = <String, Map<String, dynamic>>{};
      
      for (var key in _workHoursBoxInstance.keys) {
        final value = _workHoursBoxInstance.get(key);
        if (value != null) {
          entries[key.toString()] = Map<String, dynamic>.from(value);
        }
      }
      
      return entries;
    } catch (e) {
      debugPrint('Error getting all entries: $e');
      return {};
    }
  }

  static Future<void> importDataFromExcel(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.sheets.values.first;

        // Skip header row
        for (var row in sheet.rows.skip(1)) {
          if (row.length >= 5) {
            final dateStr = row[0]?.value?.toString() ?? '';
            final clockInStr = row[1]?.value?.toString() ?? '';
            final clockOutStr = row[2]?.value?.toString() ?? '';
            final hoursStr = row[3]?.value?.toString() ?? '0';
            final overtimeStr = row[4]?.value?.toString() ?? '0';

            if (dateStr.isNotEmpty && clockInStr.isNotEmpty) {
              try {
                final date = DateTime.parse(dateStr);
                final clockIn = DateTime.parse(clockInStr);
                final clockOut = clockOutStr.isNotEmpty ? DateTime.parse(clockOutStr) : null;
                final hours = double.parse(hoursStr);
                final overtime = double.parse(overtimeStr);

                await addWorkEntry(
                  date: date,
                  clockIn: clockIn,
                  clockOut: clockOut,
                  hours: hours,
                  overtime: overtime,
                );
              } catch (e) {
                debugPrint('Error parsing row: $e');
                continue;
              }
            }
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data imported successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error importing data: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing data: $e')),
        );
      }
    }
  }

  static Future<void> clockOut(DateTime time) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(time);
      final entry = _workHoursBoxInstance.get(dateKey);
      
      if (entry == null) {
        throw Exception('No clock-in record found for today');
      }
      
      final clockInTime = DateTime.parse(entry['in'] as String);
      final duration = time.difference(clockInTime).inMinutes;
      
      await _workHoursBoxInstance.put(dateKey, {
        ...entry,
        'out': time.toIso8601String(),
        'duration': duration,
      });
      await _syncTodayEntry();
    } catch (e) {
      debugPrint('Error in clockOut: $e');
      rethrow;
    }
  }

  static String _getDayName(int index) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[index];
  }


  static void calculateAndPrintMonthlyOvertime() {
    try {
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final today = DateTime(now.year, now.month, now.day);
      final allEntries = getAllEntries();
      final workDaysSetting = getWorkDays();
      final dailyTarget = getDailyTargetMinutes();

      debugPrint('\n🔍 [DETAILED OVERTIME CALCULATION]');
      debugPrint('📅 Period: ${DateFormat('yyyy-MM-dd').format(firstOfMonth)} to ${DateFormat('yyyy-MM-dd').format(today)}');
      debugPrint('⚙️ Settings:');
      debugPrint('   - Work days: ${workDaysSetting.asMap().entries.map((e) => '${_getDayName(e.key)}: ${e.value}').join(', ')}');
      debugPrint('   - Daily target: ${dailyTarget ~/ 60}h ${dailyTarget % 60}m ($dailyTarget minutes)');

      int targetMinutes = 0;
      int workedMinutes = 0;
      int offDaysCount = 0;
      int workDaysCount = 0;
      int missedWorkDays = 0;
      int extraWorkDays = 0;
      int nonWorkingDaysCount = 0; // Count of days that are not work days according to settings

      // Iterate through each day of the month up to today
      for (var day = firstOfMonth;
      day.isBefore(today.add(const Duration(days: 1)));
      day = day.add(const Duration(days: 1))) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final entry = allEntries[dateKey];
        final weekdayIndex = day.weekday - 1; // Convert to 0-based index (0 = Monday)
        final bool isConfiguredWorkDay = workDaysSetting[weekdayIndex];

        // Count non-working days from settings
        if (!isConfiguredWorkDay) {
          nonWorkingDaysCount++;
          targetMinutes += dailyTarget; // Add target minutes for non-working days
          debugPrint('\n📆 ${_getDayName(weekdayIndex)} $dateKey (Non-Working Day from Settings)');
        } else {
          targetMinutes += dailyTarget;
          debugPrint('\n📆 ${_getDayName(weekdayIndex)} $dateKey (Configured Work Day)');
        }

        if (entry != null) {
          final bool isOffDay = entry['offDay'] as bool? ?? false;
          final num? duration = entry['duration'] as num?;

          if (isOffDay) {
            workedMinutes += dailyTarget;
            offDaysCount++;
            debugPrint('   ✨ Off Day: +$dailyTarget minutes');
          } else if (duration != null) {
            workedMinutes += duration.toInt();

            if (isConfiguredWorkDay) {
              workDaysCount++;
              debugPrint('   💪 Worked: +${duration.toInt()} minutes');
            } else {
              extraWorkDays++;
              debugPrint('   🔍 Extra Work Day: +${duration.toInt()} minutes');
            }
          }
        } else if (isConfiguredWorkDay) {
          missedWorkDays++;
          debugPrint('   ❌ No entry (missed work day)');
        } else {
          debugPrint('   ❌ No entry (non-work day)');
        }
      }

      final overtime = workedMinutes - targetMinutes;
      final hours = overtime ~/ 60;
      final minutes = overtime % 60;
      final sign = overtime >= 0 ? '+' : '-';

      debugPrint('\n📊 [SUMMARY]');
      debugPrint('🎯 Target Time : $targetMinutes min (${targetMinutes ~/ 60}h ${targetMinutes % 60}m)');
      debugPrint('⏱️ Worked Time : $workedMinutes min (${workedMinutes ~/ 60}h ${workedMinutes % 60}m)');
      debugPrint('   - Regular work days: $workDaysCount');
      debugPrint('   - Off days counted: $offDaysCount');
      debugPrint('   - Extra work days: $extraWorkDays');
      debugPrint('   - Missed work days: $missedWorkDays');
      debugPrint('   - Non-working days from settings: $nonWorkingDaysCount');
      debugPrint('🔄 Overtime    : $sign${hours.abs()}h ${minutes.abs()}m (${overtime.abs()} minutes)');
    } catch (e) {
      debugPrint('Error in calculateAndPrintMonthlyOvertime: $e');
    }
  }

  static Future<void> setOffDay(DateTime date, bool isOffDay, {String? description}) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final entry = _workHoursBoxInstance.get(dateKey);
      
      if (entry == null) {
        await _workHoursBoxInstance.put(dateKey, {
          'in': null,
          'out': null,
          'duration': 0,
          'offDay': isOffDay,
          'description': description,
        });
      } else {
        await _workHoursBoxInstance.put(dateKey, {
          ...entry,
          'offDay': isOffDay,
          'description': description ?? entry['description'],
        });
      }
      await _syncTodayEntry();
    } catch (e) {
      debugPrint('Error in setOffDay: $e');
      rethrow;
    }
  }

  static Future<void> setDescription(DateTime date, String description) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final entry = _workHoursBoxInstance.get(dateKey);
      
      if (entry == null) {
        throw Exception('No entry found for the specified date');
      }
      
      await _workHoursBoxInstance.put(dateKey, {
        ...entry,
        'description': description,
      });
      await _syncTodayEntry();
    } catch (e) {
      debugPrint('Error in setDescription: $e');
      rethrow;
    }
  }

  static Future<void> deleteEntry(DateTime date) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final box = await Hive.openBox('work_hours');
    await box.delete(dateKey);
  }

  static Map<String, dynamic>? getEntry(DateTime date) {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final entry = _workHoursBoxInstance.get(dateKey);
      if (entry == null) return null;
      
      // Ensure the entry is properly typed
      if (entry is Map) {
        return Map<String, dynamic>.from(entry);
      }
      return null;
    } catch (e) {
      debugPrint('Error in getEntry: $e');
      return null;
    }
  }

  static List<Map<String, dynamic>> getEntriesForMonth(DateTime month) {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);
      
      final entries = <Map<String, dynamic>>[];
      for (var date = startDate; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final entry = _workHoursBoxInstance.get(dateKey);
        if (entry != null) {
          entries.add({
            'date': dateKey,
            ...entry,
          });
        }
      }
      return entries;
    } catch (e) {
      debugPrint('Error in getEntriesForMonth: $e');
      return [];
    }
  }

  // Settings Operations
  static Future<void> setDailyTargetHours(int hours) async {
    try {
      await _settingsBoxInstance.put('dailyTargetHours', hours);
    } catch (e) {
      debugPrint('Error in setDailyTargetHours: $e');
      rethrow;
    }
  }

  static int getDailyTargetHours() {
    try {
      return _settingsBoxInstance.get('dailyTargetHours', defaultValue: 8);
    } catch (e) {
      debugPrint('Error in getDailyTargetHours: $e');
      return 8;
    }
  }

  static Future<void> setMonthlySalary(double salary) async {
    try {
      await _settingsBoxInstance.put('monthlySalary', salary);
    } catch (e) {
      debugPrint('Error in setMonthlySalary: $e');
      rethrow;
    }
  }

  static double getMonthlySalary() {
    try {
      return _settingsBoxInstance.get('monthlySalary', defaultValue: 0.0);
    } catch (e) {
      debugPrint('Error in getMonthlySalary: $e');
      return 0.0;
    }
  }

  static Future<void> setWorkDays(List<bool> workDays) async {
    try {
      await _settingsBoxInstance.put('workDays', workDays);
    } catch (e) {
      debugPrint('Error in setWorkDays: $e');
      rethrow;
    }
  }

  static List<bool> getWorkDays() {
    try {
      return List<bool>.from(_settingsBoxInstance.get('workDays', defaultValue: [true, true, true, true, true, false, false]));
    } catch (e) {
      debugPrint('Error in getWorkDays: $e');
      return [true, true, true, true, true, false, false];
    }
  }

  // Clock In/Out Reminder Settings
  static Future<void> setClockInReminderTime(TimeOfDay time) async {
    try {
      await _settingsBoxInstance.put('clockInReminderTime', {
        'hour': time.hour,
        'minute': time.minute,
      });
    } catch (e) {
      debugPrint('Error in setClockInReminderTime: $e');
      rethrow;
    }
  }

  static TimeOfDay getClockInReminderTime() {
    try {
      final data = _settingsBoxInstance.get('clockInReminderTime');
      if (data != null) {
        return TimeOfDay(
          hour: data['hour'] as int,
          minute: data['minute'] as int,
        );
      }
      return const TimeOfDay(hour: 9, minute: 0); // Default to 9:00 AM
    } catch (e) {
      debugPrint('Error in getClockInReminderTime: $e');
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  static Future<void> setClockOutReminderTime(TimeOfDay time) async {
    try {
      await _settingsBoxInstance.put('clockOutReminderTime', {
        'hour': time.hour,
        'minute': time.minute,
      });
    } catch (e) {
      debugPrint('Error in setClockOutReminderTime: $e');
      rethrow;
    }
  }

  static TimeOfDay getClockOutReminderTime() {
    try {
      final data = _settingsBoxInstance.get('clockOutReminderTime');
      if (data != null) {
        return TimeOfDay(
          hour: data['hour'] as int,
          minute: data['minute'] as int,
        );
      }
      return const TimeOfDay(hour: 17, minute: 0); // Default to 5:00 PM
    } catch (e) {
      debugPrint('Error in getClockOutReminderTime: $e');
      return const TimeOfDay(hour: 17, minute: 0);
    }
  }

  static Future<void> setClockInReminderEnabled(bool enabled) async {
    try {
      await _settingsBoxInstance.put('clockInReminderEnabled', enabled);
    } catch (e) {
      debugPrint('Error in setClockInReminderEnabled: $e');
      rethrow;
    }
  }

  static bool getClockInReminderEnabled() {
    try {
      return _settingsBoxInstance.get('clockInReminderEnabled', defaultValue: true);
    } catch (e) {
      debugPrint('Error in getClockInReminderEnabled: $e');
      return true;
    }
  }

  static Future<void> setClockOutReminderEnabled(bool enabled) async {
    try {
      await _settingsBoxInstance.put('clockOutReminderEnabled', enabled);
    } catch (e) {
      debugPrint('Error in setClockOutReminderEnabled: $e');
      rethrow;
    }
  }

  static bool getClockOutReminderEnabled() {
    try {
      return _settingsBoxInstance.get('clockOutReminderEnabled', defaultValue: true);
    } catch (e) {
      debugPrint('Error in getClockOutReminderEnabled: $e');
      return true;
    }
  }

  // Clock In/Out Status
  static bool isClockedIn() {
    try {
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);
      final entry = _workHoursBoxInstance.get(dateKey);
      
      if (entry == null) return false;
      
      final clockIn = entry['in'] != null;
      final clockOut = entry['out'] != null;
      
      return clockIn && !clockOut;
    } catch (e) {
      debugPrint('Error in isClockedIn: $e');
      return false;
    }
  }

  static Duration getCurrentDuration() {
    try {
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);
      final entry = _workHoursBoxInstance.get(dateKey);
      
      if (entry == null) return Duration.zero;
      
      final clockIn = entry['in'] != null ? DateTime.parse(entry['in'] as String) : null;
      final clockOut = entry['out'] != null ? DateTime.parse(entry['out'] as String) : null;
      
      if (clockIn == null) return Duration.zero;
      
      if (clockOut != null) {
        // If clocked out, return the stored duration
        final duration = entry['duration'] as int?;
        return Duration(minutes: duration ?? 0);
      } else {
        // If still clocked in, calculate current duration
        return DateTime.now().difference(clockIn);
      }
    } catch (e) {
      debugPrint('Error in getCurrentDuration: $e');
      return Duration.zero;
    }
  }

  // Helper function to get day index
  static int _getDayIndex(String dayName) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days.indexWhere((day) => day.toLowerCase() == dayName.toLowerCase());
  }

  // Widget Sync
  static Future<void> _syncTodayEntry() async {
    try {
      // Only sync with widget on supported platforms
      if (!Platform.isAndroid && !Platform.isIOS) {
        return;
      }

      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);
      final entry = _workHoursBoxInstance.get(dateKey);
      
      if (entry != null) {
        final clockIn = entry['in'] != null ? DateTime.parse(entry['in'] as String) : null;
        final clockOut = entry['out'] != null ? DateTime.parse(entry['out'] as String) : null;
        final duration = entry['duration'] as int?;
        final offDay = entry['offDay'] as bool? ?? false;
        
        await HomeWidget.saveWidgetData('clockIn', clockIn?.toIso8601String());
        await HomeWidget.saveWidgetData('clockOut', clockOut?.toIso8601String());
        await HomeWidget.saveWidgetData('duration', duration != null ? _formatDurationForWidgetDb(duration) : null);
        await HomeWidget.saveWidgetData('offDay', offDay);
      } else {
        await HomeWidget.saveWidgetData('clockIn', null);
        await HomeWidget.saveWidgetData('clockOut', null);
        await HomeWidget.saveWidgetData('duration', null);
        await HomeWidget.saveWidgetData('offDay', false);
      }
      
      await HomeWidget.updateWidget(
        androidName: 'WorkHoursWidget',
        iOSName: 'WorkHoursWidget',
      );
    } catch (e) {
      debugPrint('Error in _syncTodayEntry: $e');
    }
  }

  static Future<void> markOffDay(DateTime date, {String? description}) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      await _workHoursBoxInstance.delete(dateKey); // First delete any old entry

      await _workHoursBoxInstance.put(dateKey, {
        'in': null,
        'out': null,
        'duration': getDailyTargetMinutes(),
        'offDay': true,
        'description': description,
      });

      await _syncTodayEntry();
      debugPrint('✅ Marked $dateKey as Off Day with description: $description');
    } catch (e) {
      debugPrint('Error in markOffDay: $e');
      rethrow;
    }
  }

  static Future<void> deleteAllEntries() async {
    final box = await Hive.openBox('work_hours');
    await box.clear();
  }

  static List<Map<String, dynamic>> getEntriesForRange(DateTime startDate, DateTime endDate) {
    final box = Hive.box('work_hours');
    final entries = <Map<String, dynamic>>[];
    
    for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final data = box.get(dateKey);
      if (data != null) {
        entries.add({
          'date': dateKey,
          ...data,
        });
      }
    }
    
    return entries;
  }

  static Future<void> saveWorkEntry(WorkEntry entry) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(entry.date);
    final box = await Hive.openBox('work_hours');
    
    final data = {
      'in': entry.clockIn?.toIso8601String(),
      'out': entry.clockOut?.toIso8601String(),
      'duration': entry.duration,
      'offDay': entry.isOffDay,
      'description': entry.description,
    };
    
    await box.put(dateKey, data);
  }

  static ValueListenable<Box> getWorkHoursListenable() {
    return _workHoursBoxInstance.listenable();
  }
  static ValueListenable<Box> getSettingsListenable() {
    return _settingsBoxInstance.listenable();
  }

  static Future<String> exportDataToExcel(BuildContext context) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        fileName: 'work_hours_export.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) {
        throw Exception('No file path selected');
      }

      final excel = Excel.createExcel();
      final sheet = excel.sheets.values.first;

      // Add headers
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Clock In'),
        TextCellValue('Clock Out'),
        TextCellValue('Hours'),
        TextCellValue('Overtime'),
      ]);

      // Get work entries
      final entries = getAllWorkEntries();
      final settings = getSettings();
      final dailyTargetHours = settings['dailyTargetHours'] as int? ?? 8;
      
      for (final entry in entries) {
        final totalHours = (entry['duration'] as int) / 60.0;
        final overtime = totalHours > dailyTargetHours ? totalHours - dailyTargetHours : 0.0;
        final regularHours = totalHours - overtime;

        sheet.appendRow([
          TextCellValue(entry['date'].toString()),
          TextCellValue(entry['clockIn']?.toString() ?? ''),
          TextCellValue(entry['clockOut']?.toString() ?? ''),
          TextCellValue(regularHours.toStringAsFixed(2)),
          TextCellValue(overtime.toStringAsFixed(2)),
        ]);
      }

      // Save the file
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      final file = File(result);
      await file.writeAsBytes(bytes);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully')),
        );
      }

      return result;
    } catch (e) {
      debugPrint('Error exporting data: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
      rethrow;
    }
  }

  static Map<String, dynamic> getSettings() {
    try {
      final settings = _settingsBoxInstance.toMap();
      return Map<String, dynamic>.from(settings);
    } catch (e) {
      debugPrint('Error in getSettings: $e');
      return {};
    }
  }

  static Map<String, dynamic> getWorkHours() {
    try {
      final workHours = _workHoursBoxInstance.toMap();
      return Map<String, dynamic>.from(workHours);
    } catch (e) {
      debugPrint('Error in getWorkHours: $e');
      return {};
    }
  }
  //debugging the hive
  static void printAllWorkHourEntries() {
    try {
      final entries = getAllEntries();
      if (entries.isEmpty) {
        debugPrint('[WORK_HOURS] ❗ No entries found in Hive DB.');
        return;
      }

      debugPrint('[WORK_HOURS] 🔍 Printing all entries in Hive DB:');
      entries.forEach((key, value) {
        debugPrint('📅 $key => ${jsonEncode(value)}');
      });
    } catch (e, stackTrace) {
      debugPrint('[WORK_HOURS] ❌ Error printing Hive DB entries: $e');
      debugPrint(stackTrace.toString());
    }
  }

  static Future<void> addWorkEntry({
    required DateTime date,
    required DateTime clockIn,
    DateTime? clockOut,
    required double hours,
    required double overtime,
  }) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final totalMinutes = ((hours + overtime) * 60).round();
      
      await _workHoursBoxInstance.put(dateKey, {
        'in': clockIn.toIso8601String(),
        'out': clockOut?.toIso8601String(),
        'duration': totalMinutes,
        'offDay': false,
        'description': null,
      });
      await _syncTodayEntry();
    } catch (e) {
      debugPrint('Error in addWorkEntry: $e');
      rethrow;
    }
  }

  static List<Map<String, dynamic>> getAllWorkEntries() {
    try {
      final entries = <Map<String, dynamic>>[];
      final allEntries = _workHoursBoxInstance.toMap();
      
      for (var entry in allEntries.entries) {
        final date = DateTime.parse(entry.key);
        final value = entry.value as Map<String, dynamic>;
        
        entries.add({
          'date': date,
          'clockIn': value['in'] != null ? DateTime.parse(value['in']) : null,
          'clockOut': value['out'] != null ? DateTime.parse(value['out']) : null,
          'duration': value['duration'] as int? ?? 0,
          'offDay': value['offDay'] as bool? ?? false,
          'description': value['description'] as String?,
        });
      }
      
      return entries;
    } catch (e) {
      debugPrint('Error in getAllWorkEntries: $e');
      return [];
    }
  }

}
