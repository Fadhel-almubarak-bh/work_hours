import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'config.dart';
import 'hive_db.dart';
import 'notification_service.dart';

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  DateTime? clockInTime;
  DateTime? clockOutTime;
  DateTime? selectedDateTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    if (mounted) {
      _getTodayStatus();
    }
  }

  Future<void> _exportDataToExcel() async {
    try {
      await HiveDb.exportDataToExcel();
      NotificationUtil.showSuccess(context, '✅ Excel Export successfully');
    } catch (e) {
      NotificationUtil.showError(context, '❌ Error exporting to Excel: $e');
    }
  }

  Future<void> _importDataFromExcel() async {
    try {
      await HiveDb.importDataFromExcel();
      NotificationUtil.showSuccess(context, '✅ Excel Import successful');
      setState(() {});
    } catch (e) {
      NotificationUtil.showError(context, '❌ Error importing Excel: $e');
    }
  }

  void _getTodayStatus() {
    if (!mounted) return;

    final data = HiveDb.getDayEntry(DateTime.now());

    if (data != null) {
      final clockInStr = data['in'];
      final clockOutStr = data['out'];

      final parsedClockIn =
          clockInStr != null ? DateTime.tryParse(clockInStr) : null;
      final parsedClockOut =
          clockOutStr != null ? DateTime.tryParse(clockOutStr) : null;

      if (mounted) {
        setState(() {
          if (parsedClockIn != null && parsedClockOut != null) {
            clockInTime = null;
            clockOutTime = null;
          } else {
            clockInTime = parsedClockIn;
            clockOutTime = parsedClockOut;
          }
        });
      }
    } else if (mounted) {
      setState(() {
        clockInTime = null;
        clockOutTime = null;
      });
    }
  }

  void _clockIn() async {
    final now = DateTime.now();
    final usedTime = selectedDateTime ?? now;

    await HiveDb.clockIn(usedTime);

    setState(() {
      clockInTime = usedTime;
      selectedDateTime = null;
    });

    NotificationUtil.showSuccess(context, 'Clocked in at ${DateFormat.Hm().format(usedTime)}');
  }

  void _clockOut() async {
    final now = DateTime.now();
    final usedTime = selectedDateTime ?? now;
    final clockInTimeLocal = clockInTime!;

    try {
      await HiveDb.clockOut(usedTime, clockInTimeLocal);

      setState(() {
        clockInTime = null;
        clockOutTime = null;
        selectedDateTime = null;
      });

      NotificationUtil.showInfo(context, 'Clocked out at ${DateFormat.Hm().format(usedTime)}');
    } catch (e) {
      String errorMessage = e.toString().contains('before clock in time')
          ? 'Error: Clock out time cannot be before clock in time'
          : 'Error clocking out: ${e.toString()}';
      NotificationUtil.showError(context, errorMessage);
    }
  }

  void _markOffDay() async {
    final now = DateTime.now();
    final usedTime = selectedDateTime ?? now;
    final dateKey = DateFormat('yyyy-MM-dd').format(usedTime);

    final existingEntry = HiveDb.getDayEntry(usedTime);
    if (existingEntry != null) {
      NotificationUtil.showWarning(context, 'This day is already marked.');
      return;
    }

    // Show dialog to select off day type
    final description = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Off Day Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.medical_services),
              title: const Text('Sick Leave'),
              onTap: () => Navigator.pop(context, 'Sick Leave'),
            ),
            ListTile(
              leading: const Icon(Icons.celebration),
              title: const Text('Public Holiday'),
              onTap: () => Navigator.pop(context, 'Public Holiday'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy),
              title: const Text('Annual Leave'),
              onTap: () => Navigator.pop(context, 'Annual Leave'),
            ),
          ],
        ),
      ),
    );

    if (description != null && mounted) {
      await HiveDb.markOffDay(usedTime, description: description);

      NotificationUtil.showInfo(context, '$description marked with 8 hours for $dateKey');

      setState(() {
        selectedDateTime = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Hours Tracker'),
        backgroundColor: colorScheme.primary,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      // Set SnackBar position to top for the entire Scaffold
      body: Builder(
        builder: (context) {
          return ValueListenableBuilder(
            valueListenable: HiveDb.getWorkHoursListenable(),
            builder: (context, Box workHours, _) {
              // Instead of calling setState here, we'll use the data directly
              final data = HiveDb.getDayEntry(DateTime.now());
              final clockInStr = data?['in'];
              final clockOutStr = data?['out'];
              
              final parsedClockIn = clockInStr != null ? DateTime.tryParse(clockInStr) : null;
              final parsedClockOut = clockOutStr != null ? DateTime.tryParse(clockOutStr) : null;
              
              // Get current time for display
              final now = DateTime.now();
              final currentTimeString = DateFormat('HH:mm').format(now);
              final currentDateString = DateFormat('yyyy-MM-dd').format(now);
              
              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [

                    // Enhanced Time Selection Card
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time, color: colorScheme.primary, size: 32),
                                const SizedBox(width: 16),
                                Text(
                                  'Time',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Current time display
                            Center(
                              child: InkWell(
                                onTap: () async {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: selectedDateTime != null 
                                        ? TimeOfDay.fromDateTime(selectedDateTime!)
                                        : TimeOfDay.now(),
                                  );
                                  
                                  if (pickedTime == null) return;
                                  
                                  setState(() {
                                    if (selectedDateTime == null) {
                                      // If no date was selected, use today with the selected time
                                      final now = DateTime.now();
                                      selectedDateTime = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                    } else {
                                      // Keep the selected date but update the time
                                      selectedDateTime = DateTime(
                                        selectedDateTime!.year,
                                        selectedDateTime!.month,
                                        selectedDateTime!.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        selectedDateTime == null ? currentTimeString : DateFormat('HH:mm').format(selectedDateTime!),
                                        style: theme.textTheme.displayLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.edit, color: colorScheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Date selection
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Date:',
                                  style: theme.textTheme.titleMedium,
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDateTime ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    
                                    if (pickedDate == null) return;
                                    
                                    final pickedTime = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? DateTime.now()),
                                    );
                                    
                                    if (pickedTime == null) return;
                                    
                                    setState(() {
                                      selectedDateTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                    });
                                  },
                                  icon: Icon(Icons.edit, color: colorScheme.primary),
                                  label: Text(
                                    selectedDateTime == null ? currentDateString : DateFormat('yyyy-MM-dd').format(selectedDateTime!),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                            // Reset button
                            if (selectedDateTime != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedDateTime = null;
                                    });
                                  },
                                  child: const Text('Reset to current time'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (parsedClockIn == null || (parsedClockIn != null && parsedClockOut != null)) ? _clockIn : null,
                              icon: const Icon(Icons.login),
                              label: const Text('Clock In'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.clockIn,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (parsedClockIn != null && parsedClockOut == null) ? _clockOut : null,
                              icon: const Icon(Icons.logout),
                              label: const Text('Clock Out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.clockOut,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Off Day Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: _markOffDay,
                        icon: const Icon(
                          Icons.event_busy,
                          color: Colors.white,
                        ),
                        label: const Text('Mark Off Day'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.offDay,
                          foregroundColor: Colors.white, // Make sure text is readable
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 0),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 50,
                    ),
                    // Export and Import Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _exportDataToExcel,
                              icon: const Icon(Icons.save_alt, color: Colors.white),
                              label: const Text('Export'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.export,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _importDataFromExcel,
                              icon: const Icon(Icons.upload_file, color: Colors.white),
                              label: const Text('Import'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.import,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
