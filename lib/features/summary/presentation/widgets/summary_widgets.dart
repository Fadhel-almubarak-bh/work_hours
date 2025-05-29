import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../../../config.dart';
import '../../../../data/local/hive_db.dart';


// Data model for chart
class WorkHoursData {
  final DateTime date;
  final double hours;
  final double target;
  final double cumulative;

  WorkHoursData({
    required this.date,
    required this.hours,
    required this.target,
    required this.cumulative,
  });
}

// Data model for pie chart
class ChartData {
  final String x;
  final double y;
  final Color color;

  ChartData(this.x, this.y, this.color);
}

class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
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
            bool isCurrentlyClockedIn = false;
            DateTime? clockInTime;

            if (todayEntry != null) {
              if (todayEntry['offDay'] == true) {
                isTodayOffDay = true;
                todayMinutes = dailyTargetMinutes;
              } else if (todayEntry['duration'] != null) {
                todayMinutes = (todayEntry['duration'] as num).toInt();
              }

              // If clocked in but not out, calculate current duration
              if (todayEntry['in'] != null && todayEntry['out'] == null) {
                isCurrentlyClockedIn = true;
                clockInTime = DateTime.parse(todayEntry['in']);
                final currentDuration = now.difference(clockInTime).inMinutes;
                todayMinutes = currentDuration;
              }
            }

            final progress = (todayMinutes / dailyTargetMinutes).clamp(0.0, 1.0);
            final remaining = (dailyTargetMinutes - todayMinutes).clamp(0, dailyTargetMinutes);
            final isComplete = todayMinutes >= dailyTargetMinutes;

            final progressColor = isTodayOffDay
                ? Colors.blue
                : isComplete
                    ? Colors.green
                    : AppColors.primaryLight;

            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            final textColor = isDarkMode ? Colors.white : Colors.black;
            final subTextColor = isDarkMode ? Colors.white70 : Colors.grey[600];

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCurrentlyClockedIn
                                  ? Icons.timer_outlined
                                  : isComplete
                                      ? Icons.check_circle_outline
                                      : Icons.access_time,
                              color: progressColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isTodayOffDay
                                  ? 'Off Day'
                                  : isCurrentlyClockedIn
                                      ? 'Currently Working'
                                      : isComplete
                                          ? 'Daily Target Achieved'
                                          : 'Daily Progress',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (isCurrentlyClockedIn && clockInTime != null)
                          Text(
                            'Started at ${DateFormat.Hm().format(clockInTime)}',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    FAProgressBar(
                      currentValue: (progress * 100).toDouble(),
                      maxValue: 100.0,
                      size: 20.0,
                      borderRadius: BorderRadius.circular(10),
                      backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                      progressColor: progressColor,
                      animatedDuration: const Duration(milliseconds: 500),
                    ),
                    const SizedBox(height: 16),
                    // Progress details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Remaining',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${remaining ~/ 60}h ${remaining % 60}m',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class WeeklySummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const WeeklySummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final weeklyTotal = summary['weeklyTotal'] as int? ?? 0;
    final weeklyWorkDays = summary['weeklyWorkDays'] as int? ?? 0;
    final weeklyOffDays = summary['weeklyOffDays'] as int? ?? 0;
    final weeklyTarget = HiveDb.getWeeklyTargetMinutes();

    final progress = (weeklyTotal / weeklyTarget).clamp(0.0, 1.0);
    final remaining = (weeklyTarget - weeklyTotal).clamp(0, weeklyTarget);
    final isComplete = weeklyTotal >= weeklyTarget;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Summary',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  isComplete ? Icons.check_circle_outline : Icons.access_time,
                  color: isComplete ? Colors.green : AppColors.primaryLight,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FAProgressBar(
              currentValue: (progress * 100).toDouble(),
              maxValue: 100.0,
              size: 20.0,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
              progressColor: isComplete ? Colors.green : AppColors.primaryLight,
              animatedDuration: const Duration(milliseconds: 500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work Days',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$weeklyWorkDays days',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Off Days',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$weeklyOffDays days',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${remaining ~/ 60}h ${remaining % 60}m',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MonthlySummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const MonthlySummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final monthlyTotal = summary['monthlyTotal'] as int? ?? 0;
    final monthlyWorkDays = summary['monthlyWorkDays'] as int? ?? 0;
    final monthlyOffDays = summary['monthlyOffDays'] as int? ?? 0;
    final overtimeMinutes = summary['overtimeMinutes'] as int? ?? 0;
    final monthlyTarget = HiveDb.getMonthlyTargetMinutes();

    final progress = (monthlyTotal / monthlyTarget).clamp(0.0, 1.0);
    final remaining = (monthlyTarget - monthlyTotal).clamp(0, monthlyTarget);
    final isComplete = monthlyTotal >= monthlyTarget;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Summary',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  isComplete ? Icons.check_circle_outline : Icons.access_time,
                  color: isComplete ? Colors.green : AppColors.primaryLight,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FAProgressBar(
              currentValue: (progress * 100).toDouble(),
              maxValue: 100.0,
              size: 20.0,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
              progressColor: isComplete ? Colors.green : AppColors.primaryLight,
              animatedDuration: const Duration(milliseconds: 500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work Days',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$monthlyWorkDays days',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Off Days',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$monthlyOffDays days',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Overtime',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${overtimeMinutes >= 0 ? '+' : ''}${overtimeMinutes ~/ 60}h ${overtimeMinutes.abs() % 60}m',
                      style: TextStyle(
                        color: overtimeMinutes >= 0 ? Colors.green : Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
