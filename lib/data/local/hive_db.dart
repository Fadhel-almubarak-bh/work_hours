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

  static Future<void> importDataFromExcel() async {
    try {
      debugPrint('[EXCEL_IMPORT] Starting Excel import process...');

      // Use a more direct file picker with clearer permission requirements
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        dialogTitle: 'Select Excel File to Import',
      );

      if (result == null) {
        debugPrint('[EXCEL_IMPORT] ⚠️ No file selected.');
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        debugPrint('[EXCEL_IMPORT] ⚠️ File path is null.');
        return;
      }
      
      debugPrint('[EXCEL_IMPORT] Selected file: $filePath');
      
      // Verify the file exists
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[EXCEL_IMPORT] ❌ File does not exist: $filePath');
        throw Exception('File does not exist: $filePath');
      }
      
      // Read file bytes using try-catch to handle potential permission issues
      Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          debugPrint('[EXCEL_IMPORT] ❌ File is empty: $filePath');
          throw Exception('File is empty');
        }
      } catch (e) {
        debugPrint('[EXCEL_IMPORT] ❌ Error reading file: $e');
        throw Exception('Cannot read file. Please check app permissions or try selecting a different file location.');
      }
      
      debugPrint('[EXCEL_IMPORT] File read successfully, size: ${bytes.length} bytes');

      final excel = Excel.decodeBytes(bytes);
      debugPrint('[EXCEL_IMPORT] Excel file decoded successfully');

      // First, process settings sheet if it exists
      final settingsSheet = excel.tables['Settings'];
      if (settingsSheet != null) {
        debugPrint('[EXCEL_IMPORT] Found Settings sheet with ${settingsSheet.rows.length} rows');
        
        // Track settings import status
        Map<String, bool> settingsImportStatus = {
          'DailyTargetHours': false,
          'MonthlySalary': false,
          'WorkDays': false
        };
        
        try {
          for (var i = 1; i < settingsSheet.rows.length; i++) {
            final row = settingsSheet.rows[i];
            if (row.isEmpty || row.length < 2) continue;
            
            final settingName = row[0]?.value?.toString();
            final settingValue = row[1]?.value?.toString();
            
            if (settingName == null || settingValue == null) continue;
            
            try {
              if (settingName == 'DailyTargetHours') {
                final hours = int.tryParse(settingValue);
                if (hours != null && hours > 0 && hours <= 24) {
                  await setDailyTargetHours(hours);
                  settingsImportStatus['DailyTargetHours'] = true;
                  debugPrint('[EXCEL_IMPORT] ✅ Successfully imported DailyTargetHours: $hours');
                } else {
                  debugPrint('[EXCEL_IMPORT] ⚠️ Invalid DailyTargetHours value: $settingValue');
                }
              } else if (settingName == 'MonthlySalary') {
                final salary = double.tryParse(settingValue);
                if (salary != null && salary >= 0) {
                  await setMonthlySalary(salary);
                  settingsImportStatus['MonthlySalary'] = true;
                  debugPrint('[EXCEL_IMPORT] ✅ Successfully imported MonthlySalary: $salary');
                } else {
                  debugPrint('[EXCEL_IMPORT] ⚠️ Invalid MonthlySalary value: $settingValue');
                }
              } else if (settingName.startsWith('WorkDay_')) {
                final dayName = settingName.substring(8); // Remove 'WorkDay_' prefix
                final isWorkDay = settingValue.toLowerCase() == 'true';
                final workDays = getWorkDays();
                final dayIndex = _getDayIndex(dayName);
                if (dayIndex != -1) {
                  workDays[dayIndex] = isWorkDay;
                  await setWorkDays(workDays);
                  settingsImportStatus['WorkDays'] = true;
                  debugPrint('[EXCEL_IMPORT] ✅ Successfully imported WorkDay_$dayName: $isWorkDay');
                } else {
                  debugPrint('[EXCEL_IMPORT] ⚠️ Invalid day name in WorkDay setting: $dayName');
                }
              }
            } catch (e) {
              debugPrint('[EXCEL_IMPORT] ❌ Error importing setting $settingName: $e');
            }
          }
          
          // Log settings import summary
          debugPrint('[EXCEL_IMPORT] Settings import summary:');
          settingsImportStatus.forEach((setting, success) {
            debugPrint('$setting: ${success ? "✅" : "❌"}');
          });
          
        } catch (e) {
          debugPrint('[EXCEL_IMPORT] ❌ Error processing settings sheet: $e');
          throw Exception('Error importing settings: $e');
        }
      } else {
        debugPrint('[EXCEL_IMPORT] ⚠️ No Settings sheet found in the Excel file');
      }

      // Then process work hours sheet
      final sheet = excel.tables['WorkHours'];
      if (sheet == null) {
        debugPrint('[EXCEL_IMPORT] ❌ No "WorkHours" sheet found. Available sheets: ${excel.tables.keys.join(', ')}');
        throw Exception('No "WorkHours" sheet found in the Excel file. Available sheets: ${excel.tables.keys.join(', ')}');
      }

      debugPrint('[EXCEL_IMPORT] Found WorkHours sheet with ${sheet.rows.length} rows');

      // Print header row for verification
      if (sheet.rows.isNotEmpty) {
        debugPrint('[EXCEL_IMPORT] Header row: ${sheet.rows[0].map((cell) => cell?.value?.toString() ?? 'null').join(', ')}');
      } else {
        debugPrint('[EXCEL_IMPORT] ⚠️ Excel file has no rows');
        throw Exception('Excel file has no data rows');
      }

      int importedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;

      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        debugPrint('[EXCEL_IMPORT] Processing row $i: ${row.map((cell) => cell?.value?.toString() ?? 'null').join(', ')}');

        // Skip empty rows
        if (row.isEmpty || row.every((cell) => cell?.value == null)) {
          debugPrint('[EXCEL_IMPORT] Skipping empty row $i');
          continue;
        }

        try {
          final rawDate = row[0]?.value;
          debugPrint('[EXCEL_IMPORT] Raw date value: $rawDate (${rawDate.runtimeType})');

          String? dateKey;
          // Always convert to string first to handle SharedString objects
          String rawDateString = rawDate.toString();
          debugPrint('[EXCEL_IMPORT] Converted date to string: "$rawDateString"');
          
          // Special handling for SharedString type that might come from Excel
          if (rawDate.runtimeType.toString().contains('SharedString')) {
            debugPrint('[EXCEL_IMPORT] Detected SharedString type, extracting value');
            // The format appears to be the actual date we want, so use it directly if it follows yyyy-MM-dd pattern
            if (rawDateString.length == 10 && rawDateString.contains('-') && 
                rawDateString.indexOf('-') == 4 && rawDateString.lastIndexOf('-') == 7) {
              dateKey = rawDateString;
              debugPrint('[EXCEL_IMPORT] Using SharedString value directly: $dateKey');
            }
          } else if (rawDate is DateTime) {
            dateKey = DateFormat('yyyy-MM-dd').format(rawDate);
          } else if (rawDateString.isNotEmpty) {
            // Handle date in common format "2025-05-21" directly
            if (rawDateString.length == 10 && rawDateString.contains('-')) {
              if (rawDateString.indexOf('-') == 4 && rawDateString.lastIndexOf('-') == 7) {
                // Direct match for yyyy-MM-dd format
                debugPrint('[EXCEL_IMPORT] Found date in yyyy-MM-dd format, using directly: $rawDateString');
                dateKey = rawDateString;
              }
            }
            
            // If we don't have a date key yet, try more parsing methods
            if (dateKey == null) {
              // Try various date formats
              DateTime? parsed;
              try {
                // Try to parse the raw string
                parsed = DateTime.tryParse(rawDateString);
                
                // Try other common formats if direct parse fails
                if (parsed == null && rawDateString.length >= 10) {
                  // Try yyyy-MM-dd format with possible time component
                  if (rawDateString.contains('-') && rawDateString.indexOf('-') == 4) {
                    final datePart = rawDateString.substring(0, 10);
                    parsed = DateTime.tryParse(datePart);
                    if (parsed != null) {
                      debugPrint('[EXCEL_IMPORT] Parsed from yyyy-MM-dd part: $datePart');
                    }
                  }
                }
                
                if (parsed != null) {
                  dateKey = DateFormat('yyyy-MM-dd').format(parsed);
                  debugPrint('[EXCEL_IMPORT] Successfully parsed date: $dateKey');
                } else {
                  debugPrint('[EXCEL_IMPORT] ❌ Could not parse date from: $rawDateString');
                  errorCount++;
                  continue;
                }
              } catch (e) {
                debugPrint('[EXCEL_IMPORT] ❌ Error parsing date: $e');
                errorCount++;
                continue;
              }
            }
          }

          if (dateKey == null) {
            debugPrint('[EXCEL_IMPORT] ❌ Could not determine date key for row $i');
            errorCount++;
            continue;
          }

          // Check if we already have an entry for this date
          final existingEntry = _workHoursBoxInstance.get(dateKey);
          if (existingEntry != null) {
            debugPrint('[EXCEL_IMPORT] ⚠️ Skipping existing entry for date: $dateKey');
            skippedCount++;
            continue;
          }

          // Parse clock in time
          final rawClockIn = row[1]?.value;
          DateTime? clockIn;
          if (rawClockIn != null) {
            try {
              if (rawClockIn is DateTime) {
                clockIn = rawClockIn;
              } else {
                final clockInString = rawClockIn.toString();
                if (clockInString.contains(':')) {
                  // Handle time format (HH:mm)
                  final timeParts = clockInString.split(':');
                  if (timeParts.length == 2) {
                    final hours = int.tryParse(timeParts[0]);
                    final minutes = int.tryParse(timeParts[1]);
                    if (hours != null && minutes != null) {
                      final date = DateTime.parse(dateKey);
                      clockIn = DateTime(date.year, date.month, date.day, hours, minutes);
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('[EXCEL_IMPORT] ❌ Error parsing clock in time: $e');
            }
          }

          // Parse clock out time
          final rawClockOut = row[2]?.value;
          DateTime? clockOut;
          if (rawClockOut != null) {
            try {
              if (rawClockOut is DateTime) {
                clockOut = rawClockOut;
              } else {
                final clockOutString = rawClockOut.toString();
                if (clockOutString.contains(':')) {
                  // Handle time format (HH:mm)
                  final timeParts = clockOutString.split(':');
                  if (timeParts.length == 2) {
                    final hours = int.tryParse(timeParts[0]);
                    final minutes = int.tryParse(timeParts[1]);
                    if (hours != null && minutes != null) {
                      final date = DateTime.parse(dateKey);
                      clockOut = DateTime(date.year, date.month, date.day, hours, minutes);
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('[EXCEL_IMPORT] ❌ Error parsing clock out time: $e');
            }
          }

          // Parse duration
          final rawDuration = row[3]?.value;
          int? duration;
          if (rawDuration != null) {
            try {
              if (rawDuration is num) {
                duration = rawDuration.toInt();
              } else {
                final durationString = rawDuration.toString();
                if (durationString.contains(':')) {
                  // Handle duration format (HH:mm)
                  final timeParts = durationString.split(':');
                  if (timeParts.length == 2) {
                    final hours = int.tryParse(timeParts[0]);
                    final minutes = int.tryParse(timeParts[1]);
                    if (hours != null && minutes != null) {
                      duration = hours * 60 + minutes;
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('[EXCEL_IMPORT] ❌ Error parsing duration: $e');
            }
          }

          // Parse off day status
          final rawOffDay = row[4]?.value;
          bool offDay = false;
          if (rawOffDay != null) {
            try {
              if (rawOffDay is bool) {
                offDay = rawOffDay;
              } else {
                final offDayString = rawOffDay.toString().toLowerCase();
                offDay = offDayString == 'true' || offDayString == 'yes' || offDayString == '1';
              }
            } catch (e) {
              debugPrint('[EXCEL_IMPORT] ❌ Error parsing off day status: $e');
            }
          }

          // Parse description
          final rawDescription = row[5]?.value;
          String? description;
          if (rawDescription != null) {
            description = rawDescription.toString();
          }

          // Create the entry
          final entry = {
            'in': clockIn?.toIso8601String(),
            'out': clockOut?.toIso8601String(),
            'duration': duration,
            'offDay': offDay,
            'description': description,
          };

          // Save the entry
          await _workHoursBoxInstance.put(dateKey, entry);
          importedCount++;
          debugPrint('[EXCEL_IMPORT] ✅ Successfully imported entry for $dateKey');

        } catch (e) {
          debugPrint('[EXCEL_IMPORT] ❌ Error processing row $i: $e');
          errorCount++;
        }
      }

      // Log import summary
      debugPrint('[EXCEL_IMPORT] Import completed:');
      debugPrint('✅ Successfully imported: $importedCount entries');
      debugPrint('⚠️ Skipped (existing): $skippedCount entries');
      debugPrint('❌ Errors: $errorCount entries');

    } catch (e) {
      debugPrint('[EXCEL_IMPORT] ❌ Error during import: $e');
      rethrow;
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

  static Future<void> deleteEntry(String dateKey) async {
    try {
      await _workHoursBoxInstance.delete(dateKey);
      await _syncTodayEntry();
    } catch (e) {
      debugPrint('Error in deleteEntry: $e');
      rethrow;
    }
  }

  static Map<String, dynamic>? getEntry(DateTime date) {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      return _workHoursBoxInstance.get(dateKey);
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
    try {
      await _workHoursBoxInstance.clear();
    } catch (e) {
      debugPrint('Error in deleteAllEntries: $e');
      rethrow;
    }
  }
  static ValueListenable<Box> getWorkHoursListenable() {
    return _workHoursBoxInstance.listenable();
  }
  static ValueListenable<Box> getSettingsListenable() {
    return _settingsBoxInstance.listenable();
  }

  static Future<String> exportDataToExcel() async {
    try {
      debugPrint('[EXCEL_EXPORT] Starting Excel export process...');

      // Create a new Excel document
      final excel = Excel.createExcel();

      // Create Settings sheet
      final settingsSheet = excel['Settings'];
      
      // Add headers
      settingsSheet.appendRow(['Setting', 'Value']);
      
      // Export settings
      settingsSheet.appendRow(['DailyTargetHours', getDailyTargetHours().toString()]);
      settingsSheet.appendRow(['MonthlySalary', getMonthlySalary().toString()]);
      
      // Export work days
      final workDays = getWorkDays();
      final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      for (var i = 0; i < workDays.length; i++) {
        settingsSheet.appendRow(['WorkDay_${dayNames[i]}', workDays[i].toString()]);
      }

      // Create WorkHours sheet
      final workHoursSheet = excel['WorkHours'];
      
      // Add headers
      workHoursSheet.appendRow(['Date', 'Clock In', 'Clock Out', 'Duration', 'Off Day', 'Description']);
      
      // Get all work hours entries
      final allEntries = _workHoursBoxInstance.toMap();
      
      // Sort entries by date
      final sortedDates = allEntries.keys.toList()
        ..sort((a, b) => b.compareTo(a)); // Sort in descending order
      
      // Export each entry
      for (final dateKey in sortedDates) {
        final entry = allEntries[dateKey];
        if (entry == null) continue;
        
        final clockIn = entry['in'] as String?;
        final clockOut = entry['out'] as String?;
        final duration = entry['duration'] as int?;
        final offDay = entry['offDay'] as bool? ?? false;
        final description = entry['description'] as String?;
        
        workHoursSheet.appendRow([
          dateKey,
          clockIn ?? '',
          clockOut ?? '',
          duration?.toString() ?? '',
          offDay.toString(),
          description ?? '',
        ]);
      }

      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName = 'work_hours_export_${DateFormat('yyyyMMdd_HHmmss').format(now)}.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      // Save the Excel file
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to encode Excel file');
      }
      
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      debugPrint('[EXCEL_EXPORT] ✅ Excel file exported successfully to: $filePath');
      
      // Return the file path for further use (e.g., sharing)
      return filePath;
    } catch (e) {
      debugPrint('[EXCEL_EXPORT] ❌ Error exporting to Excel: $e');
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

}
