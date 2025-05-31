import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../data/repositories/work_hours_repository.dart';
import '../../../../data/local/hive_db.dart';
import '../../../../data/models/work_entry.dart';
import '../../history_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Map<DateTime, Map<String, dynamic>> _events;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    // Schedule the loading after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
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

  Future<void> _loadHistory() async {
    if (!mounted) return;
    final controller = context.read<HistoryController>();
    await controller.loadHistory(_focusedDay);
  }

  String _formatDuration(dynamic minutesValue) {
    if (minutesValue == null) return '0h 0m';
    final totalMinutes = (minutesValue as num).toInt();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  void _showDayDetails(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
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
      final controller = context.read<HistoryController>();
      final entryMap = _events[DateTime.parse(key)];
      if (entryMap != null) {
        final clockIn = entryMap['in'] != null ? DateTime.parse(entryMap['in'] as String) : null;
        final clockOut = entryMap['out'] != null ? DateTime.parse(entryMap['out'] as String) : null;
        final duration = entryMap['duration'] as int? ?? 0;
        
        final entry = WorkEntry(
          date: DateTime.parse(key),
          clockIn: clockIn,
          clockOut: clockOut,
          isOffDay: entryMap['offDay'] as bool? ?? false,
          description: entryMap['description'] as String?,
          duration: duration,
        );
        await controller.deleteEntry(entry);
    setState(() {
          _loadEvents();
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted')),
          );
        }
      }
    }
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<HistoryController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final normalizedSelectedDay = _selectedDay != null 
              ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
              : null;
          final selectedEntry = normalizedSelectedDay != null ? _events[normalizedSelectedDay] : null;
          final dateKey = _selectedDay != null ? DateFormat('yyyy-MM-dd').format(_selectedDay!) : null;

          return SingleChildScrollView(
            child: Column(
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
                        markerColor = Colors.blue;
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
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
              
                // Entry details section
                if (selectedEntry != null) ...[
                  Divider(height: 1, thickness: 1, color: Colors.grey[300]),
                  Container(
                  padding: const EdgeInsets.all(16.0),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                            Expanded(
                              child: Text(
                                _selectedDay != null
                                    ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)
                                    : '',
                                style: Theme.of(context).textTheme.titleLarge,
                    ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: Colors.red,
                              onPressed: () {
                                if (dateKey != null) {
                                  _confirmAndDeleteEntry(dateKey);
                                }
                              },
                              tooltip: 'Delete Entry',
                            ),
                          ],
                    ),
                    const SizedBox(height: 16),
                        _buildEntryDetailsCard(selectedEntry),
                  ],
                ),
              ),
            ],
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEntryDetailsCard(Map<dynamic, dynamic> entry) {
    final isOffDay = entry['offDay'] == true;
    final description = entry['description'] as String?;
    final clockInStr = entry['in'] != null 
        ? DateFormat('HH:mm').format(DateTime.parse(entry['in'] as String)) 
        : 'N/A';
    final clockOutStr = entry['out'] != null 
        ? DateFormat('HH:mm').format(DateTime.parse(entry['out'] as String)) 
        : 'N/A';
    final duration = _formatDuration(entry['duration']);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOffDay 
                        ? Colors.blue.withOpacity(0.3) 
                        : entry['out'] != null 
                            ? Colors.green.withOpacity(0.3) 
                            : Colors.orange.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  ),
                const SizedBox(width: 8),
                  Text(
                  isOffDay 
                      ? 'Off Day${description != null ? " - $description" : ""}' 
                      : entry['out'] != null 
                          ? 'Completed' 
                          : 'In Progress',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    fontSize: 16,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (!isOffDay) ...[
              _buildInfoRow('Clock In', clockInStr),
              const SizedBox(height: 4),
              _buildInfoRow('Clock Out', clockOutStr),
              const SizedBox(height: 4),
            ],
            _buildInfoRow('Duration', duration),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
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
