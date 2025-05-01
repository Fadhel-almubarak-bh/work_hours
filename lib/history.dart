import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:work_hours/theme_extensions.dart';
import 'config.dart';
import 'hive_db.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
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
        await HiveDb.markOffDay(DateFormat('yyyy-MM-dd').parse(key), description: result['description']);
      } else {
        if (result['clockInTime'] != null) {
          await HiveDb.clockIn(result['clockInTime']);
        }
        if (result['clockOutTime'] != null && result['clockInTime'] != null) {
          await HiveDb.clockOut(result['clockOutTime'], result['clockInTime']);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry updated')),
        );
      }
    }
  }

  Map<String, List<MapEntry<String, dynamic>>> _groupEntriesByMonth(
      Map<dynamic, dynamic> entries) {
    final groupedEntries = <String, List<MapEntry<String, dynamic>>>{};

    for (final entry in entries.entries) {
      try {
        final date = DateTime.tryParse(entry.key.toString());
        if (date != null) {
          final monthKey = DateFormat('yyyy-MM').format(date);

          if (!groupedEntries.containsKey(monthKey)) {
            groupedEntries[monthKey] = [];
          }
          groupedEntries[monthKey]!.add(MapEntry<String, dynamic>(
            entry.key.toString(),
            Map<String, dynamic>.from(entry.value as Map),
          ));
        }
      } catch (e) {
        // Skip invalid entries
        continue;
      }
    }

    // Sort entries within each month
    for (final monthEntries in groupedEntries.values) {
      monthEntries.sort((a, b) {
        try {
          final dateA = DateTime.tryParse(a.key);
          final dateB = DateTime.tryParse(b.key);
          if (dateA != null && dateB != null) {
            return b.key.compareTo(a.key);
          }
        } catch (e) {
          // If there's an error in comparison, keep the original order
        }
        return 0;
      });
    }

    return groupedEntries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: context.customColors.infoDark
        ),),
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
          final entries = HiveDb.getAllEntries();
          final groupedEntries = _groupEntriesByMonth(entries);

          if (entries.isEmpty) {
            return const Center(
              child: Text('No entries yet'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: groupedEntries.length,
            itemBuilder: (context, index) {
              final monthKey = groupedEntries.keys.elementAt(index);
              final monthEntries = groupedEntries[monthKey]!;
              final monthDate = DateTime.tryParse(monthKey + '-01');

              if (monthDate == null) {
                return const SizedBox.shrink();
              }

              return ExpansionTile(
                title: Text(
                  DateFormat('MMMM yyyy').format(monthDate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                children: monthEntries.map((entry) {
                  try {
                    final date = DateTime.tryParse(entry.key);
                    if (date == null) {
                      return const SizedBox.shrink();
                    }

                    final data = entry.value;
                    final clockInStr = data['in'] as String?;
                    final clockOutStr = data['out'] as String?;
                    final duration = data['duration'] as num?;
                    final isOffDay = data['offDay'] as bool? ?? false;
                    final offDayDescription = data['description'] as String?;

                    DateTime? clockInTime;
                    DateTime? clockOutTime;

                    if (clockInStr != null) {
                      clockInTime = DateTime.tryParse(clockInStr);
                    }
                    if (clockOutStr != null) {
                      clockOutTime = DateTime.tryParse(clockOutStr);
                    }

                    return ListTile(
                      title: Text(DateFormat('EEEE, MMMM d').format(date),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isOffDay) ...[
                            Text(
                              offDayDescription ?? 'Off Day',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.customColors.offDay,
                              ),
                            ),
                            if (duration != null)
                              Text('Duration: ${duration.toInt() ~/ 60}h ${duration.toInt() % 60}m'),
                          ] else ...[
                            if (clockInTime != null)
                              Text('Clock In: ${DateFormat.Hm().format(clockInTime)}'),
                            if (clockOutTime != null)
                              Text('Clock Out: ${DateFormat.Hm().format(clockOutTime)}'),
                            if (duration != null)
                              Text('Duration: ${duration.toInt() ~/ 60}h ${duration.toInt() % 60}m'),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editEntry(entry.key, data),
                            tooltip: 'Edit Entry',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _confirmAndDeleteEntry(entry.key),
                            tooltip: 'Delete Entry',
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                }).toList(),
              );
            },
          );
        },
      ),
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
              title: const Text('Regular Off Day'),
              onTap: () => Navigator.pop(context, 'Regular Off Day'),
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
