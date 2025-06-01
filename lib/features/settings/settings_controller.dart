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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.saveSettings(newSettings);
      _settings = newSettings;
    } catch (e) {
      _error = 'Failed to save settings: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
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
    final newSettings = _settings!.copyWith(currency: currency);
    await saveSettings(newSettings);
  }

  Future<void> updateInsuranceRate(double rate) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(insuranceRate: rate);
    await saveSettings(newSettings);
  }

  Future<void> updateOvertimeRate(double rate) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(overtimeRate: rate);
    await saveSettings(newSettings);
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
}
