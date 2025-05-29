import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../data/repositories/work_hours_repository.dart';
import '../../../summary/summary_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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
        title: const Text('History'),
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
