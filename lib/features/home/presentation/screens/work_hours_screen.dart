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

class WorkHoursScreen extends StatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  State<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends State<WorkHoursScreen> with AutomaticKeepAliveClientMixin {
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
        }
      });
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

  Future<TimeOfDay?> _showCustomTimePicker(BuildContext context) async {
    return showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        final now = TimeOfDay.now();
        int hour = now.hour;
        int minute = now.minute;
        
        return StatefulBuilder(
          builder: (context, setState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isSmallScreen = screenWidth < 360;
            
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                  children: [
                      Text(
                        'Select Time',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      // Time display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                          style: isSmallScreen 
                            ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              )
                            : Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Hour and minute selectors
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Hour selector
                              Flexible(
                                child: Column(
                                  children: [
                                    const Text('Hour'),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          constraints: BoxConstraints.tightFor(
                                            width: isSmallScreen ? 32 : 40,
                                            height: isSmallScreen ? 32 : 40
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            setState(() {
                                              hour = (hour - 1 + 24) % 24;
                                            });
                                          },
                                        ),
                                        Text(
                                          hour.toString().padLeft(2, '0'),
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          constraints: BoxConstraints.tightFor(
                                            width: isSmallScreen ? 32 : 40,
                                            height: isSmallScreen ? 32 : 40
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            setState(() {
                                              hour = (hour + 1) % 24;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(width: isSmallScreen ? 8 : 16),
                              
                              // Minute selector
                              Flexible(
                                child: Column(
                                  children: [
                                    const Text('Minute'),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          constraints: BoxConstraints.tightFor(
                                            width: isSmallScreen ? 32 : 40,
                                            height: isSmallScreen ? 32 : 40
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            setState(() {
                                              minute = (minute - 1 + 60) % 60;
                                            });
                                          },
                                        ),
                                        Text(
                                          minute.toString().padLeft(2, '0'),
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          constraints: BoxConstraints.tightFor(
                                            width: isSmallScreen ? 32 : 40,
                                            height: isSmallScreen ? 32 : 40
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            setState(() {
                                              minute = (minute + 1) % 60;
                                            });
                                          },
                        ),
                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, TimeOfDay(hour: hour, minute: minute));
                            },
                            child: const Text('Set Time'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
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
        
        final parsedClockIn = clockInStr != null ? DateTime.tryParse(clockInStr) : null;
        final parsedClockOut = clockOutStr != null ? DateTime.tryParse(clockOutStr) : null;

        return Scaffold(
          body: SafeArea(
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
                            Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary, size: 32),
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        currentTimeString,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      color: Theme.of(context).colorScheme.primary,
                                      tooltip: 'Select custom time',
                                      constraints: BoxConstraints.tightFor(width: 36, height: 36),
                                      padding: EdgeInsets.zero,
                                      onPressed: () async {
                                        final pickedTime = await _showCustomTimePicker(context);
                                        if (pickedTime != null) {
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
                                            currentTimeString = "${DateFormat('HH:mm').format(selectedTime)}:00 (custom)";
                                            
                                            // Store for later use
                                            selectedDate = selectedTime;
                                          });
                                        }
                                      },
                                    ),
                                    if (isCustomTimeSelected)
                                      IconButton(
                                        icon: const Icon(Icons.restore, size: 20),
                                        color: Theme.of(context).colorScheme.primary,
                                        tooltip: 'Reset to current time',
                                        constraints: BoxConstraints.tightFor(width: 36, height: 36),
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          setState(() {
                                            isCustomTimeSelected = false;
                                            customTime = null;
                                            selectedDate = null;
                                            
                                            // Reset to current time
                                            final now = DateTime.now();
                                            currentTimeString = DateFormat('HH:mm:ss').format(now);
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
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
                                        final pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: selectedDate ?? DateTime.now(),
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
                                            currentDateString = DateFormat('yyyy-MM-dd').format(selectedDate!);
                                            currentTimeString = "${DateFormat('HH:mm').format(selectedDate!)}:00 (custom)";
                                          } else {
                                            // Just set the date
                                            selectedDate = pickedDate;
                                            currentDateString = DateFormat('yyyy-MM-dd').format(selectedDate!);
                                          }
                                        });
                                      },
                                      icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 18),
                                      label: Text(
                                        selectedDate == null ? currentDateString : DateFormat('yyyy-MM-dd').format(selectedDate!),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (selectedDate != null)
                                    IconButton(
                                      icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary, size: 18),
                                      tooltip: 'Reset to current date',
                                      onPressed: () {
                                        setState(() {
                                          selectedDate = null;
                                          isCustomTimeSelected = false;
                                          customTime = null;
                                          
                                          // Reset to current time display
                                          final now = DateTime.now();
                                          currentTimeString = DateFormat('HH:mm:ss').format(now);
                                          currentDateString = DateFormat('yyyy-MM-dd').format(now);
                                        });
                                      },
                                      constraints: BoxConstraints.tightFor(width: 30),
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
                                  currentTimeString = DateFormat('HH:mm:ss').format(now);
                                  currentDateString = DateFormat('yyyy-MM-dd').format(now);
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
                          onPressed: (parsedClockIn == null || (parsedClockIn != null && parsedClockOut != null)) ? _handleClockIn : null,
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
                          onPressed: (parsedClockIn != null && parsedClockOut == null) ? _handleClockOut : null,
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
        );
      },
    );
  }

  Future<void> _handleClockIn() async {
    try {
      await _controller.clockIn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clocked in successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clocking in: $e')),
        );
      }
    }
  }

  Future<void> _handleClockOut() async {
    try {
      await _controller.clockOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clocked out successfully')),
        );
      }
    } catch (e) {
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

    await controller.markOffDay(usedTime);

    setState(() {
      clockInTime = null;
      clockOutTime = null;
      selectedDate = null;
      isCustomTimeSelected = false;
      customTime = null;
      
      // Reset displays to current time
      final now = DateTime.now();
      currentTimeString = DateFormat('HH:mm:ss').format(now);
      currentDateString = DateFormat('yyyy-MM-dd').format(now);
    });
  }
} 