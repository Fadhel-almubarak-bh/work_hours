import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../data/repositories/work_hours_repository.dart';
import '../../../../data/models/work_entry.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../home_controller.dart';
import '../../../../core/theme/theme.dart';
import '../../../../data/local/hive_db.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';

class WorkHoursScreen extends StatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  State<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends State<WorkHoursScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime? clockInTime;
  DateTime? clockOutTime;
  DateTime? selectedDate;
  String currentTimeString = '';
  String currentDateString = '';
  late Timer _clockTimer;
  late HomeController _controller;

  // Add time editing variables
  bool _isEditingTime = false;
  int _editHour = DateTime.now().hour;
  int _editMinute = DateTime.now().minute;

  // Custom time selection
  bool isCustomTimeSelected = false;
  TimeOfDay? customTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = context.read<HomeController>();
    _updateTime();
    // Start a timer that updates every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    _getTodayStatus();

    // Add lifecycle listener to refresh data when app comes to foreground
    SystemChannels.lifecycle.setMessageHandler((msg) async {
      if (msg == AppLifecycleState.resumed.toString()) {
        debugPrint('[home_screen] 🔄 App resumed, refreshing data');
        
        // Force refresh the Hive box to get fresh data
        await HiveDb.refreshHiveBox();
        
        _getTodayStatus();
      }
      return null;
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        final now = DateTime.now();

        // Only update to current time if we're not using a custom time
        if (!isCustomTimeSelected) {
          currentTimeString = DateFormat('HH:mm:ss').format(now);
          currentDateString = DateFormat('yyyy-MM-dd').format(now);
        } else if (customTime != null) {
          // If custom time is selected, keep showing it with seconds
          final customDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            customTime!.hour,
            customTime!.minute,
            now.second, // Keep current seconds for live update effect
          );
          currentTimeString = "${DateFormat('HH:mm').format(customDateTime)}:${now.second.toString().padLeft(2, '0')} (custom)";
          currentDateString = DateFormat('yyyy-MM-dd').format(now);
        }
      });
    }
  }

  void _getTodayStatus() {
    if (!mounted) return;

    final data = HiveDb.getDayEntry(DateTime.now());
    debugPrint('[home_screen] 🔍 Debug: Reading today status - $data');

    if (data != null) {
      final clockInStr = data['in'];
      final clockOutStr = data['out'];
      debugPrint('[home_screen] 🔍 Debug: Clock in string - $clockInStr');
      debugPrint('[home_screen] 🔍 Debug: Clock out string - $clockOutStr');

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
        debugPrint(
            '[home_screen] 🔍 Debug: Set clockInTime to $clockInTime, clockOutTime to $clockOutTime');
      }
    } else if (mounted) {
      setState(() {
        clockInTime = null;
        clockOutTime = null;
      });
      debugPrint(
          '[home_screen] 🔍 Debug: No data found, set both times to null');
    }
  }

  // Method to manually refresh data (can be called from parent or when needed)
  void refreshData() {
    debugPrint('[home_screen] 🔄 Manual refresh requested');
    _getTodayStatus();
  }

  // Method to update widget display
  Future<void> updateWidgetDisplay() async {
    try {
      debugPrint('[home_screen] 🔄 Updating widget display');
      await HiveDb.syncTodayEntry();
      debugPrint('[home_screen] ✅ Widget display updated');
    } catch (e) {
      debugPrint('[home_screen] ❌ Error updating widget display: $e');
    }
  }

  Future<TimeOfDay?> _showCustomTimePicker(BuildContext context) async {
    debugPrint('[time_picker] Opening time picker');
    // Use current custom time as initial time if available, otherwise use current time
    final initialTime = customTime ?? TimeOfDay.now();
    debugPrint('[time_picker] Initial time: $initialTime');
    final result = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    debugPrint('[time_picker] Time picker result: $result');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ValueListenableBuilder(
      valueListenable: HiveDb.getWorkHoursListenable(),
      builder: (context, Box workHours, _) {
        // Get the current status
        final data = HiveDb.getDayEntry(DateTime.now());
        final clockInStr = data?['in'];
        final clockOutStr = data?['out'];

        final parsedClockIn =
            clockInStr != null ? DateTime.tryParse(clockInStr) : null;
        final parsedClockOut =
            clockOutStr != null ? DateTime.tryParse(clockOutStr) : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Work Hours'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  debugPrint('[home_screen] 🔄 Manual refresh button pressed');
                  await HiveDb.refreshHiveBox();
                  _getTodayStatus();
                },
                tooltip: 'Refresh data',
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                debugPrint('[home_screen] 🔄 Pull-to-refresh triggered');
                _getTodayStatus();
              },
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
                              Icon(Icons.access_time,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 32),
                              const SizedBox(width: 16),
                              Text(
                                'Time',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Current time display - Now updates in real-time with seconds
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isCustomTimeSelected
                                        ? Colors.orange.withOpacity(0.2)
                                        : Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isCustomTimeSelected
                                        ? Border.all(
                                            color: Colors.orange.withOpacity(0.5),
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          currentTimeString,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        tooltip: 'Select custom time',
                                        constraints: BoxConstraints.tightFor(
                                            width: 36, height: 36),
                                        padding: EdgeInsets.zero,
                                        onPressed: () async {
                                          debugPrint('[time_button] Time selection button pressed');
                                          final pickedTime =
                                              await _showCustomTimePicker(
                                                  context);
                                          debugPrint('[time_button] Picked time: $pickedTime');
                                          if (pickedTime != null) {
                                            debugPrint('[time_button] Processing selected time: ${pickedTime.hour}:${pickedTime.minute}');
                                            setState(() {
                                              isCustomTimeSelected = true;
                                              customTime = pickedTime;

                                              // Create a DateTime with the selected time
                                              final now = DateTime.now();
                                              final selectedTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                pickedTime.hour,
                                                pickedTime.minute,
                                              );

                                              // Update the displayed time
                                              currentTimeString =
                                                  "${DateFormat('HH:mm').format(selectedTime)}:00 (custom)";

                                              // Store for later use
                                              selectedDate = selectedTime;
                                            });
                                            debugPrint('[time_button] Updated currentTimeString to: $currentTimeString');
                                          } else {
                                            debugPrint('[time_button] No time selected (user cancelled)');
                                          }
                                        },
                                      ),
                                      if (isCustomTimeSelected)
                                        IconButton(
                                          icon: const Icon(Icons.restore,
                                              size: 20),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          tooltip: 'Reset to current time',
                                          constraints: BoxConstraints.tightFor(
                                              width: 36, height: 36),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            setState(() {
                                              isCustomTimeSelected = false;
                                              customTime = null;
                                              selectedDate = null;

                                              // Reset to current time
                                              final now = DateTime.now();
                                              currentTimeString =
                                                  DateFormat('HH:mm:ss')
                                                      .format(now);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                if (isCustomTimeSelected) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Custom time selected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Date selection - Only select date, not time
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Date:',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: TextButton.icon(
                                        onPressed: () async {
                                          final pickedDate =
                                              await showDatePicker(
                                            context: context,
                                            initialDate:
                                                selectedDate ?? DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2100),
                                          );

                                          if (pickedDate == null) return;

                                          setState(() {
                                            // If we have a custom time, preserve it with the new date
                                            if (customTime != null) {
                                              selectedDate = DateTime(
                                                pickedDate.year,
                                                pickedDate.month,
                                                pickedDate.day,
                                                customTime!.hour,
                                                customTime!.minute,
                                              );

                                              // Update the displayed date and time
                                              currentDateString =
                                                  DateFormat('yyyy-MM-dd')
                                                      .format(selectedDate!);
                                              currentTimeString =
                                                  "${DateFormat('HH:mm').format(selectedDate!)}:00 (custom)";
                                            } else {
                                              // Just set the date
                                              selectedDate = pickedDate;
                                              currentDateString =
                                                  DateFormat('yyyy-MM-dd')
                                                      .format(selectedDate!);
                                            }
                                          });
                                        },
                                        icon: Icon(Icons.edit,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            size: 18),
                                        label: Text(
                                          selectedDate == null
                                              ? currentDateString
                                              : DateFormat('yyyy-MM-dd')
                                                  .format(selectedDate!),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (selectedDate != null)
                                      IconButton(
                                        icon: Icon(Icons.refresh,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            size: 18),
                                        tooltip: 'Reset to current date',
                                        onPressed: () {
                                          setState(() {
                                            selectedDate = null;
                                            isCustomTimeSelected = false;
                                            customTime = null;

                                            // Reset to current time display
                                            final now = DateTime.now();
                                            currentTimeString =
                                                DateFormat('HH:mm:ss')
                                                    .format(now);
                                            currentDateString =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(now);
                                          });
                                        },
                                        constraints:
                                            BoxConstraints.tightFor(width: 30),
                                        padding: EdgeInsets.zero,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Reset button
                          if (selectedDate != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    selectedDate = null;
                                    isCustomTimeSelected = false;
                                    customTime = null;

                                    // Reset to current time display
                                    final now = DateTime.now();
                                    currentTimeString =
                                        DateFormat('HH:mm:ss').format(now);
                                    currentDateString =
                                        DateFormat('yyyy-MM-dd').format(now);
                                  });
                                },
                                child: const Text('Reset to current date'),
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
                            onPressed: (parsedClockIn == null ||
                                    (parsedClockIn != null &&
                                        parsedClockOut != null))
                                ? _handleClockIn
                                : null,
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
                            onPressed: (parsedClockIn != null &&
                                    parsedClockOut == null)
                                ? _handleClockOut
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
                      icon: const Icon(
                        Icons.event_busy,
                        color: Colors.white,
                      ),
                      label: const Text('Mark Off Day'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.offDay,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleClockIn() async {
    try {
      debugPrint('[clockin] _handleClockIn called');
      debugPrint('[clockin] selectedDate: $selectedDate');
      debugPrint('[clockin] isCustomTimeSelected: $isCustomTimeSelected');
      debugPrint('[clockin] customTime: $customTime');
      
      // Get time to use (either current or custom selected)
      DateTime usedTime;

      if (selectedDate != null) {
        usedTime = selectedDate!;
        debugPrint('[clockin] Using selectedDate for clock in: $usedTime');
      } else if (isCustomTimeSelected && customTime != null) {
        final now = DateTime.now();
        usedTime = DateTime(
          now.year,
          now.month,
          now.day,
          customTime!.hour,
          customTime!.minute,
        );
        debugPrint('[clockin] Using custom time for clock in: $usedTime');
      } else {
        usedTime = DateTime.now();
        debugPrint('[clockin] Using current time for clock in: $usedTime');
      }

      await _controller.clockIn(usedTime);
      debugPrint('[clockin] _controller.clockIn completed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clocked in successfully')),
        );
        setState(() {
          selectedDate = null;
          isCustomTimeSelected = false;
          customTime = null;
          final now = DateTime.now();
          currentTimeString = DateFormat('HH:mm:ss').format(now);
          currentDateString = DateFormat('yyyy-MM-dd').format(now);
        });
      }
    } catch (e, stack) {
      debugPrint('[clockin] Error in _handleClockIn: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clocking in: $e')),
        );
      }
    }
  }

  Future<void> _handleClockOut() async {
    try {
      debugPrint('[clockout] _handleClockOut called');
      debugPrint('[clockout] selectedDate: $selectedDate');
      debugPrint('[clockout] isCustomTimeSelected: $isCustomTimeSelected');
      debugPrint('[clockout] customTime: $customTime');
      
      // Get time to use (either current or custom selected)
      DateTime usedTime;

      if (selectedDate != null) {
        usedTime = selectedDate!;
        debugPrint('[clockout] Using selectedDate for clock out: $usedTime');
      } else if (isCustomTimeSelected && customTime != null) {
        final now = DateTime.now();
        usedTime = DateTime(
          now.year,
          now.month,
          now.day,
          customTime!.hour,
          customTime!.minute,
        );
        debugPrint('[clockout] Using custom time for clock out: $usedTime');
      } else {
        usedTime = DateTime.now();
        debugPrint('[clockout] Using current time for clock out: $usedTime');
      }

      await _controller.clockOut(usedTime);
      debugPrint('[clockout] _controller.clockOut completed');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clocked out successfully')),
        );
        setState(() {
          selectedDate = null;
          isCustomTimeSelected = false;
          customTime = null;
          final now = DateTime.now();
          currentTimeString = DateFormat('HH:mm:ss').format(now);
          currentDateString = DateFormat('yyyy-MM-dd').format(now);
        });
      }
    } catch (e) {
      debugPrint('[clockout] Error in _handleClockOut: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clocking out: $e')),
        );
      }
    }
  }

  void _markOffDay() async {
    final controller = context.read<HomeController>();
    // Get time to use (either current or custom selected)
    DateTime usedTime;

    if (selectedDate != null) {
      // Use the selected date and time
      usedTime = selectedDate!;
      debugPrint('🕒 Using custom time for off day: $usedTime');
    } else if (isCustomTimeSelected && customTime != null) {
      // Use custom time with current date
      final now = DateTime.now();
      usedTime = DateTime(
        now.year,
        now.month,
        now.day,
        customTime!.hour,
        customTime!.minute,
      );
      debugPrint('🕒 Using custom time for off day: $usedTime');
    } else {
      // Use current time
      usedTime = DateTime.now();
      debugPrint('🕒 Using current time for off day: $usedTime');
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
      await controller.markOffDay(usedTime, description: description);

      setState(() {
        selectedDate = null;
        isCustomTimeSelected = false;
        customTime = null;

        // Reset displays to current time
        final now = DateTime.now();
        currentTimeString = DateFormat('HH:mm:ss').format(now);
        currentDateString = DateFormat('yyyy-MM-dd').format(now);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$description marked with 8 hours for ${DateFormat('yyyy-MM-dd').format(usedTime)}')),
        );
      }
    }
  }
}
