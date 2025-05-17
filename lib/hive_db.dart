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
        debugPrint('[EXCEL_IMPORT] Starting Excel import process...');

        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (result == null) {
          debugPrint('[EXCEL_IMPORT] ⚠️ No file selected.');
          return;
        }

        debugPrint('[EXCEL_IMPORT] Selected file: ${result.files.single.path}');
        final filePath = result.files.single.path!;
        final bytes = File(filePath).readAsBytesSync();
        debugPrint('[EXCEL_IMPORT] File read successfully, size: ${bytes.length} bytes');

        final excel = Excel.decodeBytes(bytes);
        debugPrint('[EXCEL_IMPORT] Excel file decoded successfully');

        final sheet = excel.tables['WorkHours'];
        if (sheet == null) {
          debugPrint('[EXCEL_IMPORT] ❌ No "WorkHours" sheet found. Available sheets: ${excel.tables.keys.join(', ')}');
          return;
        }

        debugPrint('[EXCEL_IMPORT] Found WorkHours sheet with ${sheet.rows.length} rows');

        // Print header row for verification
        if (sheet.rows.isNotEmpty) {
          debugPrint('[EXCEL_IMPORT] Header row: ${sheet.rows[0].map((cell) => cell?.value?.toString() ?? 'null').join(', ')}');
        }

        int importedCount = 0;
        int skippedCount = 0;

        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          debugPrint('[EXCEL_IMPORT] Processing row $i: ${row.map((cell) => cell?.value?.toString() ?? 'null').join(', ')}');

          final rawDate = row[0]?.value.toString();
          debugPrint('[EXCEL_IMPORT] Raw date value: $rawDate');

          String? dateKey;
          if (rawDate is DateTime) {
            dateKey = DateFormat('yyyy-MM-dd').format(rawDate as DateTime);
          } else if (rawDate is String) {
            final parsed = DateTime.tryParse(rawDate);
            if (parsed != null) {
              dateKey = DateFormat('yyyy-MM-dd').format(parsed);
            } else if (rawDate.length >= 10) {
              dateKey = rawDate.substring(0, 10);
            }
          }

          debugPrint('[EXCEL_IMPORT] Processed date key: $dateKey');

          final clockInStr = row[1]?.value?.toString();
          final clockOutStr = row[2]?.value?.toString();
          final offDayStr = (row[4]?.value?.toString() ?? '').toLowerCase();
          // Only try to access description if the row has enough columns
          final descriptionStr = row.length > 5 ? row[5]?.value?.toString() : null;

          debugPrint('[EXCEL_IMPORT] Row values - Clock In: $clockInStr, Clock Out: $clockOutStr, Off Day: $offDayStr, Description: $descriptionStr');

          bool isOffDay = offDayStr == 'yes' || offDayStr == 'true' || offDayStr == '1';
          String? description = isOffDay ? (descriptionStr ?? 'Annual Leave') : null;

          if (dateKey != null) {
            if (isOffDay) {
              debugPrint('[EXCEL_IMPORT] Importing off day for $dateKey with description: $description');
              await Hive.box('work_hours').put(dateKey, {
                'in': null,
                'out': null,
                'duration': getDailyTargetMinutes(),
                'offDay': true,
                'description': description,
              });
              importedCount++;
            } else {
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

              debugPrint('[EXCEL_IMPORT] Importing work day for $dateKey with duration: $durationMinutes minutes');
              await Hive.box('work_hours').put(dateKey, {
                'in': clockInStr,
                'out': clockOutStr,
                'duration': durationMinutes,
                'offDay': false,
              });
              importedCount++;
            }
          } else {
            debugPrint('[EXCEL_IMPORT] ⚠️ Skipping row $i: could not parse date.');
            skippedCount++;
          }
        }

        debugPrint('[EXCEL_IMPORT] ✅ Import completed. Imported: $importedCount, Skipped: $skippedCount');
      } catch (e, stackTrace) {
        debugPrint('[EXCEL_IMPORT] ❌ Error importing from Excel: $e');
        debugPrint('[EXCEL_IMPORT] Stack trace: $stackTrace');
      }
    }

    static Future<void> exportDataToExcel() async {
      try {
        final entries = getAllEntries();
        final excel = Excel.createExcel(); // Creates a new Excel file
        final sheet = excel['WorkHours']; // Sheet name

        // Add Header
        sheet.appendRow(
            ['Date', 'Clock In', 'Clock Out', 'Duration (minutes)', 'Off Day']);

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

    static Future<void> markOffDay(DateTime date, {String? description}) async {
      try {
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        await _workHoursBox.delete(dateKey); // First delete any old entry

        await _workHoursBox.put(dateKey, {
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
        final workDays = _settingsBox.get('workDays',
            defaultValue: List.generate(7, (index) => index != 4 && index != 5));
        debugPrint('🔍 [WORK_DAYS] Raw value from settings: $workDays');
        return workDays;
      } catch (e) {
        debugPrint('Error in getWorkDays: $e');
        return List.generate(7, (index) => index != 4 && index != 5);
      }
    }

    static Future<void> setWorkDays(List<bool> days) async {
      try {
        debugPrint('🔍 [WORK_DAYS] Setting new work days: $days');
        await _settingsBox.put('workDays', days);
        // Verify the save
        final saved = _settingsBox.get('workDays');
        debugPrint('🔍 [WORK_DAYS] Verified saved value: $saved');
      } catch (e) {
        debugPrint('Error in setWorkDays: $e');
        rethrow;
      }
    }

    static int getDailyTargetHours() {
      try {
        final hours = _settingsBox.get('dailyTargetHours', defaultValue: 8);
        debugPrint('🔍 [DAILY_TARGET] Getting daily target hours: $hours');
        return hours;
      } catch (e) {
        debugPrint('Error in getDailyTargetHours: $e');
        return 8;
      }
    }

    static Future<void> setDailyTargetHours(int hours) async {
      try {
        if (hours < 1 || hours > 24) return;
        debugPrint('🔍 [DAILY_TARGET] Setting daily target hours to: $hours');
        await _settingsBox.put('dailyTargetHours', hours);
        final saved = _settingsBox.get('dailyTargetHours');
        debugPrint('🔍 [DAILY_TARGET] Verified saved value: $saved');
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
        final minute =
            _settingsBox.get('clockOutReminderMinute', defaultValue: 0);
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
        print(DateTime.now());
        String clockInText = "In: --:--";
        String clockOutText = "Out: --:--";
        bool isClockedIn = false;
        DateTime?
            clockInTimeForClockOut; // Store clock-in time if needed for clock-out action

        if (todayEntry != null) {
          final inTimeStr = todayEntry['in'] as String?;
          final outTimeStr = todayEntry['out'] as String?;

          if (inTimeStr != null) {
            final inTime = DateTime.parse(inTimeStr);
            clockInText = "In: ${DateFormat.Hm().format(inTime)}";
            clockInTimeForClockOut =
                inTime; // Store for potential clock-out action
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

        // Calculate overtime using our new method
        final overtimeMinutes = getMonthlyOvertime();
        final overtimeText =
            "Overtime: ${_formatDurationForWidgetDb(overtimeMinutes)}";

        // Save text data for widget
        await HomeWidget.saveWidgetData<String>('_clockInText', clockInText);
        await HomeWidget.saveWidgetData<String>('_clockOutText', clockOutText);
        await HomeWidget.saveWidgetData<String>('_overtimeText', overtimeText);

        debugPrint("Saving widget data:");
        debugPrint("Clock In: $clockInText");
        debugPrint("Clock Out: $clockOutText");
        debugPrint("Overtime: $overtimeText");

        // Update the widget (this now implicitly handles click registration via the callback)
        await HomeWidget.updateWidget(
            name: 'MyHomeWidgetProvider',
            androidName: 'MyHomeWidgetProvider',
            iOSName: 'MyHomeWidgetProvider');

        debugPrint("HomeWidget data saved and update triggered.");
      } catch (e) {
        debugPrint('Error syncing today entry for widget: $e');
      }
    }

    // Public method to trigger widget update
    static Future<void> updateWidget() async {
      await _syncTodayEntry();
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
        int extraWorkDays = 0; // Days worked that weren't scheduled

        // Iterate through each day of the month up to today
        for (var day = firstOfMonth;
            day.isBefore(today.add(const Duration(days: 1)));
            day = day.add(const Duration(days: 1))) {
          final dateKey = DateFormat('yyyy-MM-dd').format(day);
          final entry = allEntries[dateKey];
          final weekdayIndex = day.weekday - 1; // Convert to 0-based index (0 = Monday)
          final bool isConfiguredWorkDay = workDaysSetting[weekdayIndex];

          // Add target minutes only for configured work days
          if (isConfiguredWorkDay) {
            targetMinutes += dailyTarget;
            debugPrint('\n📆 ${_getDayName(weekdayIndex)} $dateKey (Configured Work Day)');
          } else {
            debugPrint('\n📆 ${_getDayName(weekdayIndex)} $dateKey (Not a Work Day)');
          }

          if (entry != null) {
            final bool isOffDay = entry['offDay'] as bool? ?? false;
            final num? duration = entry['duration'] as num?;

            if (isOffDay) {
              // Always add daily target for off days, regardless of whether it's a configured work day
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
        debugPrint('🔄 Overtime    : $sign${hours.abs()}h ${minutes.abs()}m (${overtime.abs()} minutes)');
      } catch (e) {
        debugPrint('Error in calculateAndPrintMonthlyOvertime: $e');
      }
    }

    static String _getDayName(int index) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[index];
    }

    static int getMonthlyOvertime() {
      try {
        final now = DateTime.now();
        final firstOfMonth = DateTime(now.year, now.month, 1);
        final today = DateTime(now.year, now.month, now.day);
        
        return getMonthlyOvertimeForRange(firstOfMonth, today);
      } catch (e) {
        debugPrint('Error in getMonthlyOvertime: $e');
        return 0;
      }
    }
    
    static int getMonthlyOvertimeForRange(DateTime startDate, DateTime endDate) {
      try {
        final allEntries = getAllEntries();
        final workDaysSetting = getWorkDays();
        final dailyTarget = getDailyTargetMinutes();

        int targetMinutes = 0;
        int workedMinutes = 0;

        // Iterate through each day in the range
        for (var day = startDate;
            day.isBefore(endDate.add(const Duration(days: 1)));
            day = day.add(const Duration(days: 1))) {
          final dateKey = DateFormat('yyyy-MM-dd').format(day);
          final entry = allEntries[dateKey];
          final weekdayIndex = day.weekday - 1; // Convert to 0-based index (0 = Monday)
          final bool isConfiguredWorkDay = workDaysSetting[weekdayIndex];

          // Add target minutes only for configured work days
          if (isConfiguredWorkDay) {
            targetMinutes += dailyTarget;
          }

          if (entry != null) {
            final bool isOffDay = entry['offDay'] as bool? ?? false;
            final num? duration = entry['duration'] as num?;

            if (isOffDay) {
              workedMinutes += dailyTarget;
            } else if (duration != null) {
              workedMinutes += duration.toInt();
            }
          }
        }

        return workedMinutes - targetMinutes;
      } catch (e) {
        debugPrint('Error in getMonthlyOvertimeForRange: $e');
        return 0;
      }
    }

    static int getLastMonthOvertime() {
      try {
        final now = DateTime.now();
        final lastMonthStart = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0); // Last day of previous month
        
        return getMonthlyOvertimeForRange(lastMonthStart, lastMonthEnd);
      } catch (e) {
        debugPrint('Error in getLastMonthOvertime: $e');
        return 0;
      }
    }

    static int getExpectedWorkMinutesForRange(DateTime startDate, DateTime endDate) {
      try {
        final workDaysSetting = getWorkDays();
        final dailyTarget = getDailyTargetMinutes();
        int expectedMinutes = 0;
        
        // Iterate through each day in the range
        for (var day = startDate;
            day.isBefore(endDate.add(const Duration(days: 1)));
            day = day.add(const Duration(days: 1))) {
          final weekdayIndex = day.weekday - 1; // 0-based index (0 = Monday)
          final bool isConfiguredWorkDay = workDaysSetting[weekdayIndex];
          
          // Add target minutes for configured work days
          if (isConfiguredWorkDay) {
            expectedMinutes += dailyTarget;
          }
        }
        
        return expectedMinutes;
      } catch (e) {
        debugPrint('Error in getExpectedWorkMinutesForRange: $e');
        return 0;
      }
    }
    
    static int getCurrentMonthExpectedMinutes() {
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final today = DateTime(now.year, now.month, now.day);
      
      return getExpectedWorkMinutesForRange(firstOfMonth, today);
    }
    
    static int getLastMonthExpectedMinutes() {
      final now = DateTime.now();
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0); // Last day of previous month
      
      return getExpectedWorkMinutesForRange(lastMonthStart, lastMonthEnd);
    }
  }

