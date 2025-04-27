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
                      child: Text(
                        'Work Days',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: HiveDb.getSettingsListenable(),
                      builder: (context, Box settings, _) {
                        final workDays = HiveDb.getWorkDays();
                        return Column(
                          children: [
                            for (var i = 0; i < 7; i++)
                              CheckboxListTile(
                                title: Text(_getDayName(i)),
                                value: workDays[i],
                                onChanged: (value) {
                                  if (value != null) {
                                    final newWorkDays =
                                        List<bool>.from(workDays);
                                    newWorkDays[i] = value;
                                    HiveDb.setWorkDays(newWorkDays);
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
                      Text(
                        'Daily Target Hours',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _dailyTargetHours.toDouble(),
                        min: 0,
                        max: 24,
                        divisions: 48,
                        label: '$_dailyTargetHours hours',
                        onChanged: (value) {
                          setState(() {
                            _dailyTargetHours = value.round();
                          });
                          HiveDb.setDailyTargetHours(_dailyTargetHours);
                        },
                      ),
                      Text(
                        '$_dailyTargetHours hours per day',
                        style: Theme.of(context).textTheme.bodyLarge,
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
                          return Column(
                            children: [
                              ListTile(
                                title: const Text('Clock In Reminder'),
                                subtitle: Text(
                                  'Set to ${HiveDb.getClockInReminderTime().format(context)}',
                                ),
                                trailing: const Icon(Icons.access_time),
                                onTap: () async {
                                  await _selectTime(context, true);
                                },
                              ),
                              const Divider(),
                              ListTile(
                                title: const Text('Clock Out Reminder'),
                                subtitle: Text(
                                  'Set to ${HiveDb.getClockOutReminderTime().format(context)}',
                                ),
                                trailing: const Icon(Icons.access_time),
                                onTap: () async {
                                  await _selectTime(context, false);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Test Notification Button
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Notifications',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await NotificationService.showTestNotification();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Test notification sent!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.notifications),
                        label: const Text('Send Test Notification'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
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
}
