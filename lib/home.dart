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

  void _getTodayStatus() {
    if (!mounted) return;
    
    final data = HiveDb.getDayEntry(DateTime.now());

    if (data != null) {
      final clockInStr = data['in'];
      final clockOutStr = data['out'];

      final parsedClockIn = clockInStr != null ? DateTime.tryParse(clockInStr) : null;
      final parsedClockOut = clockOutStr != null ? DateTime.tryParse(clockOutStr) : null;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Hours Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getTodayStatus,
            tooltip: 'Refresh Status',
          ),
        ],
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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (clockInTime != null)
                      Text(
                        'Clocked in at: ${DateFormat.Hm().format(clockInTime!)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    if (clockOutTime != null)
                      Text(
                        'Clocked out at: ${DateFormat.Hm().format(clockOutTime!)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
              ),
            ),

            // Time Selection Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  selectedDateTime == null
                      ? 'Current Time'
                      : DateFormat('yyyy-MM-dd HH:mm').format(selectedDateTime!),
                ),
                trailing: const Icon(Icons.edit),
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
                      onPressed: (clockInTime != null && clockOutTime == null) ? _clockOut : null,
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
                icon: const Icon(Icons.event_busy),
                label: const Text('Mark Off Day'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.offDay,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
