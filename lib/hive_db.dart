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
  static final Box _workHoursBox = Hive.box('work_hours');
  static final Box _settingsBox = Hive.box('settings');

  // Work Hours Operations
  static Future<void> clockIn(DateTime time) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(time);

      // Check if there's any existing entry for this day
      final existing = _workHoursBox.get(dateKey);
      final String? description = existing?['description'] as String?;

      await _workHoursBox.put(dateKey, {
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
            // dateKey = DateFormat('yyyy-MM-dd').format(rawDate);
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

                  // Try dd/MM/yyyy format
                  if (parsed == null && rawDateString.contains('/')) {
                    final parts = rawDateString.split('/');
                    if (parts.length == 3) {
                      parsed = DateTime.tryParse('${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}');
                    }
                  }
                }

                if (parsed != null) {
                  dateKey = DateFormat('yyyy-MM-dd').format(parsed);
                }
              } catch (e) {
                debugPrint('[EXCEL_IMPORT] Error parsing date: $e');
              }
            }

            // Last resort fallback - if it looks like a date string, use it
            if (dateKey == null && rawDateString.length == 10) {
              // Check if it matches yyyy-MM-dd pattern with regex
              final regExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
              if (regExp.hasMatch(rawDateString)) {
                debugPrint('[EXCEL_IMPORT] Using date string based on pattern match: $rawDateString');
                dateKey = rawDateString;
              }
            }
          } else if (rawDate is num) {
            // Handle Excel numeric date format (days since 1900-01-01)
            try {
              // final date = DateTime(1899, 12, 30).add(Duration(days: rawDate.toInt()));
              // dateKey = DateFormat('yyyy-MM-dd').format(date);
              debugPrint('[EXCEL_IMPORT] Converted numeric date: $rawDate to $dateKey');
            } catch (e) {
              debugPrint('[EXCEL_IMPORT] Error converting numeric date: $e');
            }
          }

          debugPrint('[EXCEL_IMPORT] Processed date key: $dateKey');

          if (dateKey == null) {
            debugPrint('[EXCEL_IMPORT] ⚠️ Could not parse date for row $i');
            skippedCount++;
            continue;
          }

          final clockInStr = row[1]?.value?.toString();
          final clockOutStr = row[2]?.value?.toString();
          final offDayStr = (row[4]?.value?.toString() ?? '').toLowerCase();
          final descriptionStr = row.length > 5 ? row[5]?.value?.toString() : null;

          debugPrint('[EXCEL_IMPORT] Row values - Clock In: $clockInStr, Clock Out: $clockOutStr, Off Day: $offDayStr, Description: $descriptionStr');

          bool isOffDay = offDayStr == 'yes' || offDayStr == 'true' || offDayStr == '1';
          String? description = isOffDay ? (descriptionStr ?? 'Annual Leave') : descriptionStr;

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
              'description': description,
            });
            importedCount++;
          }
        } catch (e) {
          debugPrint('[EXCEL_IMPORT] ❌ Error processing row $i: $e');
          errorCount++;
        }
      }

      // Update widget after import
      await updateWidget();
      await updateWidgetWithOvertimeInfo();

      debugPrint('[EXCEL_IMPORT] ✅ Import completed. Imported: $importedCount, Skipped: $skippedCount, Errors: $errorCount');

      // Throw an exception if there were any errors during import
      if (errorCount > 0) {
        throw Exception('Import completed with $errorCount errors. Please check the logs for details.');
      }
    } catch (e, stackTrace) {
      debugPrint('[EXCEL_IMPORT] ❌ Error importing from Excel: $e');
      debugPrint('[EXCEL_IMPORT] Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> exportDataToExcel() async {
    try {
      debugPrint('📊 Starting Excel export process...');
      final entries = getAllEntries();
      final excel = Excel.createExcel(); // Creates a new Excel file
      final sheet = excel['WorkHours']; // Sheet name

      // Add Header with Description column
      sheet.appendRow([
        // 'Date',
        // 'Clock In',
        // 'Clock Out',
        // 'Duration (minutes)',
        // 'Off Day',
        // 'Description'
      ]);

      // Create a Settings sheet for app settings
      final settingsSheet = excel['Settings'];

      // Add header
      settingsSheet.appendRow([
        // 'Setting',
        // 'Value'
      ]);

      // Export settings
      // settingsSheet.appendRow(['DailyTargetHours', getDailyTargetHours().toString()]);
      // settingsSheet.appendRow(['MonthlySalary', getMonthlySalary().toString()]);

      // Export work days
      final workDays = getWorkDays();
      for (int i = 0; i < 7; i++) {
        final dayName = _getDayName(i);
        // settingsSheet.appendRow(['WorkDay_$dayName', workDays[i].toString()]);
      }

      // Add entries
      entries.forEach((date, entry) {
        // Format the date as a simple string to ensure it can be properly parsed on import
        final formattedDate = date;

        sheet.appendRow([
          // formattedDate, // Use the date key directly as the date
          entry['in'] ?? '',
          entry['out'] ?? '',
          entry['duration'] ?? 0,
          // entry['offDay'] == true ? 'Yes' : 'No',
          entry['description'] ?? '',
        ]);
      });

      // Generate Excel file data
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        debugPrint('⚠️ Failed to generate Excel file data.');
        throw Exception('Failed to generate Excel file data');
      }

      // Convert List<int> to Uint8List for the file picker
      final Uint8List uint8FileBytes = Uint8List.fromList(fileBytes);

      // Let user pick the save location with a suggested filename
      debugPrint('📂 Asking user to select export location...');
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final suggestedFileName = 'work_hours_backup_$timestamp.xlsx';

      // On Android 11+, use FileSaver for saving directly (more permission friendly)
      if (Platform.isAndroid) {
        int? sdkVersion;
        try {
          const platform = MethodChannel('work_hours/system_info');
          sdkVersion = await platform.invokeMethod<int>('getAndroidSdkVersion');
        } catch (e) {
          debugPrint('Error getting Android SDK version: $e');
        }

        // If we're on Android 11+ (API 30+), use the saveable file approach
        if (sdkVersion != null && sdkVersion >= 30) {
          debugPrint('📱 Using Android 11+ file saving approach');

          // For Android 11+, we need to pass the bytes directly to saveFile
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Work Hours Export',
            fileName: suggestedFileName,
            allowedExtensions: ['xlsx'],
            type: FileType.custom,
            // bytes: uint8FileBytes, // Pass the Uint8List bytes
          );

          if (result == null) {
            debugPrint('⚠️ User canceled file save operation');
            return;
          }

          debugPrint('✅ Exported work hours to Excel successfully using the system file picker');
          return;
        }
      }

      // Legacy approach for older Android versions and other platforms
      debugPrint('📱 Using legacy file saving approach');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        debugPrint('⚠️ User canceled directory selection.');
        return;
      }

      // Create the file path
      final path = '$selectedDirectory/$suggestedFileName';
      debugPrint('📝 Preparing to export to: $path');

      // Create directory path if it doesn't exist
      try {
        final directory = Directory(selectedDirectory);
        if (!await directory.exists()) {
          debugPrint('📁 Creating directory: $selectedDirectory');
          await directory.create(recursive: true);
        }

        // Verify the directory was created and is writable
        if (!await directory.exists()) {
          throw Exception('Failed to create directory: $selectedDirectory');
        }

        // Test write permissions by creating a small test file
        final testFile = File('$selectedDirectory/test_write_permissions.txt');
        await testFile.writeAsString('Testing write permissions');
        await testFile.delete(); // Clean up the test file
        debugPrint('✅ Write permissions verified');
      } catch (e) {
        debugPrint('❌ Error with directory: $e');
        throw Exception('Cannot write to selected directory. Please choose another location or check app permissions.');
      }

      // Write the file
      final file = File(path);
      await file.writeAsBytes(uint8FileBytes);
      debugPrint('✅ Exported work hours to Excel: $path');

      // Verify the file was written successfully
      if (!await file.exists()) {
        throw Exception('File was not created: $path');
      }

      final fileSize = await file.length();
      debugPrint('📊 Exported file size: $fileSize bytes');
    } catch (e) {
      debugPrint('❌ Error exporting to Excel: $e');
      rethrow;
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
      String? description;

      if (existing != null) {
        if (existing['duration'] != null) {
          previousDuration = (existing['duration'] as num).toInt();
        }
        // Preserve any existing description
        description = existing['description'] as String?;
      }

      await _workHoursBox.put(dateKey, {
        'in': clockInTime.toIso8601String(),
        'out': time.toIso8601String(),
        'duration': previousDuration + workedDuration,
        'offDay': existing?['offDay'] ?? false,
        'description': description,
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
      int nonWorkingDays = 0;
      final dailyTarget = getDailyTargetMinutes();
      final workDaysSetting = getWorkDays();

      debugPrint('\n🔍 [STATS_DEBUG] Calculating stats for range:');
      debugPrint('Start date: ${DateFormat('yyyy-MM-dd').format(start)}');
      debugPrint('End date: ${DateFormat('yyyy-MM-dd').format(end)}');

      for (var day = start;
          day.isBefore(end.add(const Duration(days: 1)));
          day = day.add(const Duration(days: 1))) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final entry = _workHoursBox.get(dateKey);
        final weekdayIndex = day.weekday - 1; // 0-based index (0 = Monday)
        final bool isConfiguredWorkDay = workDaysSetting[weekdayIndex];

        if (entry != null) {
          if (entry['offDay'] == true) {
            totalMinutes += dailyTarget;
            offDays++;
            debugPrint('📅 $dateKey: Off Day (Description: ${entry['description']})');
          } else if (entry['duration'] != null) {
            totalMinutes += (entry['duration'] as num).toInt();
            workDays++;
            debugPrint('📅 $dateKey: Work Day (Duration: ${entry['duration']} minutes)');
          }
        } else {
          // If no entry and it's not a configured work day (e.g., Friday), count it as a non-working day
          if (!isConfiguredWorkDay) {
            nonWorkingDays++;
            debugPrint('📅 $dateKey: Non-Work Day (${_getDayName(weekdayIndex)})');
          } else {
            debugPrint('📅 $dateKey: No entry');
          }
        }
      }

      debugPrint('\n📊 [STATS_DEBUG] Final counts:');
      debugPrint('Total Minutes: $totalMinutes');
      debugPrint('Work Days: $workDays');
      debugPrint('Off Days (Excused): $offDays');
      debugPrint('Non-Work Days: $nonWorkingDays');
      debugPrint('Total Days Off: ${offDays + nonWorkingDays}');

      return {
        'totalMinutes': totalMinutes,
        'workDays': workDays,
        'offDays': offDays,
        'nonWorkingDays': nonWorkingDays,
        'totalDaysOff': offDays + nonWorkingDays,
      };
    } catch (e) {
      debugPrint('Error in getStatsForRange: $e');
      return {
        'totalMinutes': 0,
        'workDays': 0,
        'offDays': 0,
        'nonWorkingDays': 0,
        'totalDaysOff': 0,
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

  static bool getClockInReminderEnabled() {
    try {
      return _settingsBox.get('clockInReminderEnabled', defaultValue: true);
    } catch (e) {
      debugPrint('Error in getClockInReminderEnabled: $e');
      return true;
    }
  }

  static Future<void> setClockInReminderEnabled(bool enabled) async {
    try {
      await _settingsBox.put('clockInReminderEnabled', enabled);
    } catch (e) {
      debugPrint('Error in setClockInReminderEnabled: $e');
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

  static bool getClockOutReminderEnabled() {
    try {
      return _settingsBox.get('clockOutReminderEnabled', defaultValue: true);
    } catch (e) {
      debugPrint('Error in getClockOutReminderEnabled: $e');
      return true;
    }
  }

  static Future<void> setClockOutReminderEnabled(bool enabled) async {
    try {
      await _settingsBox.put('clockOutReminderEnabled', enabled);
    } catch (e) {
      debugPrint('Error in setClockOutReminderEnabled: $e');
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
      // Debug: Check what's happening with the widget page
      final widgetPageTest = await HomeWidget.getWidgetData<dynamic>('_widgetPage');
      debugPrint("🔍 [WIDGET_DEBUG] Current widget page data: ${widgetPageTest} (type: ${widgetPageTest?.runtimeType})");

      final now = DateTime.now();
      final todayEntry = getDayEntry(now);
      debugPrint("🔍 [WIDGET_DEBUG] Today's entry: ${todayEntry != null ? 'found' : 'not found'}");
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
          debugPrint("🔍 [WIDGET_DEBUG] Clock in time found: $clockInText");
        }
        if (outTimeStr != null) {
          final outTime = DateTime.parse(outTimeStr);
          clockOutText = "Out: ${DateFormat.Hm().format(outTime)}";
          isClockedIn = false; // Explicitly set to false if clocked out
          debugPrint("🔍 [WIDGET_DEBUG] Clock out time found: $clockOutText");
        } else if (inTimeStr != null) {
          // If clocked in but not out
          clockOutText = "Out: Pending";
          isClockedIn = true;
          debugPrint("🔍 [WIDGET_DEBUG] No clock out time yet, showing 'Pending'");
        }
      }

      // Calculate overtime using our new method
      final overtimeMinutes = getMonthlyOvertime();
      final overtimeText =
          "Overtime: ${_formatDurationForWidgetDb(overtimeMinutes)}";
      debugPrint("🔍 [WIDGET_DEBUG] Calculated overtime: $overtimeMinutes minutes");

      // Save text data for widget
      await HomeWidget.saveWidgetData<String>('_clockInText', clockInText);
      await HomeWidget.saveWidgetData<String>('_clockOutText', clockOutText);
      await HomeWidget.saveWidgetData<String>('_overtimeText', overtimeText);

      // Check if _widgetPage exists and set it to 0 if it doesn't
      final widgetPage = await HomeWidget.getWidgetData<int>('_widgetPage');
      debugPrint("🔍 [WIDGET_DEBUG] Retrieved widget page: $widgetPage (type: ${widgetPage?.runtimeType})");
      if (widgetPage == null) {
        await HomeWidget.saveWidgetData<int>('_widgetPage', 0);
        debugPrint("🔍 [WIDGET_DEBUG] Widget page was null, setting to 0");
      }

      debugPrint("Saving widget data:");
      debugPrint("Clock In: $clockInText");
      debugPrint("Clock Out: $clockOutText");
      debugPrint("Overtime: $overtimeText");

      // Update the widget (this now implicitly handles click registration via the callback)
      await HomeWidget.updateWidget(
          name: 'MyHomeWidgetProvider',
          androidName: 'MyHomeWidgetProvider',
          iOSName: 'MyHomeWidgetProvider');

      debugPrint("🔍 [WIDGET_DEBUG] HomeWidget update triggered");
    } catch (e, stackTrace) {
      debugPrint('❌ [WIDGET_DEBUG] Error syncing today entry for widget: $e');
      debugPrint('❌ [WIDGET_DEBUG] Stack trace: $stackTrace');
    }
  }

  // Public method to trigger widget update
  static Future<void> updateWidget() async {
    debugPrint("🔄 [WIDGET_DEBUG] HiveDb.updateWidget() called - Updating HomeWidget with current data");
    try {
      await _syncTodayEntry();
      debugPrint("✅ [WIDGET_DEBUG] HomeWidget update completed successfully");
    } catch (e, stackTrace) {
      debugPrint("❌ [WIDGET_DEBUG] HomeWidget update failed: $e");
      debugPrint("❌ [WIDGET_DEBUG] Stack trace: $stackTrace");
    }
  }

  // Method to update the widget with overtime information
  static Future<void> updateWidgetWithOvertimeInfo() async {
    try {
      debugPrint("🔄 [WIDGET_DEBUG] Updating widget with overtime information...");
      // Get current month info
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final today = DateTime(now.year, now.month, now.day);
      final currentMonthName = DateFormat('MMMM yyyy').format(firstOfMonth);

      // Get workdays counter
      final allEntries = getAllEntries();
      final workDaysSetting = getWorkDays();
      final dailyTarget = getDailyTargetMinutes();

      // Initialize counters
      int regularWorkDays = 0;
      int offDays = 0;
      int extraWorkDays = 0;
      int totalWorkedMinutes = 0;
      int totalExpectedMinutes = 0;

      // Calculate days and minutes
      for (var day = firstOfMonth;
          day.isBefore(today.add(const Duration(days: 1)));
          day = day.add(const Duration(days: 1))) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final entry = allEntries[dateKey];
        final weekdayIndex = day.weekday - 1; // 0-based index (0 = Monday)
        final bool isConfiguredWorkDay = workDaysSetting[weekdayIndex];

        // Count expected work time
        if (isConfiguredWorkDay) {
          totalExpectedMinutes += dailyTarget;
        }

        // Count actual work time
        if (entry != null) {
          if (entry['offDay'] == true) {
            offDays++;
            totalWorkedMinutes += dailyTarget;
          } else if (entry['duration'] != null) {
            final duration = (entry['duration'] as num).toInt();
            totalWorkedMinutes += duration;

            if (isConfiguredWorkDay) {
              regularWorkDays++;
            } else {
              extraWorkDays++;
            }
          }
        }
      }

      // Calculate overtime
      final overtimeMinutes = totalWorkedMinutes - totalExpectedMinutes;
      final isAhead = overtimeMinutes >= 0;
      debugPrint("🔍 [WIDGET_DEBUG] Calculated total expected minutes: $totalExpectedMinutes");
      debugPrint("🔍 [WIDGET_DEBUG] Calculated total worked minutes: $totalWorkedMinutes");
      debugPrint("🔍 [WIDGET_DEBUG] Calculated overtime minutes: $overtimeMinutes");

      // Format strings for the widget
      final overtimeText = "Overtime: ${_formatDurationForWidgetDb(overtimeMinutes)}";
      final expectedHours = totalExpectedMinutes ~/ 60;
      final expectedMinutes = totalExpectedMinutes % 60;
      final actualHours = totalWorkedMinutes ~/ 60;
      final actualMinutes = totalWorkedMinutes % 60;
      final expectedVsActual = "Expected: ${expectedHours}h ${expectedMinutes}m / Actual: ${actualHours}h ${actualMinutes}m";
      final workDaysText = "Work Days: ${regularWorkDays + extraWorkDays}";
      final offDaysText = "Off Days: $offDays";
      final statusMessage = isAhead
          ? "You are ahead of schedule!"
          : "You are behind schedule";

      // Save extended data for widget
      await HomeWidget.saveWidgetData<String>('_currentMonthName', currentMonthName);
      await HomeWidget.saveWidgetData<String>('_overtimeText', overtimeText);
      await HomeWidget.saveWidgetData<String>('_expectedVsActual', expectedVsActual);
      await HomeWidget.saveWidgetData<String>('_workDaysText', workDaysText);
      await HomeWidget.saveWidgetData<String>('_offDaysText', offDaysText);
      await HomeWidget.saveWidgetData<String>('_statusMessage', statusMessage);
      await HomeWidget.saveWidgetData<int>('_overtimeColor', isAhead ? 1 : 0); // 1 = green, 0 = red

      debugPrint("Saving extended widget data:");
      debugPrint("Month: $currentMonthName");
      debugPrint("Overtime: $overtimeText");
      debugPrint("Expected vs Actual: $expectedVsActual");
      debugPrint("Work Days: $workDaysText");
      debugPrint("Off Days: $offDaysText");
      debugPrint("Status Message: $statusMessage");
      debugPrint("Overtime Color: ${isAhead ? 'green' : 'red'}");

      // Trigger widget update
      await HomeWidget.updateWidget(
          name: 'MyHomeWidgetProvider',
          androidName: 'MyHomeWidgetProvider',
          iOSName: 'MyHomeWidgetProvider');

      // Get the current widget page, if any
      final currentWidgetPage = await HomeWidget.getWidgetData<int>('_widgetPage') ?? 0;
      debugPrint("🔍 [WIDGET_DEBUG] Current widget page before preserving: $currentWidgetPage");
      // Preserve the current widget page in case it was changed by the user
      await HomeWidget.saveWidgetData<int>('_widgetPage', currentWidgetPage);

      debugPrint("✅ [WIDGET_DEBUG] Widget updated with overtime information.");
    } catch (e, stackTrace) {
      debugPrint('❌ [WIDGET_DEBUG] Error updating widget with overtime info: $e');
      debugPrint('❌ [WIDGET_DEBUG] Stack trace: $stackTrace');
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

        // Only add target minutes for configured work days
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

  static double getMonthlySalary() {
    try {
      return _settingsBox.get('monthlySalary', defaultValue: 0.0);
    } catch (e) {
      debugPrint('Error in getMonthlySalary: $e');
      return 0.0;
    }
  }

  static Future<void> setMonthlySalary(double salary) async {
    try {
      if (salary < 0) return;
      debugPrint('🔍 [MONTHLY_SALARY] Setting monthly salary to: $salary');
      await _settingsBox.put('monthlySalary', salary);
      final saved = _settingsBox.get('monthlySalary');
      debugPrint('🔍 [MONTHLY_SALARY] Verified saved value: $saved');
    } catch (e) {
      debugPrint('Error in setMonthlySalary: $e');
      rethrow;
    }
  }

  static int _getDayIndex(String dayName) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.indexOf(dayName);
  }

  static List<Map<String, dynamic>> getEntriesForRange(DateTime start, DateTime end) {
    final box = Hive.box('work_hours');
    final entries = <Map<String, dynamic>>[];

    // Convert dates to start and end of day
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);

    // Get all entries
    final allEntries = box.toMap();

    // Filter entries within the date range
    allEntries.forEach((key, value) {
      if (value is Map) {
        final entryDate = DateTime.parse(key);
        if (entryDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            entryDate.isBefore(endDate.add(const Duration(days: 1)))) {
          // Add the date to the entry map
          final entry = Map<String, dynamic>.from(value);
          entry['date'] = key; // Add the date key to the entry
          entries.add(entry);
        }
      }
    });

    // Sort entries by date
    entries.sort((a, b) {
      final dateA = DateTime.parse(a['date'] as String);
      final dateB = DateTime.parse(b['date'] as String);
      return dateA.compareTo(dateB);
    });

    return entries;
  }
}

