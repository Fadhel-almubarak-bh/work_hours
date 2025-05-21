import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_db.dart';
import 'notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _dailyTargetHours = HiveDb.getDailyTargetHours();
      _workDays = HiveDb.getWorkDays();
      _clockInReminderTime = HiveDb.getClockInReminderTime();
      _clockOutReminderTime = HiveDb.getClockOutReminderTime();
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
              const SizedBox(
                height: 20,
              )
            ],
          );
        },
      ),
    );
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
