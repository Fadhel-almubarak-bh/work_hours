import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'hive_db.dart';
import 'notification_service.dart';
import 'data_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _dailyTargetHours = 8;
  List<bool> _workDays = List.filled(7, false);
  TimeOfDay _clockInReminderTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _clockOutReminderTime = const TimeOfDay(hour: 17, minute: 0);
  TextEditingController? _salaryController;

  @override
  void initState() {
    super.initState();
    _salaryController = TextEditingController(
      text: HiveDb.getMonthlySalary() > 0 ? HiveDb.getMonthlySalary().toString() : ''
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _salaryController?.dispose();
    super.dispose();
  }

  void _loadSettings() {
    setState(() {
      _dailyTargetHours = HiveDb.getDailyTargetHours();
      _workDays = HiveDb.getWorkDays();
      _clockInReminderTime = HiveDb.getClockInReminderTime();
      _clockOutReminderTime = HiveDb.getClockOutReminderTime();
      _salaryController?.text = HiveDb.getMonthlySalary() > 0 ? HiveDb.getMonthlySalary().toString() : '';
    });
  }

  Future<void> _selectTime(BuildContext context, bool isClockIn) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isClockIn ? _clockInReminderTime : _clockOutReminderTime,
    );
    if (picked != null) {
      setState(() {
        if (isClockIn) {
          _clockInReminderTime = picked;
          HiveDb.setClockInReminderTime(picked);
        } else {
          _clockOutReminderTime = picked;
          HiveDb.setClockOutReminderTime(picked);
        }
      });
      await NotificationService.scheduleNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveDb.getSettingsListenable(),
        builder: (context, Box settings, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Bottom 100
            children: [
              // Dark Mode Switch
              Card(
                child: SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Enable dark theme'),
                  value: HiveDb.getIsDarkMode(),
                  onChanged: (value) => HiveDb.setIsDarkMode(value),
                ),
              ),
              const SizedBox(height: 16),

              // Work Days Selection
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, 
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Work Days',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Select the days that you normally work. This affects overtime calculations.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder(
                      valueListenable: HiveDb.getSettingsListenable(),
                      builder: (context, Box settings, _) {
                        final workDays = HiveDb.getWorkDays();
                        return Column(
                          children: [
                            for (var i = 0; i < 7; i++)
                              CheckboxListTile(
                                title: Text(_getDayName(i), 
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: workDays[i] ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: workDays[i] 
                                  ? Text('Set as a work day', 
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary))
                                  : null,
                                activeColor: Theme.of(context).colorScheme.primary,
                                checkColor: Theme.of(context).colorScheme.onPrimary,
                                value: workDays[i],
                                onChanged: (value) {
                                  if (value != null) {
                                    // Show confirmation dialog if unchecking a work day
                                    if (workDays[i] && value == false) {
                                      _confirmWorkDayChange(context, i, value);
                                    } else {
                                      final newWorkDays = List<bool>.from(workDays);
                                      newWorkDays[i] = value;
                                      debugPrint('🔧 [SETTINGS] Changing work day ${_getDayName(i)} to $value');
                                      debugPrint('🔧 [SETTINGS] New work days array: $newWorkDays');
                                      HiveDb.setWorkDays(newWorkDays);
                                    }
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Daily Target Hours
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, 
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Daily Target Hours',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Set your standard working hours per day. This affects overtime calculations.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      
                      // Simplified hour selector with just +/- buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Decrement button
                            IconButton(
                              onPressed: () {
                                final currentHours = HiveDb.getDailyTargetHours();
                                if (currentHours > 1) {
                                  final newHours = currentHours - 1;
                                  HiveDb.setDailyTargetHours(newHours);
                                  setState(() {
                                    _dailyTargetHours = newHours;
                                  });
                                }
                              },
                              icon: Icon(
                                Icons.remove_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 36,
                              ),
                            ),
                            
                            // Current value display
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${HiveDb.getDailyTargetHours()}',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Increment button
                            IconButton(
                              onPressed: () {
                                final currentHours = HiveDb.getDailyTargetHours();
                                if (currentHours < 24) {
                                  final newHours = currentHours + 1;
                                  HiveDb.setDailyTargetHours(newHours);
                                  setState(() {
                                    _dailyTargetHours = newHours;
                                  });
                                }
                              },
                              icon: Icon(
                                Icons.add_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Monthly Salary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_money, 
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Monthly Salary',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Set your monthly salary to calculate hourly rates and overtime pay.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      
                      ValueListenableBuilder(
                        valueListenable: HiveDb.getSettingsListenable(),
                        builder: (context, Box settings, _) {
                          return TextField(
                            controller: _salaryController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Monthly Salary',
                              hintText: 'Enter your monthly salary',
                              prefixIcon: const Icon(Icons.attach_money),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            onChanged: (value) {
                              if (value.isEmpty) {
                                HiveDb.setMonthlySalary(0.0);
                                return;
                              }
                              
                              final salary = double.tryParse(value);
                              if (salary != null) {
                                HiveDb.setMonthlySalary(salary);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reminder Times
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminder Times',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder(
                        valueListenable: HiveDb.getSettingsListenable(),
                        builder: (context, Box settings, _) {
                          final clockInEnabled = HiveDb.getClockInReminderEnabled();
                          final clockOutEnabled = HiveDb.getClockOutReminderEnabled();
                          
                          return Column(
                            children: [
                              // Clock In Reminder Switch
                              SwitchListTile(
                                title: const Text('Clock In Reminders'),
                                subtitle: Text(
                                  clockInEnabled ? 'Enabled' : 'Disabled',
                                ),
                                value: clockInEnabled,
                                onChanged: (value) async {
                                  await HiveDb.setClockInReminderEnabled(value);
                                  await NotificationService.scheduleNotifications();
                                },
                              ),
                              ListTile(
                                title: const Text('Clock In Time'),
                                subtitle: Text(
                                  'Set to ${HiveDb.getClockInReminderTime().format(context)}',
                                ),
                                trailing: const Icon(Icons.access_time),
                                enabled: clockInEnabled,
                                onTap: clockInEnabled ? () async {
                                  await _selectTime(context, true);
                                } : null,
                              ),
                              const Divider(),
                              // Clock Out Reminder Switch
                              SwitchListTile(
                                title: const Text('Clock Out Reminders'),
                                subtitle: Text(
                                  clockOutEnabled ? 'Enabled' : 'Disabled',
                                ),
                                value: clockOutEnabled, 
                                onChanged: (value) async {
                                  await HiveDb.setClockOutReminderEnabled(value);
                                  await NotificationService.scheduleNotifications();
                                },
                              ),
                              ListTile(
                                title: const Text('Clock Out Time'),
                                subtitle: Text(
                                  'Set to ${HiveDb.getClockOutReminderTime().format(context)}',
                                ),
                                trailing: const Icon(Icons.access_time),
                                enabled: clockOutEnabled,
                                onTap: clockOutEnabled ? () async {
                                  await _selectTime(context, false);
                                } : null,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Data Management Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.data_array, 
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Data Management',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Export your work hours data to Excel or import from a backup.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => DataManager.exportDataToExcel(context),
                              icon: const Icon(Icons.save_alt, color: Colors.white),
                              label: const Text('Export'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => DataManager.importDataFromExcel(context),
                              icon: const Icon(Icons.upload_file, color: Colors.white),
                              label: const Text('Import'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Debug Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bug_report, 
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Debug Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'View detailed debug information about the app\'s state and data.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _printDebugInfo,
                        icon: const Icon(Icons.bug_report, color: Colors.white),
                        label: const Text('Show Debug Info'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  void _printDebugInfo() {
    debugPrint('\n🔍 [DEBUG] Testing All Pages Values');
    debugPrint('==========================================');
    
    // Test Summary Page Values
    debugPrint('\n📊 [SUMMARY PAGE] Testing Values:');
    debugPrint('----------------------');
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: (now.weekday + 1) % 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);

    // Test work hours data
    final workHoursBox = Hive.box('work_hours');
    final allEntries = workHoursBox.toMap();
    debugPrint('Total Entries: ${allEntries.length}');
    
    // Test today's entry
    final todayEntry = HiveDb.getDayEntry(now);
    debugPrint('\nToday\'s Entry:');
    debugPrint('Date: ${DateFormat('yyyy-MM-dd').format(now)}');
    debugPrint('Data: $todayEntry');

    // Test weekly stats
    final weekStats = HiveDb.getStatsForRange(weekStart, now.subtract(const Duration(days: 1)));
    debugPrint('\nWeekly Stats:');
    debugPrint('Total Minutes: ${weekStats['totalMinutes']}');
    debugPrint('Work Days: ${weekStats['workDays']}');
    debugPrint('Off Days: ${weekStats['offDays']}');

    // Test monthly stats
    final monthStats = HiveDb.getStatsForRange(monthStart, now.subtract(const Duration(days: 1)));
    debugPrint('\nMonthly Stats:');
    debugPrint('Total Minutes: ${monthStats['totalMinutes']}');
    debugPrint('Work Days: ${monthStats['workDays']}');
    debugPrint('Off Days: ${monthStats['offDays']}');

    // Test overtime calculations
    final overtimeMinutes = HiveDb.getMonthlyOvertime();
    final lastMonthOvertimeMinutes = HiveDb.getLastMonthOvertime();
    debugPrint('\nOvertime:');
    debugPrint('Current Month: $overtimeMinutes minutes');
    debugPrint('Last Month: $lastMonthOvertimeMinutes minutes');

    // Test expected minutes
    final currentMonthExpectedMinutes = HiveDb.getCurrentMonthExpectedMinutes();
    final lastMonthExpectedMinutes = HiveDb.getLastMonthExpectedMinutes();
    debugPrint('\nExpected Minutes:');
    debugPrint('Current Month: $currentMonthExpectedMinutes');
    debugPrint('Last Month: $lastMonthExpectedMinutes');

    // Test Salary Page Values
    debugPrint('\n💰 [SALARY PAGE] Testing Values:');
    debugPrint('----------------------');
    final monthlySalary = HiveDb.getMonthlySalary();
    final dailyTargetHours = HiveDb.getDailyTargetHours();
    final workDays = HiveDb.getWorkDays();
    
    debugPrint('Monthly Salary: $monthlySalary');
    debugPrint('Daily Target Hours: $dailyTargetHours');
    debugPrint('Work Days: $workDays');

    // Calculate and test salary-related values
    if (currentMonthExpectedMinutes > 0 && monthlySalary > 0) {
      // Get work days for the current month
      final workDays = HiveDb.getWorkDays();
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      
      // Count actual work days in the month
      int actualWorkDaysInMonth = 0;
      for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        if (workDays[day.weekday - 1]) {
          actualWorkDaysInMonth++;
        }
      }
      
      // Calculate daily rate based on actual work days
      final dailyRate = monthlySalary / actualWorkDaysInMonth;
      final hourlyRate = dailyRate / dailyTargetHours;
      
      debugPrint('\nCalculated Rates:');
      debugPrint('Actual Work Days in Month: $actualWorkDaysInMonth');
      debugPrint('Daily Rate: $dailyRate');
      debugPrint('Hourly Rate: $hourlyRate');

      // Test overtime pay calculation
      if (overtimeMinutes > 0) {
        final overtimePay = (overtimeMinutes / 60) * hourlyRate * 1.5;
        debugPrint('Overtime Pay: $overtimePay');
      }
    }

    // Test Settings Page Values
    debugPrint('\n⚙️ [SETTINGS PAGE] Testing Values:');
    debugPrint('----------------------');
    final isDarkMode = HiveDb.getIsDarkMode();
    final clockInReminderTime = HiveDb.getClockInReminderTime();
    final clockOutReminderTime = HiveDb.getClockOutReminderTime();
    final clockInReminderEnabled = HiveDb.getClockInReminderEnabled();
    final clockOutReminderEnabled = HiveDb.getClockOutReminderEnabled();

    debugPrint('Dark Mode: $isDarkMode');
    debugPrint('Clock In Reminder: ${clockInReminderEnabled ? 'Enabled' : 'Disabled'} at ${clockInReminderTime.format(context)}');
    debugPrint('Clock Out Reminder: ${clockOutReminderEnabled ? 'Enabled' : 'Disabled'} at ${clockOutReminderTime.format(context)}');

    // Test Hive DB Functions
    debugPrint('\n🗄️ [HIVE DB] Testing Functions:');
    debugPrint('----------------------');
    debugPrint('Daily Target Minutes: ${HiveDb.getDailyTargetMinutes()}');
    debugPrint('Daily Target Hours: ${HiveDb.getDailyTargetHours()}');
    debugPrint('Work Days: ${HiveDb.getWorkDays()}');
    debugPrint('Monthly Salary: ${HiveDb.getMonthlySalary()}');
    
    // Test if currently clocked in
    final isClockedIn = todayEntry != null && 
                       todayEntry['in'] != null && 
                       todayEntry['out'] == null;
    debugPrint('\nCurrent Status:');
    debugPrint('Clocked In: $isClockedIn');
    if (isClockedIn) {
      final clockInTime = DateTime.parse(todayEntry['in']);
      final currentDuration = now.difference(clockInTime).inMinutes;
      debugPrint('Current Duration: $currentDuration minutes');
    }
  }

  String _getDayName(int index) {
    switch (index) {
      case 0:
        return 'Monday';
      case 1:
        return 'Tuesday';
      case 2:
        return 'Wednesday';
      case 3:
        return 'Thursday';
      case 4:
        return 'Friday';
      case 5:
        return 'Saturday';
      case 6:
        return 'Sunday';
      default:
        return '';
    }
  }

  void _confirmWorkDayChange(BuildContext context, int index, bool value) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Work Day Change'),
          content: Text(
            'Are you sure you want to remove ${_getDayName(index)} from your work days?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                final newWorkDays = List<bool>.from(_workDays);
                newWorkDays[index] = value;
                debugPrint('🔧 [SETTINGS] Changing work day ${_getDayName(index)} to $value');
                debugPrint('🔧 [SETTINGS] New work days array: $newWorkDays');
                HiveDb.setWorkDays(newWorkDays);
                Navigator.of(context).pop();
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );
  }
}
