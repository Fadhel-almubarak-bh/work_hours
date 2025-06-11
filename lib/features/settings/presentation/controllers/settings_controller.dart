import 'package:flutter/material.dart';
import '../../../../data/repositories/work_hours_repository.dart';
import '../../../../data/models/settings.dart';
import '../../../../core/theme/theme_provider.dart';

class SettingsController extends ChangeNotifier {
  final WorkHoursRepository _repository;
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
      
      final settings = await _repository.getSettings();
      if (settings == null) {
        throw Exception('Settings not found');
      }

      final entries = await _repository.getAllWorkEntries();
      
      debugPrint('\n📊 [SUMMARY DEBUG INFO]');
      debugPrint('==========================================');
      
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
      
      final monthMinutes = monthEntries.fold<int>(0, (sum, e) => sum + e.duration);
      final monthExpectedMinutes = settings.dailyTargetHours * 60 * settings.workDays.where((d) => d).length * 4; // Approximate
      final monthOvertime = monthMinutes > monthExpectedMinutes ? monthMinutes - monthExpectedMinutes : 0;
      
      debugPrint('Month Start: $monthStart');
      debugPrint('Entries This Month: ${monthEntries.length}');
      debugPrint('Minutes Worked: $monthMinutes');
      debugPrint('Expected Minutes: $monthExpectedMinutes');
      debugPrint('Overtime Minutes: $monthOvertime');
      
      // Work Days Analysis
      debugPrint('\n📅 Work Days Analysis:');
      debugPrint('----------------------');
      final workDays = settings.workDays;
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var i = 0; i < 7; i++) {
        final dayEntries = entries.where((e) => e.date.weekday == i + 1).length;
        debugPrint('${days[i]}: ${workDays[i] ? '✓' : '✗'} (Entries: $dayEntries)');
      }
      
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

  Future<void> printWidgetDebugInfo(BuildContext context) async {
    try {
      final debugInfo = StringBuffer();
      debugInfo.writeln('=== Home Widget Debug Information ===');
      
      // Get today's entry
      final today = DateTime.now();
      final entry = await _repository.getDayEntry(today);
      
      debugInfo.writeln('\nToday\'s Entry:');
      if (entry != null) {
        debugInfo.writeln('Clock In: ${entry['in']}');
        debugInfo.writeln('Clock Out: ${entry['out']}');
        debugInfo.writeln('Duration: ${entry['duration']} minutes');
        debugInfo.writeln('Is Off Day: ${entry['offDay']}');
        debugInfo.writeln('Description: ${entry['description']}');
      } else {
        debugInfo.writeln('No entry found for today');
      }
      
      // Get widget data
      debugInfo.writeln('\nWidget Data:');
      final isClockedIn = await _repository.isClockedIn();
      final currentDuration = await _repository.getCurrentDuration();
      
      debugInfo.writeln('Is Clocked In: $isClockedIn');
      debugInfo.writeln('Current Duration: ${currentDuration.inMinutes} minutes');
      
      // Get overtime information
      final monthlyOvertime = await _repository.getMonthlyOvertime();
      final lastMonthOvertime = await _repository.getLastMonthOvertime();
      
      debugInfo.writeln('\nOvertime Information:');
      debugInfo.writeln('Current Month Overtime: $monthlyOvertime minutes');
      debugInfo.writeln('Last Month Overtime: $lastMonthOvertime minutes');
      
      // Get work days information
      final settings = await _repository.getSettings();
      final workDays = settings?.workDays ?? [true, true, true, true, true, false, false];
      
      debugInfo.writeln('\nWork Days Configuration:');
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      for (var i = 0; i < days.length; i++) {
        debugInfo.writeln('${days[i]}: ${workDays[i] ? 'Work Day' : 'Off Day'}');
      }
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Widget Debug Information'),
            content: SingleChildScrollView(
              child: Text(debugInfo.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  await _repository.updateWidget();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Widget updated')),
                    );
                  }
                },
                child: const Text('Update Widget'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error printing widget debug info: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing widget debug info: $e')),
        );
      }
    }
  }
} 