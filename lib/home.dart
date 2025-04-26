import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
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

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Excel Export successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error exporting to Excel: $e')),
      );
    }
  }

  Future<void> _importDataFromExcel() async {
    try {
      await HiveDb.importDataFromExcel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Excel Import successful')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error importing Excel: $e')),
      );
    }
  }


  void _getTodayStatus() {
    if (!mounted) return;

    final data = HiveDb.getDayEntry(DateTime.now());

    if (data != null) {
      final clockInStr = data['in'];
      final clockOutStr = data['out'];

      final parsedClockIn = clockInStr != null
          ? DateTime.tryParse(clockInStr)
          : null;
      final parsedClockOut = clockOutStr != null ? DateTime.tryParse(
          clockOutStr) : null;

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

  Future<void> _pickDateTime() async {
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
  }

  void _clockIn() async {
    final now = DateTime.now();
    final usedTime = selectedDateTime ?? now;

    await HiveDb.clockIn(usedTime);

    setState(() {
      clockInTime = usedTime;
      selectedDateTime = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Clocked in at ${DateFormat.Hm().format(usedTime)}'),
        backgroundColor: Colors.green,
      ),
    );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Clocked out at ${DateFormat.Hm().format(usedTime)}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains('before clock in time')
              ? 'Error: Clock out time cannot be before clock in time'
              : 'Error clocking out: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _markOffDay() async {
    final now = DateTime.now();
    final usedTime = selectedDateTime ?? now;
    final dateKey = DateFormat('yyyy-MM-dd').format(usedTime);

    final existingEntry = HiveDb.getDayEntry(usedTime);
    if (existingEntry != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This day is already marked.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await HiveDb.markOffDay(usedTime);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Off day marked with 8 hours for $dateKey'),
        backgroundColor: Colors.blue,
      ),
    );

    setState(() {
      selectedDateTime = null;
    });
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
      body: SafeArea(
        child: Column(
          children: [
            // Status Card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Today\'s Status',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (clockInTime != null)
                      Text(
                        'Clocked in at: ${DateFormat.Hm().format(
                            clockInTime!)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    if (clockOutTime != null)
                      Text(
                        'Clocked out at: ${DateFormat.Hm().format(
                            clockOutTime!)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),

            // Time Selection Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: Icon(Icons.access_time, color: colorScheme.primary),
                title: Text(
                  selectedDateTime == null
                      ? 'Current Time'
                      : DateFormat('yyyy-MM-dd HH:mm').format(
                      selectedDateTime!),
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: Icon(Icons.edit, color: colorScheme.primary),
                onTap: _pickDateTime,
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
                      onPressed: clockInTime == null ? _clockIn : null,
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
                      onPressed: (clockInTime != null && clockOutTime == null)
                          ? _clockOut
                          : null,
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
                icon: const Icon(Icons.event_busy, color: Colors.white,),
                label: const Text('Mark Off Day'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.offDay,
                  foregroundColor: Colors.white, // Make sure text is readable
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ),
            SizedBox(height: 50,),
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
                        backgroundColor: Colors.teal,
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
                        backgroundColor: Colors.deepOrange,
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
      ),
    );
  }
}