import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:work_hours/theme_extensions.dart';
import '../../../../data/local/hive_db.dart';
import '../../../../data/repositories/work_hours_repository.dart';
import '../widgets/overtime_tracker.dart';
import '../../summary_controller.dart';
import 'package:provider/provider.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Schedule the loading after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSummary();
    });
  }

  Future<void> _loadSummary() async {
    if (!mounted) return;
    final controller = context.read<SummaryController>();
    await controller.loadSummary(_selectedMonth);
  }

  void _selectPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _loadSummary();
  }

  void _selectNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSummary,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<SummaryController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = controller.summary;
          if (summary == null) {
            return const Center(child: Text('No data available'));
          }

          return Column(
            children: [
              // Month selector
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _selectPreviousMonth,
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _selectNextMonth,
                    ),
                  ],
                ),
              ),
              
              // Summary cards
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildSummaryCard(
                      'Total Hours',
                      '${summary.totalHours.toStringAsFixed(1)} hours',
                      Icons.access_time,
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(
                      'Work Days',
                      '${summary.workDays} days',
                      Icons.calendar_today,
                      Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(
                      'Overtime',
                      '${summary.overtimeHours.toStringAsFixed(1)} hours',
                      Icons.timer,
                      Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(
                      'Average Daily Hours',
                      '${summary.averageDailyHours.toStringAsFixed(1)} hours',
                      Icons.analytics,
                      Colors.purple,
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
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
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
