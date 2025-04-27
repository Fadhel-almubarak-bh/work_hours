import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'hive_db.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  bool _isCalculating = false;
  Future<Map<String, dynamic>>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _calculateSummary();
  }

  Future<Map<String, dynamic>> _calculateSummary() async {
    if (_isCalculating) return {};
    _isCalculating = true;

    try {
      final now = DateTime.now();
      // Calculate week start (Saturday) by going back to the previous Saturday
      final weekStart = now.subtract(Duration(days: (now.weekday + 1) % 7)); // Saturday
      final monthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      final yesterday = now.subtract(const Duration(days: 1));

      // Get today's entry to calculate current progress
      final todayEntry = HiveDb.getDayEntry(now);
      int todayMinutes = 0;
      bool isCurrentlyClockedIn = false;
      
      if (todayEntry != null) {
        if (todayEntry['offDay'] == true) {
          todayMinutes = HiveDb.getDailyTargetMinutes();
        } else if (todayEntry['duration'] != null) {
          todayMinutes = (todayEntry['duration'] as num).toInt();
        }
        // If currently clocked in, add current duration
        if (todayEntry['in'] != null && todayEntry['out'] == null) {
          isCurrentlyClockedIn = true;
          final clockInTime = DateTime.parse(todayEntry['in']);
          final currentDuration = now.difference(clockInTime).inMinutes;
          todayMinutes = currentDuration;
        }
      }

      // Get stats excluding today
      final weekStats = HiveDb.getStatsForRange(weekStart, now.subtract(const Duration(days: 1)));
      final monthStats = HiveDb.getStatsForRange(monthStart, now.subtract(const Duration(days: 1)));
      final lastMonthStats = HiveDb.getStatsForRange(lastMonthStart, lastMonthEnd);

      // Calculate monthly total including today if checked out
      int monthlyTotal = (monthStats['totalMinutes'] as num).toInt();
      if (!isCurrentlyClockedIn && todayEntry != null && todayEntry['out'] != null) {
        if (todayEntry['offDay'] == true) {
          monthlyTotal += HiveDb.getDailyTargetMinutes();
        } else if (todayEntry['duration'] != null) {
          monthlyTotal += (todayEntry['duration'] as num).toInt();
        }
      }

      // Calculate overtime for completed days only (up to yesterday)
      final overtimeMinutesUntilYesterday = HiveDb.calculateOvertimeUntilYesterday();

      // Calculate weekly and monthly totals separately
      final weeklyTotal = (weekStats['totalMinutes'] as num).toInt() + (isCurrentlyClockedIn ? 0 : todayMinutes);

      return {
        'weeklyTotal': weeklyTotal,
        'monthlyTotal': monthlyTotal,
        'lastMonthTotal': (lastMonthStats['totalMinutes'] as num).toInt(),
        'weeklyWorkDays': (weekStats['workDays'] as num).toInt() + (isCurrentlyClockedIn ? 0 : (todayMinutes > 0 ? 1 : 0)),
        'monthlyWorkDays': (monthStats['workDays'] as num).toInt(),
        'lastMonthWorkDays': (lastMonthStats['workDays'] as num).toInt(),
        'weeklyOffDays': (weekStats['offDays'] as num).toInt() + (isCurrentlyClockedIn ? 0 : (todayEntry?['offDay'] == true ? 1 : 0)),
        'monthlyOffDays': (monthStats['offDays'] as num).toInt(),
        'lastMonthOffDays': (lastMonthStats['offDays'] as num).toInt(),
        'overtimeMinutes': overtimeMinutesUntilYesterday,
      };
    } catch (e) {
      debugPrint('Error calculating summary: $e');
      return {};
    } finally {
      _isCalculating = false;
    }
  }

  void _refreshSummary() {
    print(HiveDb.getAllEntries());
    setState(() {
      _summaryFuture = _calculateSummary();
    });
  }

  String formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Widget _buildTodayProgressCard() {
    return ValueListenableBuilder(
      valueListenable: HiveDb.getWorkHoursListenable(),
      builder: (context, Box workHours, _) {
        return ValueListenableBuilder(
          valueListenable: HiveDb.getSettingsListenable(),
          builder: (context, Box settings, _) {
            final now = DateTime.now();
            final todayEntry = HiveDb.getDayEntry(now);
            final dailyTargetMinutes = HiveDb.getDailyTargetMinutes();
            
            int todayMinutes = 0;
            bool isTodayOffDay = false;

            if (todayEntry != null) {
              if (todayEntry['offDay'] == true) {
                isTodayOffDay = true;
                todayMinutes = dailyTargetMinutes;
              } else if (todayEntry['duration'] != null) {
                todayMinutes = (todayEntry['duration'] as num).toInt();
              }
              
              // If clocked in but not out, calculate current duration
              if (todayEntry['in'] != null && todayEntry['out'] == null) {
                final clockInTime = DateTime.parse(todayEntry['in']);
                final currentDuration = now.difference(clockInTime).inMinutes;
                todayMinutes = currentDuration;
              }
            }

            final progress = (todayMinutes / dailyTargetMinutes).clamp(0.0, 1.0);
            final remaining = (dailyTargetMinutes - todayMinutes).clamp(0, dailyTargetMinutes);
            final isComplete = todayMinutes >= dailyTargetMinutes;

            return Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Progress',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (isTodayOffDay)
                          const Chip(
                            label: Text('Off Day'),
                            backgroundColor: Colors.blue,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isTodayOffDay ? Colors.blue :
                        isComplete ? Colors.green : AppColors.primaryLight,
                      ),
                      minHeight: 10,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isTodayOffDay ? Colors.blue :
                                   isComplete ? Colors.green : AppColors.primaryLight,
                          ),
                        ),
                        Text(
                          '${formatDuration(todayMinutes)} / ${formatDuration(dailyTargetMinutes)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (!isTodayOffDay && !isComplete) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Remaining: ${formatDuration(remaining)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressCard({
    required String title,
    required int current,
    required int target,
    required int workDays,
    required int offDays,
    required Color color,
    bool showTarget = true,
  }) {
    final progress = showTarget ? (current / target).clamp(0.0, 1.0) : 1.0;
    final remaining = showTarget ? (target - current).clamp(0, target) : 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (showTarget) LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showTarget) Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  showTarget 
                    ? '${formatDuration(current)} / ${formatDuration(target)}'
                    : formatDuration(current),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work Days: $workDays',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Off Days: $offDays',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (showTarget) Text(
                  'Remaining: ${formatDuration(remaining)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeCard(Map<String, dynamic> summary) {
    final overtimeMinutes = summary['overtimeMinutes'] as int? ?? 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Progress (Up to Yesterday)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overtime',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: overtimeMinutes >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                  formatDuration(overtimeMinutes.abs()),
                  style: TextStyle(
                    fontSize: 16,
                    color: overtimeMinutes >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (overtimeMinutes != 0) ...[
              const SizedBox(height: 8),
              Text(
                overtimeMinutes > 0
                    ? 'You are ${formatDuration(overtimeMinutes)} ahead of schedule'
                    : 'You are ${formatDuration(overtimeMinutes.abs())} behind schedule',
                style: TextStyle(
                  fontSize: 14,
                  color: overtimeMinutes > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        title: const Text('Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isCalculating ? null : _refreshSummary,
            tooltip: 'Refresh Summary',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveDb.getWorkHoursListenable(),
        builder: (context, Box workHours, _) {
          return ValueListenableBuilder(
            valueListenable: HiveDb.getSettingsListenable(),
            builder: (context, Box settings, _) {
              return FutureBuilder<Map<String, dynamic>>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final summary = snapshot.data ?? {};
                  final weeklyTarget = HiveDb.getWeeklyTargetMinutes();
                  final monthlyTarget = HiveDb.getMonthlyTargetMinutes();

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Bottom 100
                      child: Column(
                        children: [
                          _buildTodayProgressCard(),
                          const SizedBox(height: 24),
                          _buildOvertimeCard(summary),
                          const SizedBox(height: 24),
                          _buildProgressCard(
                            title: 'Weekly Progress',
                            current: (summary['weeklyTotal'] as num?)?.toInt() ?? 0,
                            target: weeklyTarget,
                            workDays: (summary['weeklyWorkDays'] as num?)?.toInt() ?? 0,
                            offDays: (summary['weeklyOffDays'] as num?)?.toInt() ?? 0,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(height: 24),
                          _buildProgressCard(
                            title: 'Monthly Progress',
                            current: (summary['monthlyTotal'] as num?)?.toInt() ?? 0,
                            target: monthlyTarget,
                            workDays: (summary['monthlyWorkDays'] as num?)?.toInt() ?? 0,
                            offDays: (summary['monthlyOffDays'] as num?)?.toInt() ?? 0,
                            color: AppColors.secondaryLight,
                          ),
                          const SizedBox(height: 24),
                          _buildProgressCard(
                            title: 'Last Month Summary',
                            current: (summary['lastMonthTotal'] as num?)?.toInt() ?? 0,
                            target: monthlyTarget,
                            workDays: (summary['lastMonthWorkDays'] as num?)?.toInt() ?? 0,
                            offDays: (summary['lastMonthOffDays'] as num?)?.toInt() ?? 0,
                            color: AppColors.infoLight,
                            showTarget: false,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
