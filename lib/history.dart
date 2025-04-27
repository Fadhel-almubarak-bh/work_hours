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
    return 'In: ${data['in'] != null ? DateFormat.Hm().format(DateTime.parse(data['in'])) : 'N/A'}, '
        'Out: ${data['out'] != null ? DateFormat.Hm().format(DateTime.parse(data['out'])) : 'N/A'}\n'
        'Worked: ${_formatDuration(data['duration'])}';
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
      ),
    );

    if (result != null) {
      if (result['isOffDay']) {
        await HiveDb.markOffDay(DateFormat('yyyy-MM-dd').parse(key));
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
      final date = DateTime.parse(entry.key.toString());
      final monthKey = DateFormat('yyyy-MM').format(date);

      if (!groupedEntries.containsKey(monthKey)) {
        groupedEntries[monthKey] = [];
      }
      groupedEntries[monthKey]!.add(MapEntry<String, dynamic>(
        entry.key.toString(),
        Map<String, dynamic>.from(entry.value as Map),
      ));
    }

    // Sort entries within each month
    for (final monthEntries in groupedEntries.values) {
      monthEntries.sort((a, b) => b.key.compareTo(a.key));
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
              final monthDate = DateTime.parse(monthKey + '-01');

              return ExpansionTile(
                title: Text(
                  DateFormat('MMMM yyyy').format(monthDate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                children: monthEntries.map((entry) {
                  final date = DateTime.parse(entry.key);
                  final data = entry.value;
                  final clockInStr = data['in'] as String?;
                  final clockOutStr = data['out'] as String?;
                  final duration = data['duration'] as num?;
                  final isOffDay = data['offDay'] as bool? ?? false;

                  final clockInTime =
                      clockInStr != null ? DateTime.parse(clockInStr) : null;
                  final clockOutTime =
                      clockOutStr != null ? DateTime.parse(clockOutStr) : null;

                  return ListTile(
                    title: Text(DateFormat('EEEE, MMMM d').format(date),style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOffDay)
                          Text('Off Day',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,color: context.customColors.offDay,
                            ),)
                        else ...[
                          if (clockInTime != null)
                            Text(
                                'Clock In: ${DateFormat.Hm().format(clockInTime)}'),
                          if (clockOutTime != null)
                            Text(
                                'Clock Out: ${DateFormat.Hm().format(clockOutTime)}'),
                          if (duration != null)
                            Text(
                                'Duration: ${duration.toInt() ~/ 60}h ${duration.toInt() % 60}m'),
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

  const _EditEntryDialog({
    super.key,
    required this.entryKey,
    this.clockInTime,
    this.clockOutTime,
    required this.isOffDay,
  });

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late DateTime? _clockInTime;
  late DateTime? _clockOutTime;
  late bool _isOffDay;

  @override
  void initState() {
    super.initState();
    _clockInTime = widget.clockInTime;
    _clockOutTime = widget.clockOutTime;
    _isOffDay = widget.isOffDay;
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
                if (value) {
                  _clockInTime = null;
                  _clockOutTime = null;
                }
              });
            },
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
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
