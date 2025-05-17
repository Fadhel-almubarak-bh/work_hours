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
      final weekStart =
          now.subtract(Duration(days: (now.weekday + 1) % 7)); // Saturday
      final monthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);

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
      final weekStats = HiveDb.getStatsForRange(
          weekStart, now.subtract(const Duration(days: 1)));
      final monthStats = HiveDb.getStatsForRange(
          monthStart, now.subtract(const Duration(days: 1)));
      final lastMonthStats =
          HiveDb.getStatsForRange(lastMonthStart, lastMonthEnd);

      // Calculate monthly total including today if checked out
      int monthlyTotal = (monthStats['totalMinutes'] as num).toInt();
      if (!isCurrentlyClockedIn &&
          todayEntry != null &&
          todayEntry['out'] != null) {
        if (todayEntry['offDay'] == true) {
          monthlyTotal += HiveDb.getDailyTargetMinutes();
        } else if (todayEntry['duration'] != null) {
          monthlyTotal += (todayEntry['duration'] as num).toInt();
        }
      }

      // Calculate monthly overtime using the new method
      final overtimeMinutes = HiveDb.getMonthlyOvertime();
      
      // Calculate last month's overtime
      final lastMonthOvertimeMinutes = HiveDb.getLastMonthOvertime();
      
      // Get expected minutes for both months
      final currentMonthExpectedMinutes = HiveDb.getCurrentMonthExpectedMinutes();
      final lastMonthExpectedMinutes = HiveDb.getLastMonthExpectedMinutes();

      // Calculate weekly and monthly totals separately
      final weeklyTotal = (weekStats['totalMinutes'] as num).toInt() +
          (isCurrentlyClockedIn ? 0 : todayMinutes);

      return {
        'weeklyTotal': weeklyTotal,
        'monthlyTotal': monthlyTotal,
        'lastMonthTotal': (lastMonthStats['totalMinutes'] as num).toInt(),
        'weeklyWorkDays': (weekStats['workDays'] as num).toInt() +
            (isCurrentlyClockedIn ? 0 : (todayMinutes > 0 ? 1 : 0)),
        'monthlyWorkDays': (monthStats['workDays'] as num).toInt(),
        'lastMonthWorkDays': (lastMonthStats['workDays'] as num).toInt(),
        'weeklyOffDays': (weekStats['offDays'] as num).toInt() +
            (isCurrentlyClockedIn
                ? 0
                : (todayEntry?['offDay'] == true ? 1 : 0)),
        'monthlyOffDays': (monthStats['offDays'] as num).toInt(),
        'lastMonthOffDays': (lastMonthStats['offDays'] as num).toInt(),
        'overtimeMinutes': overtimeMinutes,
        'lastMonthOvertimeMinutes': lastMonthOvertimeMinutes,
        'currentMonthExpectedMinutes': currentMonthExpectedMinutes,
        'lastMonthExpectedMinutes': lastMonthExpectedMinutes,
      };
    } catch (e) {
      debugPrint('Error calculating summary: $e');
      return {};
    } finally {
      _isCalculating = false;
    }
  }

  void _refreshSummary() {
    setState(() {
      HiveDb.printAllWorkHourEntries();
      debugPrint("---------------->");
      HiveDb.calculateAndPrintMonthlyOvertime();
      
      // Current month details
      final currentMonthExpected = HiveDb.getCurrentMonthExpectedMinutes();
      final currentMonthOvertime = HiveDb.getMonthlyOvertime();
      debugPrint("\n📅 [CURRENT MONTH]");
      debugPrint("Expected Hours: ${formatDuration(currentMonthExpected)}");
      debugPrint("Overtime: ${currentMonthOvertime >= 0 ? '+' : ''}${formatDuration(currentMonthOvertime.abs())}");
      
      // Last month details
      final lastMonthExpected = HiveDb.getLastMonthExpectedMinutes();
      final lastMonthOvertime = HiveDb.getLastMonthOvertime();
      debugPrint("\n📅 [LAST MONTH]");
      debugPrint("Expected Hours: ${formatDuration(lastMonthExpected)}");
      debugPrint("Overtime: ${lastMonthOvertime >= 0 ? '+' : ''}${formatDuration(lastMonthOvertime.abs())}");
      
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

            final progress =
                (todayMinutes / dailyTargetMinutes).clamp(0.0, 1.0);
            final remaining = (dailyTargetMinutes - todayMinutes)
                .clamp(0, dailyTargetMinutes);
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
                        isTodayOffDay
                            ? Colors.blue
                            : isComplete
                                ? Colors.green
                                : AppColors.primaryLight,
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
                            color: isTodayOffDay
                                ? Colors.blue
                                : isComplete
                                    ? Colors.green
                                    : AppColors.primaryLight,
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
    int? overtime,
    String? subtitle,
    int? expectedMinutes,
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
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            
            // Only show expected vs actual hours if expectedMinutes is provided
            if (expectedMinutes != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expected:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatDuration(expectedMinutes),
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Actual:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatDuration(current),
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const Divider(height: 20),
            ],
            
            if (showTarget)
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 10,
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showTarget)
                  Text(
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
                    if (overtime != null)
                      Text(
                        'Overtime: ${overtime >= 0 ? '+' : ''}${formatDuration(overtime.abs())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: overtime >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                if (showTarget)
                  Text(
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
    // Get the accurate overtime using our new method
    final currentMonthOvertimeMinutes = HiveDb.getMonthlyOvertime();
    
    // Get extra details for display
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    final allEntries = HiveDb.getAllEntries();
    final workDaysSetting = HiveDb.getWorkDays();
    final dailyTarget = HiveDb.getDailyTargetMinutes();
    
    // Count various day types for display
    int regularWorkDays = 0;
    int offDays = 0;
    int extraWorkDays = 0;
    int configuredWorkDaysThisMonth = 0;
    int missedWorkDays = 0;
    int totalWorkedMinutes = 0;
    int totalExpectedMinutes = 0;
    
    for (var day = firstOfMonth;
        day.isBefore(today.add(const Duration(days: 1)));
        day = day.add(const Duration(days: 1))) {
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final entry = allEntries[dateKey];
      final weekdayIndex = day.weekday - 1; // 0-based index (0 = Monday)
      final bool isWorkDay = workDaysSetting[weekdayIndex];
      
      if (isWorkDay) {
        configuredWorkDaysThisMonth++;
        totalExpectedMinutes += dailyTarget;
        
        // Check if this configured work day has no entry
        if (entry == null) {
          missedWorkDays++;
        }
      }
      
      if (entry != null) {
        if (entry['offDay'] == true) {
          offDays++;
          totalWorkedMinutes += dailyTarget;
        } else if (entry['duration'] != null) {
          final duration = (entry['duration'] as num).toInt();
          totalWorkedMinutes += duration;
          
          if (isWorkDay) {
            regularWorkDays++;
          } else {
            extraWorkDays++;
          }
        }
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overtime Tracker',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Current month's overtime (accurate calculation)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Overtime',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  (currentMonthOvertimeMinutes >= 0 ? '+' : '') + formatDuration(currentMonthOvertimeMinutes.abs()),
                  style: TextStyle(
                    fontSize: 18,
                    color: currentMonthOvertimeMinutes >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Expected vs Actual hours
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expected:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  formatDuration(totalExpectedMinutes),
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Actual:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  formatDuration(totalWorkedMinutes),
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
            
            const Divider(height: 20),
            
            // Day counts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Regular Days: $regularWorkDays', style: TextStyle(fontSize: 13)),
                    Text('Off Days: $offDays', style: TextStyle(fontSize: 13)),
                    Text('Extra Days: $extraWorkDays', style: TextStyle(fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Required Days: $configuredWorkDaysThisMonth', style: TextStyle(fontSize: 13)),
                    Text('Missed Days: $missedWorkDays', style: TextStyle(fontSize: 13, color: Colors.red)),
                    Text('Daily Target: ${formatDuration(dailyTarget)}', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            if (currentMonthOvertimeMinutes != 0) ...[
              Text(
                currentMonthOvertimeMinutes > 0
                    ? 'You are ${formatDuration(currentMonthOvertimeMinutes)} ahead of schedule'
                    : 'You are ${formatDuration(currentMonthOvertimeMinutes.abs())} behind schedule',
                style: TextStyle(
                  fontSize: 14,
                  color: currentMonthOvertimeMinutes > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            
            if (missedWorkDays > 0) ...[
              const SizedBox(height: 8),
              Text(
                'You have $missedWorkDays missed work ${missedWorkDays == 1 ? 'day' : 'days'} this month',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
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
                  
                  // Get the current and last month periods for subtitles
                  final now = DateTime.now();
                  final currentMonth = DateTime(now.year, now.month, 1);
                  final lastMonth = DateTime(now.year, now.month - 1, 1);
                  final currentMonthName = DateFormat('MMMM yyyy').format(currentMonth);
                  final lastMonthName = DateFormat('MMMM yyyy').format(lastMonth);

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 16, 16, 100), // Bottom 100
                      child: Column(
                        children: [
                          _buildTodayProgressCard(),
                          const SizedBox(height: 24),
                          _buildOvertimeCard(summary),
                          const SizedBox(height: 24),
                          _buildProgressCard(
                            title: 'Weekly Progress',
                            current:
                                (summary['weeklyTotal'] as num?)?.toInt() ?? 0,
                            target: weeklyTarget,
                            workDays:
                                (summary['weeklyWorkDays'] as num?)?.toInt() ??
                                    0,
                            offDays:
                                (summary['weeklyOffDays'] as num?)?.toInt() ??
                                    0,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(height: 24),
                          _buildProgressCard(
                            title: 'Monthly Progress',
                            subtitle: 'For $currentMonthName',
                            current:
                                (summary['monthlyTotal'] as num?)?.toInt() ?? 0,
                            target: monthlyTarget,
                            workDays:
                                (summary['monthlyWorkDays'] as num?)?.toInt() ??
                                    0,
                            offDays:
                                (summary['monthlyOffDays'] as num?)?.toInt() ??
                                    0,
                            color: AppColors.secondaryLight,
                            overtime: (summary['overtimeMinutes'] as num?)?.toInt(),
                            expectedMinutes: (summary['currentMonthExpectedMinutes'] as num?)?.toInt(),
                          ),
                          const SizedBox(height: 24),
                          _buildProgressCard(
                            title: 'Last Month Summary',
                            subtitle: 'For $lastMonthName',
                            current:
                                (summary['lastMonthTotal'] as num?)?.toInt() ??
                                    0,
                            target: monthlyTarget,
                            workDays: (summary['lastMonthWorkDays'] as num?)
                                    ?.toInt() ??
                                0,
                            offDays: (summary['lastMonthOffDays'] as num?)
                                    ?.toInt() ??
                                0,
                            color: AppColors.infoLight,
                            showTarget: false,
                            overtime: (summary['lastMonthOvertimeMinutes'] as num?)?.toInt(),
                            expectedMinutes: (summary['lastMonthExpectedMinutes'] as num?)?.toInt(),
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
