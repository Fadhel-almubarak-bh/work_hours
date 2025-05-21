import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'hive_db.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

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

class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key});

  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
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
      final currentMonthExpectedMinutes =
          HiveDb.getCurrentMonthExpectedMinutes();
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
      debugPrint(
          "Overtime: ${currentMonthOvertime >= 0 ? '+' : ''}${formatDuration(currentMonthOvertime.abs())}");

      // Last month details
      final lastMonthExpected = HiveDb.getLastMonthExpectedMinutes();
      final lastMonthOvertime = HiveDb.getLastMonthOvertime();
      debugPrint("\n📅 [LAST MONTH]");
      debugPrint("Expected Hours: ${formatDuration(lastMonthExpected)}");
      debugPrint(
          "Overtime: ${lastMonthOvertime >= 0 ? '+' : ''}${formatDuration(lastMonthOvertime.abs())}");

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

            final progress =
                (todayMinutes / dailyTargetMinutes).clamp(0.0, 1.0);
            final remaining = (dailyTargetMinutes - todayMinutes)
                .clamp(0, dailyTargetMinutes);
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                            const SizedBox(width: 10),
                            Text(
                              'Today\'s Progress',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: textColor,
                                  ),
                            ),
                          ],
                        ),
                        if (isTodayOffDay)
                          const Chip(
                            label: Text('Off Day'),
                            backgroundColor: Colors.blue,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                        if (isCurrentlyClockedIn)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Clocked In',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Progress visualization with radial gauge and stats
                    Row(
                      children: [
                        // Circular progress indicator
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 140,
                            child: SfRadialGauge(
                              enableLoadingAnimation: true,
                              animationDuration: 1000,
                              axes: [
                                RadialAxis(
                                  minimum: 0,
                                  maximum: 100,
                                  showLabels: false,
                                  showTicks: false,
                                  startAngle: 270,
                                  endAngle: 270,
                                  axisLineStyle: AxisLineStyle(
                                    thickness: 0.1,
                                    color: isDarkMode
                                        ? Colors.grey[700]
                                        : Colors.grey[300],
                                    thicknessUnit: GaugeSizeUnit.factor,
                                  ),
                                  pointers: [
                                    RangePointer(
                                      value: progress * 100,
                                      width: 0.1,
                                      sizeUnit: GaugeSizeUnit.factor,
                                      color: progressColor,
                                      enableAnimation: true,
                                    ),
                                  ],
                                  annotations: [
                                    GaugeAnnotation(
                                      widget: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${(progress * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 24,
                                              color: progressColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formatDuration(todayMinutes),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                              color: textColor,
                                            ),
                                          ),
                                          if (isCurrentlyClockedIn) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Started ${_formatTimeAgo(clockInTime!)}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: subTextColor,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      positionFactor: 0,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Stats and details
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Target hours indicator
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey[800]!.withOpacity(0.5)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.flag_outlined,
                                        size: 16,
                                        color: subTextColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Target: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subTextColor,
                                        ),
                                      ),
                                      Text(
                                        formatDuration(dailyTargetMinutes),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Remaining time indicator (or completed indicator)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isComplete || isTodayOffDay
                                        ? (isDarkMode
                                            ? progressColor.withOpacity(0.3)
                                            : progressColor.withOpacity(0.1))
                                        : isDarkMode
                                            ? Colors.orange.withOpacity(0.3)
                                            : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isComplete || isTodayOffDay
                                          ? progressColor.withOpacity(0.3)
                                          : Colors.orange.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isComplete || isTodayOffDay
                                                ? Icons.check_circle_outline
                                                : Icons.timer_outlined,
                                            size: 16,
                                            color: isComplete || isTodayOffDay
                                                ? progressColor
                                                : Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: isComplete || isTodayOffDay
                                                ? Text(
                                                    isTodayOffDay
                                                        ? 'Off day recorded'
                                                        : 'Daily target completed!',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isComplete ||
                                                              isTodayOffDay
                                                          ? progressColor
                                                          : Colors.orange,
                                                    ),
                                                  )
                                                : Text(
                                                    'Remaining: ${formatDuration(remaining)}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                      if (isCurrentlyClockedIn) ...[
                                        Text(
                                          '${DateFormat('hh:mm a').format(DateTime.now().add(Duration(minutes: remaining)))}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subTextColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Current status
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey[800]!.withOpacity(0.5)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCurrentlyClockedIn
                                            ? Icons.play_circle_outline
                                            : Icons.access_time_filled,
                                        size: 16,
                                        color: subTextColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Status: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subTextColor,
                                        ),
                                      ),
                                      Text(
                                        isCurrentlyClockedIn
                                            ? 'Working now'
                                            : todayMinutes > 0
                                                ? 'Clocked out'
                                                : 'Not started',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
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

  Widget _buildOvertimeGaugeCard(Map<String, dynamic> summary) {
    // Get the accurate overtime using our new method
    final currentMonthOvertimeMinutes = HiveDb.getMonthlyOvertime();
    final dailyTarget = HiveDb.getDailyTargetMinutes();

    // Convert to hours for better readability
    final overtimeHours = currentMonthOvertimeMinutes / 60.0;
    final maxGaugeValue =
        dailyTarget / 30.0; // About one day's worth in either direction

    // Determine the gauge values and colors
    double gaugeValue = overtimeHours.abs().clamp(0.0, maxGaugeValue);
    double percentage = (gaugeValue / maxGaugeValue) * 100;

    final isAhead = currentMonthOvertimeMinutes >= 0;
    final displayValue = formatDuration(currentMonthOvertimeMinutes.abs());
    final statusText = isAhead ? 'ahead of schedule' : 'behind schedule';
    final gaugeColor = isAhead ? Colors.green : Colors.red;

    // Get extra details for display
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    final allEntries = HiveDb.getAllEntries();
    final workDaysSetting = HiveDb.getWorkDays();

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

            // Add the gauge visualization
            SizedBox(
              height: 220,
              child: SfRadialGauge(
                enableLoadingAnimation: true,
                animationDuration: 750,
                axes: [
                  RadialAxis(
                    minimum: -maxGaugeValue,
                    maximum: maxGaugeValue,
                    interval: maxGaugeValue / 3,
                    showLabels: true,
                    showTicks: true,
                    radiusFactor: 0.8,
                    axisLineStyle: const AxisLineStyle(
                      thickness: 10,
                      cornerStyle: CornerStyle.bothCurve,
                      color: Colors.black12,
                    ),
                    pointers: [
                      NeedlePointer(
                        value: overtimeHours,
                        needleLength: 0.7,
                        needleColor: gaugeColor,
                        knobStyle: const KnobStyle(
                          knobRadius: 10,
                          sizeUnit: GaugeSizeUnit.logicalPixel,
                        ),
                        tailStyle: const TailStyle(
                          length: 0.15,
                          width: 8,
                          color: Colors.grey,
                        ),
                      ),
                      RangePointer(
                        value: overtimeHours,
                        width: 10,
                        color: gaugeColor,
                        enableAnimation: true,
                      ),
                    ],
                    ranges: [
                      GaugeRange(
                        startValue: -maxGaugeValue,
                        endValue: 0,
                        color: Colors.red.withOpacity(0.3),
                        startWidth: 10,
                        endWidth: 10,
                      ),
                      GaugeRange(
                        startValue: 0,
                        endValue: maxGaugeValue,
                        color: Colors.green.withOpacity(0.3),
                        startWidth: 10,
                        endWidth: 10,
                      ),
                    ],
                    annotations: [
                      GaugeAnnotation(
                        widget: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              displayValue,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: gaugeColor,
                              ),
                            ),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 14,
                                color: gaugeColor,
                              ),
                            ),
                          ],
                        ),
                        positionFactor: 0.9,
                        angle: 90,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Stats section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Regular Days: $regularWorkDays',
                        style: TextStyle(fontSize: 13)),
                    Text('Off Days: $offDays', style: TextStyle(fontSize: 13)),
                    Text('Extra Days: $extraWorkDays',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Required Days: $configuredWorkDaysThisMonth',
                        style: TextStyle(fontSize: 13)),
                    Text('Missed Days: $missedWorkDays',
                        style: TextStyle(fontSize: 13, color: Colors.red)),
                    Text('Daily Target: ${formatDuration(dailyTarget)}',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),

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

  Widget _buildMonthlyTrendChart(Map<String, dynamic> summary) {
    final currentMonthName = DateFormat('MMMM yyyy')
        .format(DateTime(DateTime.now().year, DateTime.now().month, 1));
    final currentMonthExpectedMinutes =
        (summary['currentMonthExpectedMinutes'] as num?)?.toInt() ?? 0;
    final monthlyTotal = (summary['monthlyTotal'] as num?)?.toInt() ?? 0;
    final overtimeMinutes = (summary['overtimeMinutes'] as num?)?.toInt() ?? 0;
    final monthlyWorkDays = (summary['monthlyWorkDays'] as num?)?.toInt() ?? 0;
    final monthlyOffDays = (summary['monthlyOffDays'] as num?)?.toInt() ?? 0;

    // Calculate completion percentage
    final completionPercentage = currentMonthExpectedMinutes > 0
        ? ((monthlyTotal / currentMonthExpectedMinutes) * 100).clamp(0, 100)
        : 0.0;

    return FutureBuilder<List<WorkHoursData>>(
      future: _getMonthlyTrendData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data ?? [];
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final subTextColor = isDarkMode ? Colors.white70 : Colors.grey;
        final containerColor = isDarkMode ? Colors.grey[800] : Colors.white;
        final gridBackgroundColor =
            isDarkMode ? Colors.grey[850] : Colors.grey.withOpacity(0.1);

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with month name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Progress',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'For $currentMonthName',
                          style: TextStyle(fontSize: 14, color: subTextColor),
                        ),
                      ],
                    ),
                    // Completion indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: completionPercentage >= 100
                            ? Colors.green.withOpacity(isDarkMode ? 0.4 : 0.2)
                            : Colors.amber.withOpacity(isDarkMode ? 0.4 : 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${completionPercentage.toStringAsFixed(1)}% Complete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: completionPercentage >= 100
                              ? (isDarkMode ? Colors.green[200] : Colors.green)
                              : (isDarkMode
                                  ? Colors.amber[200]
                                  : Colors.amber[800]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats grid - more visual organization of key metrics
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: gridBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Expected hours box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: containerColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Expected Hours',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: subTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatDuration(currentMonthExpectedMinutes),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Actual hours box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: containerColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Actual Hours',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: subTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatDuration(monthlyTotal),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: overtimeMinutes >= 0
                                          ? (isDarkMode
                                              ? Colors.green[200]
                                              : Colors.green)
                                          : (isDarkMode
                                              ? Colors.red[200]
                                              : Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Work days box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: containerColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Work Days',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: subTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$monthlyWorkDays',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? AppColors.secondaryLight
                                          : AppColors.secondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Off days box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: containerColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Off Days',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: subTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$monthlyOffDays',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.lightBlue[200]
                                          : Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Overtime box - full width
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: overtimeMinutes >= 0
                              ? (isDarkMode
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.green.withOpacity(0.1))
                              : (isDarkMode
                                  ? Colors.red.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Overtime',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: overtimeMinutes >= 0
                                    ? (isDarkMode
                                        ? Colors.green[200]
                                        : Colors.green[700])
                                    : (isDarkMode
                                        ? Colors.red[200]
                                        : Colors.red[700]),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${overtimeMinutes >= 0 ? '+' : ''}${formatDuration(overtimeMinutes.abs())}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: overtimeMinutes >= 0
                                    ? (isDarkMode
                                        ? Colors.green[200]
                                        : Colors.green[700])
                                    : (isDarkMode
                                        ? Colors.red[200]
                                        : Colors.red[700]),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              overtimeMinutes >= 0
                                  ? 'You are ahead of schedule'
                                  : 'You are behind schedule',
                              style: TextStyle(
                                fontSize: 12,
                                color: overtimeMinutes >= 0
                                    ? (isDarkMode
                                        ? Colors.green[200]
                                        : Colors.green[700])
                                    : (isDarkMode
                                        ? Colors.red[200]
                                        : Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Chart title with clearer label
                Text(
                  'Daily Work Hours Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),

                // Add the monthly trend chart with improved settings
                SizedBox(
                  height: 250,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    margin: const EdgeInsets.all(10),
                    primaryXAxis: DateTimeAxis(
                      intervalType: DateTimeIntervalType.days,
                      dateFormat: DateFormat.d(),
                      majorGridLines: const MajorGridLines(width: 0),
                      title: AxisTitle(
                        text: 'Day of Month',
                        textStyle: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      labelStyle: TextStyle(color: subTextColor),
                    ),
                    primaryYAxis: NumericAxis(
                      axisLine: const AxisLine(width: 0),
                      labelFormat: '{value}h',
                      majorTickLines: const MajorTickLines(size: 0),
                      title: AxisTitle(
                        text: 'Hours',
                        textStyle: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      labelStyle: TextStyle(color: subTextColor),
                    ),
                    legend: Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                      overflowMode: LegendItemOverflowMode.wrap,
                      textStyle: TextStyle(color: subTextColor),
                    ),
                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                      format: 'point.x : point.y hours',
                      duration: 3000,
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      textStyle: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                    ),
                    crosshairBehavior: CrosshairBehavior(
                      enable: true,
                      lineColor: isDarkMode ? Colors.grey[400] : Colors.grey,
                      lineDashArray: const <double>[5, 5],
                    ),
                    zoomPanBehavior: ZoomPanBehavior(
                      enablePinching: true,
                      enableDoubleTapZooming: true,
                      enablePanning: true,
                    ),
                    series: <CartesianSeries>[
                      // Actual work hours line
                      LineSeries<WorkHoursData, DateTime>(
                        name: 'Daily Hours',
                        dataSource: data,
                        xValueMapper: (WorkHoursData data, _) => data.date,
                        yValueMapper: (WorkHoursData data, _) => data.hours,
                        color: isDarkMode
                            ? AppColors.secondaryLight.withOpacity(0.9)
                            : AppColors.secondaryLight,
                        width: 3,
                        markerSettings: const MarkerSettings(
                          isVisible: true,
                          height: 6,
                          width: 6,
                          shape: DataMarkerType.circle,
                        ),
                        animationDuration: 1500,
                        enableTooltip: true,
                      ),
                      // Target line
                      LineSeries<WorkHoursData, DateTime>(
                        name: 'Target',
                        dataSource: data,
                        xValueMapper: (WorkHoursData data, _) => data.date,
                        yValueMapper: (WorkHoursData data, _) => data.target,
                        color: isDarkMode
                            ? Colors.grey[400]
                            : Colors.grey.withOpacity(0.7),
                        width: 2,
                        dashArray: const <double>[5, 5],
                      ),
                      // Cumulative line (total hours worked to date)
                      AreaSeries<WorkHoursData, DateTime>(
                        name: 'Cumulative',
                        dataSource: data,
                        xValueMapper: (WorkHoursData data, _) => data.date,
                        yValueMapper: (WorkHoursData data, _) =>
                            data.cumulative,
                        color: isDarkMode
                            ? AppColors.secondaryLight.withOpacity(0.4)
                            : AppColors.secondaryLight.withOpacity(0.2),
                        borderColor: isDarkMode
                            ? AppColors.secondaryLight.withOpacity(0.7)
                            : AppColors.secondaryLight.withOpacity(0.5),
                        borderWidth: 2,
                        animationDuration: 2000,
                      ),
                    ],
                    annotations: <CartesianChartAnnotation>[
                      // Add an annotation to show the current day
                      CartesianChartAnnotation(
                        widget: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.amber.withOpacity(0.9)
                                : Colors.amber.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        coordinateUnit: CoordinateUnit.point,
                        x: DateTime.now(),
                        y: 0,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Add a legend explaining the chart
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey[800]!.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: subTextColor),
                          const SizedBox(width: 8),
                          Text(
                            'Chart Guide',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Blue line: Daily hours worked each day',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      Text(
                        '• Grey line: Daily target hours',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      Text(
                        '• Blue area: Cumulative hours worked in the month',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      Text(
                        '• Zoom: Pinch or double tap to zoom in on specific days',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<WorkHoursData>> _getMonthlyTrendData() async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final List<WorkHoursData> result = [];

    final allEntries = HiveDb.getAllEntries();
    final dailyTarget =
        HiveDb.getDailyTargetMinutes() / 60.0; // Convert to hours
    double cumulativeHours = 0;

    // Generate data for each day of the month until today
    for (var day = firstOfMonth;
        day.isBefore(now.add(const Duration(days: 1)));
        day = day.add(const Duration(days: 1))) {
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final entry = allEntries[dateKey];

      double hoursWorked = 0;

      if (entry != null) {
        if (entry['offDay'] == true) {
          // Off days count as target minutes
          hoursWorked = dailyTarget;
        } else if (entry['duration'] != null) {
          hoursWorked = (entry['duration'] as num).toInt() / 60.0;
        } else if (entry['in'] != null &&
            entry['out'] == null &&
            day.day == now.day) {
          // For today, if clocked in but not out
          final clockInTime = DateTime.parse(entry['in']);
          final currentDuration = now.difference(clockInTime).inMinutes;
          hoursWorked = currentDuration / 60.0;
        }
      }

      cumulativeHours += hoursWorked;

      result.add(WorkHoursData(
        date: day,
        hours: hoursWorked,
        target: dailyTarget,
        cumulative: cumulativeHours,
      ));
    }

    return result;
  }

  Widget _buildWeeklyBarChart() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getWeeklyWorkHours(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data ?? {};
        final List<BarChartGroupData> barGroups = [];

        // Days of the week
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dailyTarget =
            HiveDb.getDailyTargetMinutes() / 60; // Convert to hours

        for (int i = 0; i < 7; i++) {
          final double hours =
              (data[i.toString()] ?? 0.0) / 60.0; // Convert minutes to hours

          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: hours,
                  color: hours >= dailyTarget
                      ? Colors.green
                      : (hours > 0 ? AppColors.primaryLight : Colors.grey[300]),
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Work Hours',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hours worked each day this week',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: dailyTarget *
                          1.5, // Set max Y to 150% of daily target
                      barGroups: barGroups,
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value < 0 || value >= weekdays.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  weekdays[value.toInt()],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 500),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendItem(Colors.green, 'Met Daily Target'),
                    const SizedBox(width: 16),
                    _legendItem(AppColors.primaryLight, 'Below Target'),
                    const SizedBox(width: 16),
                    _legendItem(Colors.grey[300]!, 'No Hours'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getWeeklyWorkHours() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final Map<String, dynamic> weeklyHours = {};

    // Initialize all days to 0 minutes
    for (int i = 0; i < 7; i++) {
      weeklyHours[i.toString()] = 0;
    }

    // Get all entries for the week
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final entry = HiveDb.getDayEntry(day);

      if (entry != null) {
        if (entry['offDay'] == true) {
          // Off days count as target minutes
          weeklyHours[i.toString()] = HiveDb.getDailyTargetMinutes();
        } else if (entry['duration'] != null) {
          weeklyHours[i.toString()] = (entry['duration'] as num).toInt();
        } else if (entry['in'] != null &&
            entry['out'] == null &&
            i == now.weekday - 1) {
          // For today, if clocked in but not out
          final clockInTime = DateTime.parse(entry['in']);
          final currentDuration = now.difference(clockInTime).inMinutes;
          weeklyHours[i.toString()] = currentDuration;
        }
      }
    }

    return weeklyHours;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Salary'),
        actions: [
        ],
      ),
      body: null,
    );
  }

  Widget _buildLastMonthSummaryCard(
      Map<String, dynamic> summary, String lastMonthName) {
    final lastMonthTotal = (summary['lastMonthTotal'] as num?)?.toInt() ?? 0;
    final lastMonthWorkDays =
        (summary['lastMonthWorkDays'] as num?)?.toInt() ?? 0;
    final lastMonthOffDays =
        (summary['lastMonthOffDays'] as num?)?.toInt() ?? 0;
    final lastMonthOvertimeMinutes =
        (summary['lastMonthOvertimeMinutes'] as num?)?.toInt() ?? 0;
    final lastMonthExpectedMinutes =
        (summary['lastMonthExpectedMinutes'] as num?)?.toInt() ?? 0;

    // Create data for the pie chart
    final List<ChartData> pieData = [
      ChartData('Work Days', lastMonthWorkDays.toDouble(), AppColors.infoLight),
      ChartData('Off Days', lastMonthOffDays.toDouble(), Colors.blue),
    ];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Month Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'For $lastMonthName',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Hours summary at the top
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expected:',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formatDuration(lastMonthExpectedMinutes),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Actual:',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formatDuration(lastMonthTotal),
                      style: TextStyle(
                        fontSize: 16,
                        color: lastMonthOvertimeMinutes >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Pie chart for work days vs off days
            SizedBox(
              height: 200,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                series: <CircularSeries>[
                  PieSeries<ChartData, String>(
                    dataSource: pieData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      connectorLineSettings: ConnectorLineSettings(
                        type: ConnectorType.curve,
                        length: '10%',
                      ),
                    ),
                    radius: '70%',
                    explode: true,
                    explodeIndex: 0,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Overtime box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: lastMonthOvertimeMinutes >= 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Overtime',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: lastMonthOvertimeMinutes >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lastMonthOvertimeMinutes >= 0 ? '+' : ''}${formatDuration(lastMonthOvertimeMinutes.abs())}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: lastMonthOvertimeMinutes >= 0
                          ? Colors.green
                          : Colors.red,
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
