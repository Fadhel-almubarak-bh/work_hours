import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:work_hours/theme_extensions.dart';
import 'config.dart';
import 'hive_db.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Map<DateTime, Map<String, dynamic>> _events;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    final entries = HiveDb.getAllEntries();
    _events = {};
    
    entries.forEach((key, value) {
      try {
        final date = DateTime.parse(key);
        // Normalize the date to remove time component
        final normalizedDate = DateTime(date.year, date.month, date.day);
        _events[normalizedDate] = Map<String, dynamic>.from(value);
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    });
  }

  String _formatDuration(dynamic minutesValue) {
    if (minutesValue == null) return '0h 0m';
    final totalMinutes = (minutesValue as num).toInt();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String _getEntryDescription(Map<dynamic, dynamic> data) {
    if (data['offDay'] == true) {
      return 'Off Day - ${_formatDuration(data['duration'])}';
    }

    String clockInStr = 'N/A';
    String clockOutStr = 'N/A';

    try {
      if (data['in'] != null) {
        final parsedIn = DateTime.tryParse(data['in']);
        if (parsedIn != null) {
          clockInStr = DateFormat.Hm().format(parsedIn);
        }
      }
      if (data['out'] != null) {
        final parsedOut = DateTime.tryParse(data['out']);
        if (parsedOut != null) {
          clockOutStr = DateFormat.Hm().format(parsedOut);
        }
      }
    } catch (e) {
      // If there's any error in parsing, keep the default 'N/A' values
    }

    return 'In: $clockInStr, Out: $clockOutStr\nWorked: ${_formatDuration(data['duration'])}';
  }

  Future<bool> _confirmAndDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Entries'),
        content: const Text(
            'Are you sure you want to delete all entries? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HiveDb.deleteAllEntries();
      setState(() {
        _loadEvents();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All entries deleted')),
        );
      }
    }
    return confirmed ?? false;
  }

  Future<bool> _confirmAndDeleteEntry(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HiveDb.deleteEntry(key);
      setState(() {
        _loadEvents();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
        );
      }
    }
    return confirmed ?? false;
  }

  Future<void> _editEntry(String key, Map<dynamic, dynamic> entry) async {
    DateTime? clockInTime;
    DateTime? clockOutTime;
    bool isOffDay = entry['offDay'] ?? false;
    String? offDayDescription = entry['description'] as String?;

    if (entry['in'] != null) {
      clockInTime = DateTime.parse(entry['in']);
    }
    if (entry['out'] != null) {
      clockOutTime = DateTime.parse(entry['out']);
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditEntryDialog(
        entryKey: key,
        clockInTime: clockInTime,
        clockOutTime: clockOutTime,
        isOffDay: isOffDay,
        offDayDescription: offDayDescription,
      ),
    );

    if (result != null) {
      if (result['isOffDay']) {
        await HiveDb.markOffDay(DateFormat('yyyy-MM-dd').parse(key),
            description: result['description']);
      } else {
        if (result['clockInTime'] != null) {
          await HiveDb.clockIn(result['clockInTime']);
        }
        if (result['clockOutTime'] != null && result['clockInTime'] != null) {
          await HiveDb.clockOut(result['clockOutTime'], result['clockInTime']);
        }
      }
      setState(() {
        _loadEvents();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry updated')),
        );
      }
    }
  }

  void _showDayDetails(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    final entry = _events[normalizedDate];
    if (entry == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(day),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              _getEntryDescription(entry),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmAndDeleteEntry(dateKey);
                  },
                  child: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _editEntry(dateKey, entry);
                  },
                  child: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.customColors.infoDark,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmAndDeleteAll,
            tooltip: 'Delete All Entries',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveDb.getWorkHoursListenable(),
        builder: (context, Box workHours, _) {
          _loadEvents(); // Reload events when the box changes
          
          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _showDayDetails(selectedDay);
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  weekendTextStyle: const TextStyle(color: Colors.red),
                  holidayTextStyle: const TextStyle(color: Colors.blue),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final normalizedDate = DateTime(date.year, date.month, date.day);
                    final entry = _events[normalizedDate];
                    if (entry == null) return null;

                    final isOffDay = entry['offDay'] == true;
                    final duration = entry['duration'] as num?;
                    final hasClockIn = entry['in'] != null;
                    final hasClockOut = entry['out'] != null;

                    Color markerColor;
                    if (isOffDay) {
                      markerColor = context.customColors.offDay;
                    } else if (hasClockIn && hasClockOut) {
                      markerColor = Colors.green;
                    } else if (hasClockIn) {
                      markerColor = Colors.orange;
                    } else {
                      markerColor = Colors.grey;
                    }

                    return Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(1),
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(4),
                          color: markerColor.withOpacity(0.3),
                        ),
                        child: Center(
                          child: Text(
                            duration != null ? _formatDuration(duration) : '',
                            style: TextStyle(
                              fontSize: 10,
                              color: markerColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _LegendItem(
                      color: Colors.green,
                      label: 'Completed',
                    ),
                    _LegendItem(
                      color: Colors.orange,
                      label: 'In Progress',
                    ),
                    _LegendItem(
                      color: Colors.blue,
                      label: 'Off Day',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _EditEntryDialog extends StatefulWidget {
  final String entryKey;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final bool isOffDay;
  final String? offDayDescription;

  const _EditEntryDialog({
    super.key,
    required this.entryKey,
    this.clockInTime,
    this.clockOutTime,
    required this.isOffDay,
    this.offDayDescription,
  });

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late DateTime? _clockInTime;
  late DateTime? _clockOutTime;
  late bool _isOffDay;
  String? _offDayDescription;

  @override
  void initState() {
    super.initState();
    _clockInTime = widget.clockInTime;
    _clockOutTime = widget.clockOutTime;
    _isOffDay = widget.isOffDay;
    _offDayDescription = widget.offDayDescription;
  }

  Future<void> _pickDateTime(bool isClockIn) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isClockIn
          ? (_clockInTime ?? DateTime.now())
          : (_clockOutTime ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isClockIn
            ? (_clockInTime ?? DateTime.now())
            : (_clockOutTime ?? DateTime.now()),
      ),
    );

    if (time == null) return;

    setState(() {
      if (isClockIn) {
        _clockInTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      } else {
        _clockOutTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    });
  }

  Future<void> _selectOffDayType() async {
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

    if (description != null) {
      setState(() {
        _offDayDescription = description;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Entry'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Off Day'),
            value: _isOffDay,
            onChanged: (value) {
              setState(() {
                _isOffDay = value;
                if (value && _offDayDescription == null) {
                  _selectOffDayType();
                }
                if (!value) {
                  _offDayDescription = null;
                }
                if (value) {
                  _clockInTime = null;
                  _clockOutTime = null;
                }
              });
            },
          ),
          if (_isOffDay)
            ListTile(
              title: const Text('Off Day Type'),
              subtitle: Text(_offDayDescription ?? 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: _selectOffDayType,
            ),
          if (!_isOffDay) ...[
            ListTile(
              title: const Text('Clock In'),
              subtitle: Text(_clockInTime != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(_clockInTime!)
                  : 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () => _pickDateTime(true),
            ),
            ListTile(
              title: const Text('Clock Out'),
              subtitle: Text(_clockOutTime != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(_clockOutTime!)
                  : 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () => _pickDateTime(false),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_isOffDay || _clockInTime != null) {
              Navigator.pop(context, {
                'clockInTime': _clockInTime,
                'clockOutTime': _clockOutTime,
                'isOffDay': _isOffDay,
                'description': _offDayDescription,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
} 