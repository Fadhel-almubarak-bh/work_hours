import 'package:flutter/material.dart';
import '../../data/repositories/work_hours_repository.dart';
import '../../data/models/settings.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/local/hive_db.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';

class SettingsController extends ChangeNotifier {
  final WorkHoursRepository _repository;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  bool _isLoading = false;
  Settings? _settings;
  String? _error;

  SettingsController(this._repository);

  bool get isLoading => _isLoading;
  Settings? get settings => _settings;
  String? get error => _error;

  Future<void> initialize() async {
    await loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _repository.getSettings();
      if (_settings == null) {
        // Create default settings if none exist
        _settings = Settings(
          monthlySalary: 0,
          dailyTargetHours: 8,
          workDays: [true, true, true, true, true, false, false], // Mon-Fri
          currency: 'USD',
          insuranceRate: 0.08,
          overtimeRate: 1.5,
          themeMode: ThemeMode.system,
        );
        await saveSettings(_settings!);
      }
    } catch (e) {
      _error = 'Failed to load settings: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSettings(Settings newSettings) async {
    try {
      await _repository.saveSettings(newSettings);
      _settings = newSettings;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save settings: $e';
      debugPrint(_error);
    }
  }

  Future<void> updateMonthlySalary(double salary) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(monthlySalary: salary);
    await saveSettings(newSettings);
  }

  Future<void> updateDailyTargetHours(int hours) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(dailyTargetHours: hours);
    await saveSettings(newSettings);
  }

  Future<void> updateWorkDays(List<bool> workDays) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(workDays: workDays);
    await saveSettings(newSettings);
  }

  Future<void> updateCurrency(String currency) async {
    if (_settings == null) return;
    try {
      final newSettings = _settings!.copyWith(currency: currency);
      await saveSettings(newSettings);
    } catch (e) {
      _error = 'Failed to update currency: $e';
      debugPrint(_error);
    }
  }

  Future<void> updateInsuranceRate(double rate) async {
    if (_settings == null) return;
    try {
      // Ensure rate is between 0 and 1
      final clampedRate = rate.clamp(0.0, 1.0);
      final newSettings = _settings!.copyWith(insuranceRate: clampedRate);
      await saveSettings(newSettings);
    } catch (e) {
      _error = 'Failed to update insurance rate: $e';
      debugPrint(_error);
    }
  }

  Future<void> updateOvertimeRate(double rate) async {
    if (_settings == null) return;
    try {
      // Ensure overtime rate is at least 1.0 (100%)
      final clampedRate = rate.clamp(1.0, 3.0);
      final newSettings = _settings!.copyWith(overtimeRate: clampedRate);
      await saveSettings(newSettings);
    } catch (e) {
      _error = 'Failed to update overtime rate: $e';
      debugPrint(_error);
    }
  }

  Future<void> updateThemeMode(ThemeMode? mode, BuildContext context) async {
    if (_settings == null || mode == null) return;
    final newSettings = _settings!.copyWith(themeMode: mode);
    await saveSettings(newSettings);
    
    // Update the theme provider using the existing instance
    final themeProvider = ThemeProvider.of(context);
    themeProvider.setThemeMode(mode);
  }

  String formatCurrency(double amount) {
    if (_settings == null) return '\$${amount.toStringAsFixed(2)}';
    return '${_settings!.currency} ${amount.toStringAsFixed(2)}';
  }

  String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  Future<void> exportDataToExcel(BuildContext context) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        fileName: 'work_hours_export.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
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

        // Get work entries from repository
        final entries = await _repository.getAllWorkEntries();
        final settings = await _repository.getSettings();
        
        for (final entry in entries) {
          final totalHours = entry.duration / 60.0;
          final expectedHours = settings?.dailyTargetHours ?? 8.0;
          final overtime = totalHours > expectedHours ? totalHours - expectedHours : 0.0;
          final regularHours = totalHours - overtime;

          sheet.appendRow([
            TextCellValue(entry.date.toString()),
            TextCellValue(entry.clockIn.toString()),
            TextCellValue(entry.clockOut?.toString() ?? ''),
            TextCellValue(regularHours.toStringAsFixed(2)),
            TextCellValue(overtime.toStringAsFixed(2)),
          ]);
        }

        // Save the file
        final bytes = excel.encode();
        if (bytes != null) {
          final file = File(result);
          await file.writeAsBytes(bytes);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data exported successfully')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error exporting data: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
    }
  }

  Future<void> importDataFromExcel(BuildContext context) async {
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
            final dateStr = row[0]?.value.toString() ?? '';
            final clockInStr = row[1]?.value.toString() ?? '';
            final clockOutStr = row[2]?.value.toString() ?? '';
            final hoursStr = row[3]?.value.toString() ?? '0';
            final overtimeStr = row[4]?.value.toString() ?? '0';

            if (dateStr.isNotEmpty && clockInStr.isNotEmpty) {
              final date = DateTime.parse(dateStr);
              final clockIn = DateTime.parse(clockInStr);
              final clockOut = clockOutStr.isNotEmpty ? DateTime.parse(clockOutStr) : null;
              final hours = double.parse(hoursStr);
              final overtime = double.parse(overtimeStr);

              await _repository.addWorkEntry(
                date: date,
                clockIn: clockIn,
                clockOut: clockOut,
                hours: hours,
                overtime: overtime,
              );
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

  Future<void> printDebugInfo(BuildContext context) async {
    try {
      final entries = await _repository.getAllWorkEntries();
      final settings = await _repository.getSettings();
      
      // Print to console
      debugPrint('\n🔧 [SETTINGS DEBUG INFO]');
      debugPrint('==========================================');
      
      // Settings Information
      debugPrint('\n⚙️ Settings:');
      debugPrint('----------------------');
      debugPrint('Monthly Salary: ${settings?.monthlySalary}');
      debugPrint('Daily Target Hours: ${settings?.dailyTargetHours}');
      debugPrint('Currency: ${settings?.currency}');
      debugPrint('Insurance Rate: ${(settings?.insuranceRate ?? 0) * 100}%');
      debugPrint('Overtime Rate: ${(settings?.overtimeRate ?? 0) * 100}%');
      debugPrint('Theme Mode: ${settings?.themeMode}');
      
      // Work Days Configuration
      debugPrint('\n📅 Work Days Configuration:');
      debugPrint('----------------------');
      final workDays = settings?.workDays ?? [];
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var i = 0; i < 7; i++) {
        debugPrint('${days[i]}: ${workDays[i] ? '✓' : '✗'}');
      }
      
      // Work Entries Summary
      debugPrint('\n📊 Work Entries Summary:');
      debugPrint('----------------------');
      debugPrint('Total Entries: ${entries.length}');
      
      // Group entries by month
      final entriesByMonth = <String, List<dynamic>>{};
      for (final entry in entries) {
        final monthKey = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}';
        entriesByMonth.putIfAbsent(monthKey, () => []).add(entry);
      }
      
      // Print monthly statistics
      debugPrint('\n📅 Monthly Statistics:');
      debugPrint('----------------------');
      entriesByMonth.forEach((month, monthEntries) {
        final totalMinutes = monthEntries.fold<int>(0, (sum, e) => sum + (e.duration as int));
        final totalHours = totalMinutes / 60;
        debugPrint('$month: ${monthEntries.length} entries, ${totalHours.toStringAsFixed(1)} hours');
      });
      
      // Show dialog with the same information
      final debugInfo = StringBuffer();
      debugInfo.writeln('=== Debug Information ===');
      debugInfo.writeln('\nSettings:');
      debugInfo.writeln('Monthly Salary: ${settings?.monthlySalary}');
      debugInfo.writeln('Daily Target Hours: ${settings?.dailyTargetHours}');
      debugInfo.writeln('Work Days: ${settings?.workDays}');
      debugInfo.writeln('Currency: ${settings?.currency}');
      debugInfo.writeln('Insurance Rate: ${settings?.insuranceRate}');
      debugInfo.writeln('Overtime Rate: ${settings?.overtimeRate}');
      debugInfo.writeln('Theme Mode: ${settings?.themeMode}');
      
      debugInfo.writeln('\nWork Entries (${entries.length}):');
      for (final entry in entries) {
        final totalHours = entry.duration / 60.0;
        final expectedHours = settings?.dailyTargetHours ?? 8.0;
        final overtime = totalHours > expectedHours ? totalHours - expectedHours : 0.0;
        final regularHours = totalHours - overtime;

        debugInfo.writeln('Date: ${entry.date}');
        debugInfo.writeln('Clock In: ${entry.clockIn}');
        debugInfo.writeln('Clock Out: ${entry.clockOut}');
        debugInfo.writeln('Hours: ${regularHours.toStringAsFixed(2)}');
        debugInfo.writeln('Overtime: ${overtime.toStringAsFixed(2)}');
        debugInfo.writeln('---');
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Debug Information'),
            content: SingleChildScrollView(
              child: Text(debugInfo.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error printing debug info: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing debug info: $e')),
        );
      }
    }
  }

  Future<void> printSalaryDebugInfo(BuildContext context) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      
      final settings = await _repository.getSettings();
      if (settings == null) {
        throw Exception('Settings not found');
      }

      final salaryData = await _repository.calculateSalary(now);
      
      debugPrint('\n💰 [SALARY DEBUG INFO]');
      debugPrint('==========================================');
      
      // Basic Settings
      debugPrint('\n⚙️ Basic Settings:');
      debugPrint('----------------------');
      debugPrint('Monthly Salary: ${settings.monthlySalary}');
      debugPrint('Daily Target Hours: ${settings.dailyTargetHours}');
      debugPrint('Insurance Rate: ${(settings.insuranceRate * 100).toStringAsFixed(1)}%');
      debugPrint('Overtime Rate: ${(settings.overtimeRate * 100).toStringAsFixed(1)}%');
      
      // Work Days Configuration
      debugPrint('\n📅 Work Days Configuration:');
      debugPrint('----------------------');
      final workDays = settings.workDays;
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var i = 0; i < 7; i++) {
        debugPrint('${days[i]}: ${workDays[i] ? '✓' : '✗'}');
      }
      
      // Monthly Calculations
      debugPrint('\n📊 Monthly Calculations:');
      debugPrint('----------------------');
      debugPrint('Expected Work Days: ${salaryData['expectedWorkDays']}');
      debugPrint('Expected Hours: ${salaryData['expectedHours']}');
      debugPrint('Expected Minutes: ${salaryData['expectedMinutes']}');
      debugPrint('Actual Minutes: ${salaryData['actualMinutes']}');
      debugPrint('Overtime Minutes: ${salaryData['overtimeMinutes']}');
      debugPrint('Off Days Count: ${salaryData['offDaysCount']}');
      debugPrint('Non-working Days: ${salaryData['nonWorkingDaysCount']}');
      debugPrint('Total Days Off: ${salaryData['totalDaysOff']}');
      
      // Rate Calculations
      debugPrint('\n💵 Rate Calculations:');
      debugPrint('----------------------');
      debugPrint('Daily Rate: ${salaryData['dailyRate']}');
      debugPrint('Hourly Rate: ${salaryData['hourlyRate']}');
      debugPrint('Overtime Rate: ${salaryData['overtimeRate']}');
      
      // Earnings Breakdown
      debugPrint('\n💰 Earnings Breakdown:');
      debugPrint('----------------------');
      debugPrint('Regular Hours Earnings: ${(salaryData['actualMinutes'] - salaryData['overtimeMinutes']) * salaryData['hourlyRate'] / 60}');
      debugPrint('Overtime Pay: ${salaryData['overtimePay']}');
      debugPrint('Work Days Earnings: ${salaryData['workDaysEarnings']}');
      debugPrint('Off Days Earnings: ${salaryData['offDaysEarnings']}');
      debugPrint('Total Earnings: ${salaryData['totalEarnings']}');
      debugPrint('After Insurance: ${salaryData['earningsAfterInsurance']}');
      
      // Today's Status
      debugPrint('\n📅 Today\'s Status:');
      debugPrint('----------------------');
      debugPrint('Minutes Worked: ${salaryData['todayMinutes']}');
      debugPrint('Today\'s Earnings: ${salaryData['todayEarnings']}');
      
      debugPrint('\n==========================================\n');
      
      // Show snackbar with success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salary debug information printed to console'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error printing salary debug info: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> printSummaryDebugInfo(BuildContext context) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      
      final settings = await _repository.getSettings();
      if (settings == null) {
        throw Exception('Settings not found');
      }

      final entries = await _repository.getAllWorkEntries();
      
      debugPrint('\n📊 [SUMMARY DEBUG INFO]');
      debugPrint('==========================================');
      
      // Settings Information
      debugPrint('\n⚙️ Settings:');
      debugPrint('----------------------');
      debugPrint('Monthly Salary: ${settings.monthlySalary}');
      debugPrint('Daily Target Hours: ${settings.dailyTargetHours}');
      debugPrint('Currency: ${settings.currency}');
      debugPrint('Insurance Rate: ${(settings.insuranceRate * 100).toStringAsFixed(1)}%');
      debugPrint('Overtime Rate: ${(settings.overtimeRate * 100).toStringAsFixed(1)}%');
      
      // Work Days Configuration
      debugPrint('\n📅 Work Days Configuration:');
      debugPrint('----------------------');
      final workDays = settings.workDays;
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var i = 0; i < 7; i++) {
        debugPrint('${days[i]}: ${workDays[i] ? '✓' : '✗'}');
      }
      
      // Current Week Stats
      debugPrint('\n📅 Current Week Stats:');
      debugPrint('----------------------');
      final weekEntries = entries.where((e) => 
        e.date.isAfter(weekStart.subtract(const Duration(days: 1))) && 
        e.date.isBefore(weekStart.add(const Duration(days: 7)))
      ).toList();
      
      final weekMinutes = weekEntries.fold<int>(0, (sum, e) => sum + e.duration);
      final weekExpectedMinutes = settings.dailyTargetHours * 60 * settings.workDays.where((d) => d).length;
      final weekOvertime = weekMinutes > weekExpectedMinutes ? weekMinutes - weekExpectedMinutes : 0;
      
      debugPrint('Week Start: $weekStart');
      debugPrint('Entries This Week: ${weekEntries.length}');
      debugPrint('Minutes Worked: $weekMinutes');
      debugPrint('Expected Minutes: $weekExpectedMinutes');
      debugPrint('Overtime Minutes: $weekOvertime');
      
      // Current Month Stats
      debugPrint('\n📅 Current Month Stats:');
      debugPrint('----------------------');
      final monthEntries = entries.where((e) => 
        e.date.isAfter(monthStart.subtract(const Duration(days: 1))) && 
        e.date.isBefore(DateTime(now.year, now.month + 1, 1))
      ).toList();
      
      // Calculate expected work days for the month
      int expectedWorkDays = 0;
      int totalOffDays = 0;
      int totalNonWorkDays = 0;
      int totalMinutesWorked = 0;
      int expectedMinutes = 0;
      int actualWorkDays = 0;
      int actualOffDays = 0;

      for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        final weekdayIndex = day.weekday - 1;
        final bool isWorkDay = workDays[weekdayIndex];
        final entry = HiveDb.getDayEntry(day);

        if (isWorkDay) {
          expectedWorkDays++;
          expectedMinutes += settings.dailyTargetHours * 60;

          if (entry != null) {
            if (entry['offDay'] == true) {
              totalOffDays++;
              actualOffDays++;
              totalMinutesWorked += settings.dailyTargetHours * 60;
            } else if (entry['duration'] != null) {
              actualWorkDays++;
              totalMinutesWorked += (entry['duration'] as num).toInt();
            } else if (entry['in'] != null && entry['out'] == null && day.isAtSameMomentAs(now)) {
              actualWorkDays++;
              final clockInTime = DateTime.parse(entry['in']);
              final currentDuration = now.difference(clockInTime).inMinutes;
              totalMinutesWorked += currentDuration;
            }
          }
        } else {
          totalNonWorkDays++;
        }
      }
      
      final monthMinutes = monthEntries.fold<int>(0, (sum, e) => sum + e.duration);
      final monthExpectedMinutes = expectedWorkDays * settings.dailyTargetHours * 60;
      final monthOvertime = monthMinutes > monthExpectedMinutes ? monthMinutes - monthExpectedMinutes : 0;
      
      debugPrint('Month Start: $monthStart');
      debugPrint('Month End: $monthEnd');
      debugPrint('Expected Work Days: $expectedWorkDays');
      debugPrint('Entries This Month: ${monthEntries.length}');
      debugPrint('Minutes Worked: $monthMinutes');
      debugPrint('Expected Minutes: $monthExpectedMinutes');
      debugPrint('Overtime Minutes: $monthOvertime');
      
      // Monthly Progress Analysis
      debugPrint('\n📊 Monthly Progress Analysis:');
      debugPrint('----------------------');
      debugPrint('Total Work Days in Month: $expectedWorkDays');
      debugPrint('Total Off Days: $totalOffDays');
      debugPrint('Total Non-Work Days: $totalNonWorkDays');
      debugPrint('Total Minutes Worked: $totalMinutesWorked');
      debugPrint('Expected Minutes: $expectedMinutes');
      debugPrint('Progress: ${(totalMinutesWorked / expectedMinutes * 100).toStringAsFixed(1)}%');
      debugPrint('Work Days Completed: $actualWorkDays');
      debugPrint('Off Days Taken: $actualOffDays');
      debugPrint('Total Days Off: ${totalOffDays + totalNonWorkDays}');
      
      // Today's Progress
      debugPrint('\n📅 Today\'s Progress:');
      debugPrint('----------------------');
      final todayEntries = entries.where((e) => 
        e.date.year == now.year && 
        e.date.month == now.month && 
        e.date.day == now.day
      ).toList();
      
      final todayMinutes = todayEntries.fold<int>(0, (sum, e) => sum + e.duration);
      final todayExpectedMinutes = settings.dailyTargetHours * 60;
      final todayOvertime = todayMinutes > todayExpectedMinutes ? todayMinutes - todayExpectedMinutes : 0;
      
      debugPrint('Entries Today: ${todayEntries.length}');
      debugPrint('Minutes Worked: $todayMinutes');
      debugPrint('Expected Minutes: $todayExpectedMinutes');
      debugPrint('Overtime Minutes: $todayOvertime');
      
      // Last Month Stats
      debugPrint('\n📅 Last Month Stats:');
      debugPrint('----------------------');
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      final lastMonthEntries = entries.where((e) => 
        e.date.isAfter(lastMonthStart.subtract(const Duration(days: 1))) && 
        e.date.isBefore(lastMonthEnd.add(const Duration(days: 1)))
      ).toList();
      
      final lastMonthMinutes = lastMonthEntries.fold<int>(0, (sum, e) => sum + e.duration);
      final lastMonthExpectedMinutes = HiveDb.getLastMonthExpectedMinutes();
      final lastMonthOvertime = lastMonthMinutes - lastMonthExpectedMinutes;
      
      debugPrint('Last Month Start: $lastMonthStart');
      debugPrint('Last Month End: $lastMonthEnd');
      debugPrint('Entries Last Month: ${lastMonthEntries.length}');
      debugPrint('Minutes Worked: $lastMonthMinutes');
      debugPrint('Expected Minutes: $lastMonthExpectedMinutes');
      debugPrint('Overtime Minutes: $lastMonthOvertime');
      
      debugPrint('\n==========================================\n');
      
      // Show snackbar with success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Summary debug information printed to console'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error printing summary debug info: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
