import 'package:flutter/material.dart';import 'package:intl/intl.dart';import 'package:flutter_local_notifications/flutter_local_notifications.dart';import 'dart:async';import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:work_hours/permissions.dart';
import 'config.dart';
import 'hive_db.dart';
import 'notification_service.dart';

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

// Helper class to track dialog state
class _LoadingDialogHandle {
  bool isActive = true;
  
  void dismiss(BuildContext context) {
    if (isActive && context.mounted) {
      Navigator.of(context).pop();
      isActive = false;
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  DateTime? clockInTime;
  DateTime? clockOutTime;
  DateTime? selectedDate;
  String currentTimeString = '';
  String currentDateString = '';
  late Timer _clockTimer;
  
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
    WidgetsBinding.instance.addObserver(this);
    _initializeAsync();
    _updateTime();
    // Start a timer that updates every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔍 [WIDGET_DEBUG] App lifecycle state changed to: $state');
    if (state == AppLifecycleState.resumed) {
      // Refresh the state when app is resumed
      debugPrint('🔍 [WIDGET_DEBUG] App resumed, refreshing clock state');
      _getTodayStatus();
    }
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

  Future<void> _initializeAsync() async {
    if (mounted) {
      _getTodayStatus();
    }
  }

  Future<void> _exportDataToExcel() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Text("Exporting data..."),
              ],
            ),
          );
        },
      );
      
      try {
        // Check permissions first
        final permissionsGranted = await PermissionService.checkAndRequestPermissions(context);
        if (!permissionsGranted) {
          // Hide loading dialog
          if (context.mounted) Navigator.of(context).pop();
          NotificationUtil.showWarning(context, 'Storage permission is required to export data');
          return;
        }
        
        await HiveDb.exportDataToExcel();
        
        // Hide loading dialog
        if (context.mounted) Navigator.of(context).pop();
        NotificationUtil.showSuccess(context, '✅ Excel export successful');
      } catch (e) {
        // Hide loading dialog if it's still showing
        if (context.mounted) Navigator.of(context).pop();
        throw e; // Re-throw for outer catch
      }
    } catch (e) {
      NotificationUtil.showError(context, '❌ Error exporting to Excel: ${e.toString()}');
      debugPrint('Export error: $e');
    }
  }

  Future<void> _importDataFromExcel() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Text("Importing data..."),
              ],
            ),
          );
        },
      );
      
      try {
        // Check permissions first
        final permissionsGranted = await PermissionService.checkAndRequestPermissions(context);
        if (!permissionsGranted) {
          // Hide loading dialog
          if (context.mounted) Navigator.of(context).pop();
          NotificationUtil.showWarning(context, 'Storage permission is required to import data');
          return;
        }
        
        await HiveDb.importDataFromExcel();
        
        // Hide loading dialog
        if (context.mounted) Navigator.of(context).pop();
        
        NotificationUtil.showSuccess(context, '✅ Excel import successful');
        setState(() {
          _getTodayStatus(); // Refresh the UI with the imported data
        });
      } catch (e) {
        // Hide loading dialog if it's still showing
        if (context.mounted) Navigator.of(context).pop();
        throw e; // Re-throw for outer catch
      }
    } catch (e) {
      NotificationUtil.showError(context, '❌ Error importing Excel: ${e.toString()}');
      debugPrint('Import error: $e');
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
    // Get time to use (either current or custom selected)
    DateTime usedTime;
    
    if (selectedDate != null) {
      // Use the selected date and time
      usedTime = selectedDate!;
      debugPrint('🕒 Using custom time for clock in: $usedTime');
    } else {
      // Use current time
      usedTime = DateTime.now();
      debugPrint('🕒 Using current time for clock in: $usedTime');
    }

    await HiveDb.clockIn(usedTime);

    setState(() {
      clockInTime = usedTime;
      selectedDate = null;
      isCustomTimeSelected = false;
      customTime = null;
      
      // Reset displays to current time
      final now = DateTime.now();
      currentTimeString = DateFormat('HH:mm:ss').format(now);
      currentDateString = DateFormat('yyyy-MM-dd').format(now);
    });

    NotificationUtil.showSuccess(context, 'Clocked in at ${DateFormat.Hm().format(usedTime)}');
  }

  void _clockOut() async {
    // Get time to use (either current or custom selected)
    DateTime usedTime;
    
    if (selectedDate != null) {
      // Use the selected date and time
      usedTime = selectedDate!;
      debugPrint('🕒 Using custom time for clock out: $usedTime');
    } else {
      // Use current time
      usedTime = DateTime.now();
      debugPrint('🕒 Using current time for clock out: $usedTime');
    }
    
    // Safely get clock in time, either from state or database
    DateTime? clockInTimeLocal = clockInTime;
    
    // If clockInTime is null, try to get it from the database
    if (clockInTimeLocal == null) {
      final data = HiveDb.getDayEntry(DateTime.now());
      final clockInStr = data?['in'];
      if (clockInStr != null) {
        clockInTimeLocal = DateTime.tryParse(clockInStr);
        debugPrint('🔍 [WIDGET_DEBUG] Retrieved clock in time from database: $clockInTimeLocal');
      }
    }
    
    // Make sure we have a valid clock in time
    if (clockInTimeLocal == null) {
      NotificationUtil.showError(context, 'Error: Could not find clock in time');
      return;
    }

    try {
      await HiveDb.clockOut(usedTime, clockInTimeLocal);

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
    final usedDate = selectedDate ?? now;
    final dateKey = DateFormat('yyyy-MM-dd').format(usedDate);

    final existingEntry = HiveDb.getDayEntry(usedDate);
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
      await HiveDb.markOffDay(usedDate, description: description);

      NotificationUtil.showInfo(context, '$description marked with 8 hours for $dateKey');

      setState(() {
        selectedDate = null;
        isCustomTimeSelected = false;
        customTime = null;
        
        // Reset to current time display
        final now = DateTime.now();
        currentTimeString = DateFormat('HH:mm:ss').format(now);
        currentDateString = DateFormat('yyyy-MM-dd').format(now);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

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
                            // Current time display - Now updates in real-time with seconds
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            currentTimeString,
                                            style: theme.textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          color: colorScheme.primary,
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
                                            color: colorScheme.primary,
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
                                  style: theme.textTheme.titleMedium,
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
                                          icon: Icon(Icons.edit, color: colorScheme.primary, size: 18),
                                          label: Text(
                                            selectedDate == null ? currentDateString : DateFormat('yyyy-MM-dd').format(selectedDate!),
                                            style: theme.textTheme.bodyMedium,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (selectedDate != null)
                                        IconButton(
                                          icon: Icon(Icons.refresh, color: colorScheme.primary, size: 18),
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
}
