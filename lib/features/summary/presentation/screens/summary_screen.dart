import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../data/local/hive_db.dart';
import '../../../../data/repositories/work_hours_repository.dart';
import '../../summary_controller.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';

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

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isCalculating = false;
  Future<Map<String, dynamic>>? _summaryFuture;
  final WorkHoursRepository _repository = WorkHoursRepository();

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
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0); // Last day of current month
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);

      final todayEntry = HiveDb.getDayEntry(now);
      int todayMinutes = 0;
      bool isCurrentlyClockedIn = false;
      bool isTodayOffDay = false;

      if (todayEntry != null) {
        isTodayOffDay = todayEntry['offDay'] == true;
        if (isTodayOffDay) {
          todayMinutes = 0; // Don't count off days in total minutes
        } else if (todayEntry['duration'] != null) {
          todayMinutes = (todayEntry['duration'] as num).toInt();
        }
        if (todayEntry['in'] != null && todayEntry['out'] == null) {
          isCurrentlyClockedIn = true;
          final clockInTime = DateTime.parse(todayEntry['in']);
          final currentDuration = now.difference(clockInTime).inMinutes;
          todayMinutes = currentDuration;
        }
      }

      // Get all entries for the current month
      final entries = await _repository.getAllWorkEntries();
      int monthlyTotal = 0;
      int overtimeMinutes = 0;
      final dailyTargetMinutes = HiveDb.getDailyTargetMinutes();

      // Calculate monthly total and overtime for current month only
      for (final entry in entries) {
        // Only process entries from the current month
        if (entry.date.year == now.year && entry.date.month == now.month) {
          if (!entry.isOffDay) {
            monthlyTotal += entry.duration;
            if (entry.duration > dailyTargetMinutes) {
              overtimeMinutes += (entry.duration - dailyTargetMinutes);
            }
          }
        }
      }

      // Add today's minutes if not already included and not an off day
      if (!isTodayOffDay && todayMinutes > 0) {
        // Check if today's entry is already included in the monthly total
        bool isTodayIncluded = false;
        for (final entry in entries) {
          if (entry.date.year == now.year && 
              entry.date.month == now.month && 
              entry.date.day == now.day) {
            isTodayIncluded = true;
            break;
          }
        }

        if (!isTodayIncluded) {
          monthlyTotal += todayMinutes;
          if (todayMinutes > dailyTargetMinutes) {
            overtimeMinutes += (todayMinutes - dailyTargetMinutes);
          }
        }
      }

      // Get work days configuration
      final workDays = HiveDb.getWorkDays();
      final dailyTargetHours = HiveDb.getDailyTargetHours();

      // Calculate expected work days for entire current month
      int expectedWorkDays = 0;
      for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        if (workDays[day.weekday - 1]) {
          expectedWorkDays++;
        }
      }

      // Calculate expected minutes for entire current month
      final currentMonthExpectedMinutes = expectedWorkDays * dailyTargetHours * 60;

      // Get stats excluding today
      final weekStats = HiveDb.getStatsForRange(weekStart, now.subtract(const Duration(days: 1)));
      final monthStats = HiveDb.getStatsForRange(monthStart, now.subtract(const Duration(days: 1)));
      final lastMonthStats = HiveDb.getStatsForRange(lastMonthStart, lastMonthEnd);

      // Calculate monthly total including today if checked out
      int monthlyTotalIncludingToday = (monthStats['totalMinutes'] as num).toInt();
      if (!isCurrentlyClockedIn && todayEntry != null && todayEntry['out'] != null) {
        if (todayEntry['offDay'] == true) {
          monthlyTotalIncludingToday += HiveDb.getDailyTargetMinutes();
        } else if (todayEntry['duration'] != null) {
          monthlyTotalIncludingToday += (todayEntry['duration'] as num).toInt();
        }
      }

      // Calculate overtime based on total expected minutes for the month
      final overtimeMinutesNew = monthlyTotalIncludingToday - currentMonthExpectedMinutes;

      return {
        'weeklyTotal': (weekStats['totalMinutes'] as num).toInt() + (isCurrentlyClockedIn ? 0 : todayMinutes),
        'monthlyTotal': monthlyTotalIncludingToday,
        'lastMonthTotal': (lastMonthStats['totalMinutes'] as num).toInt(),
        'weeklyWorkDays': (weekStats['workDays'] as num).toInt() + (isCurrentlyClockedIn ? 0 : (!isTodayOffDay && todayMinutes > 0 ? 1 : 0)),
        'monthlyWorkDays': (monthStats['workDays'] as num).toInt() + (!isTodayOffDay && todayMinutes > 0 ? 1 : 0),
        'lastMonthWorkDays': (lastMonthStats['workDays'] as num).toInt(),
        'weeklyOffDays': (weekStats['offDays'] as num).toInt() + (isTodayOffDay ? 1 : 0),
        'monthlyOffDays': (monthStats['offDays'] as num).toInt() + (isTodayOffDay ? 1 : 0),
        'lastMonthOffDays': (lastMonthStats['offDays'] as num).toInt(),
        'overtimeMinutes': overtimeMinutesNew,
        'lastMonthOvertimeMinutes': lastMonthStats['overtimeMinutes'] ?? 0,
        'currentMonthExpectedMinutes': currentMonthExpectedMinutes,
        'lastMonthExpectedMinutes': lastMonthStats['expectedMinutes'] ?? 0,
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
      HiveDb.calculateAndPrintMonthlyOvertime();

      final currentMonthExpected = HiveDb.getCurrentMonthExpectedMinutes();
      final currentMonthOvertime = HiveDb.getMonthlyOvertime();

      final lastMonthExpected = HiveDb.getLastMonthExpectedMinutes();
      final lastMonthOvertime = HiveDb.getLastMonthOvertime();
 
      _summaryFuture = _calculateSummary();
    });
  }

  String formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
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

                  final now = DateTime.now();
                  final lastMonth = DateTime(now.year, now.month - 1, 1);
                  final lastMonthName = DateFormat('MMMM yyyy').format(lastMonth);
          
          return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              children: [
                          _buildTodayProgressCard(),
                          const SizedBox(height: 24),
                          _buildOvertimeGaugeCard(summary),
                          const SizedBox(height: 24),
                          _buildMonthlyProgress(summary),
                          const SizedBox(height: 24),
                          _buildWeeklyBarChart(),
                          const SizedBox(height: 24),
                          _buildLastMonthSummaryCard(summary, lastMonthName),
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                                const Text(
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
                    Row(
                      children: [
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
                                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
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
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[100],
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
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isComplete || isTodayOffDay
                                        ? (isDarkMode ? progressColor.withOpacity(0.3) : progressColor.withOpacity(0.1))
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
                                            color: isComplete || isTodayOffDay ? progressColor : Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: isComplete || isTodayOffDay
                                                ? Text(
                                                    isTodayOffDay ? 'Off day recorded' : 'Daily target completed!',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isComplete || isTodayOffDay ? progressColor : Colors.orange,
                                                    ),
                                                  )
                                                : Text(
                                                    'Remaining: ${formatDuration(remaining)}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
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
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCurrentlyClockedIn ? Icons.play_circle_outline : Icons.access_time_filled,
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

  Widget _buildOvertimeGaugeCard(Map<String, dynamic> summary) {
    final overtimeMinutes = summary['overtimeMinutes'] ?? 0;
    final monthlyTotal = summary['monthlyTotal'] ?? 0;
    final currentMonthExpectedMinutes = summary['currentMonthExpectedMinutes'] ?? 0;
    final monthlyWorkDays = summary['monthlyWorkDays'] ?? 0;
    final monthlyOffDays = summary['monthlyOffDays'] ?? 0;

    // Calculate overtime in hours for the gauge
    final overtimeHours = overtimeMinutes / 60.0;
    // Set max gauge value to 20 hours (adjust as needed)
    final maxGaugeValue = 20.0;
    
    // For the gauge, we'll show both positive and negative values
    double gaugeValue = overtimeHours.clamp(-maxGaugeValue, maxGaugeValue);
    double percentage = ((gaugeValue + maxGaugeValue) / (2 * maxGaugeValue)) * 100;

    final isAhead = overtimeMinutes >= 0;
    final displayValue = overtimeMinutes == 0 ? '0h 0m' : formatDuration(overtimeMinutes.abs());
    final statusText = overtimeMinutes == 0 ? 'on schedule' : (isAhead ? 'ahead of schedule' : 'behind schedule');
    final gaugeColor = overtimeMinutes == 0 ? Colors.blue : (isAhead ? Colors.green : Colors.red);


    // Calculate work statistics
    final workDays = HiveDb.getWorkDays();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);

    int configuredWorkDays = 0;
    int workedDays = 0;
    int offDays = 0;
    int missedDays = 0;
    int totalMinutesWorked = 0;
    int expectedMinutesUntilToday = 0;

    // Calculate expected and actual minutes until today
    for (var day = monthStart; day.isBefore(today.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final weekdayIndex = day.weekday - 1;
      final bool isWorkDay = workDays[weekdayIndex];
      final entry = HiveDb.getDayEntry(day);

      if (isWorkDay) {
        configuredWorkDays++;
        expectedMinutesUntilToday += HiveDb.getDailyTargetMinutes();
        
        if (entry != null) {
          if (entry['offDay'] == true) {
            offDays++;
            // Add target minutes for off days since they count towards the monthly target
            totalMinutesWorked += HiveDb.getDailyTargetMinutes();
          } else if (entry['duration'] != null || entry['in'] != null) {
            workedDays++;
            if (entry['duration'] != null) {
              totalMinutesWorked += (entry['duration'] as num).toInt();
            } else if (entry['in'] != null && entry['out'] == null) {
              // For current day if still working
              final clockInTime = DateTime.parse(entry['in']);
              final currentDuration = now.difference(clockInTime).inMinutes;
              totalMinutesWorked += currentDuration;
            }
          } else {
            missedDays++;
          }
        } else {
          missedDays++;
        }
      }
    }

    // Recalculate overtime based on actual minutes worked until today
    final actualOvertimeMinutes = totalMinutesWorked - expectedMinutesUntilToday;
    final actualOvertimeHours = actualOvertimeMinutes / 60.0;
    
    // Update gauge value with actual overtime
    gaugeValue = actualOvertimeHours.clamp(-maxGaugeValue, maxGaugeValue);
    percentage = ((gaugeValue + maxGaugeValue) / (2 * maxGaugeValue)) * 100;

    // Update display values
    final isActuallyAhead = actualOvertimeMinutes >= 0;
    final actualDisplayValue = actualOvertimeMinutes == 0 ? '0h 0m' : formatDuration(actualOvertimeMinutes.abs());
    final actualStatusText = actualOvertimeMinutes == 0 ? 'on schedule' : (isActuallyAhead ? 'ahead of schedule' : 'behind schedule');
    final actualGaugeColor = actualOvertimeMinutes == 0 ? Colors.blue : (isActuallyAhead ? Colors.green : Colors.red);


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
                  'Overtime Tracker',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: actualOvertimeMinutes >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: actualOvertimeMinutes >= 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    actualStatusText,
                    style: TextStyle(
                      color: actualOvertimeMinutes >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: SfRadialGauge(
                enableLoadingAnimation: true,
                animationDuration: 750,
                axes: [
                  RadialAxis(
                    minimum: -maxGaugeValue,
                    maximum: maxGaugeValue,
                    interval: maxGaugeValue / 2,
                    showLabels: true,
                    showLastLabel: true,
                    radiusFactor: 0.8,
                    labelFormat: '{value}h',
                    numberFormat: NumberFormat.compact(),
                    axisLineStyle: const AxisLineStyle(
                      thickness: 10,
                      cornerStyle: CornerStyle.bothCurve,
                      color: Colors.black12,
                    ),
                    majorTickStyle: const MajorTickStyle(
                      length: 0.2,
                      thickness: 1.5,
                      color: Colors.black,
                    ),
                    minorTickStyle: const MinorTickStyle(
                      length: 0.1,
                      thickness: 1,
                      color: Colors.black,
                    ),
                    axisLabelStyle: const GaugeTextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    pointers: [
                      NeedlePointer(
                        value: gaugeValue,
                        needleLength: 0.7,
                        needleColor: actualGaugeColor,
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
                        value: gaugeValue,
                        width: 10,
                        color: actualGaugeColor,
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
                              actualDisplayValue,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: actualGaugeColor,
                              ),
                            ),
                            Text(
                              '${(totalMinutesWorked / 60).toStringAsFixed(1)}h / ${(expectedMinutesUntilToday / 60).toStringAsFixed(1)}h',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work Days',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$workedDays / $configuredWorkDays',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Off Days',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$offDays',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
            if (missedDays > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have $missedDays missed work ${missedDays == 1 ? 'day' : 'days'} this month',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMonthlyProgress(Map<String, dynamic> summary) {
    final monthlyTotal = summary['monthlyTotal'] ?? 0;
    final currentMonthExpectedMinutes = summary['currentMonthExpectedMinutes'] ?? 0;
    final monthlyWorkDays = summary['monthlyWorkDays'] ?? 0;
    final monthlyOffDays = summary['monthlyOffDays'] ?? 0;

    // Get all entries for current month
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final workDays = HiveDb.getWorkDays();
    final dailyTargetMinutes = HiveDb.getDailyTargetMinutes();

    int totalWorkDays = 0;
    int totalOffDays = 0;
    int totalNonWorkDays = 0;
    int totalMinutesWorked = 0;
    int expectedMinutes = 0;
    int actualWorkDays = 0;
    int actualOffDays = 0;

    // Calculate monthly statistics
    for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final weekdayIndex = day.weekday - 1;
      final bool isWorkDay = workDays[weekdayIndex];
      final entry = HiveDb.getDayEntry(day);

      if (isWorkDay) {
        totalWorkDays++;
        expectedMinutes += dailyTargetMinutes;

        if (entry != null) {
          if (entry['offDay'] == true) {
            totalOffDays++;
            actualOffDays++;
            totalMinutesWorked += dailyTargetMinutes;
          } else if (entry['duration'] != null) {
            actualWorkDays++;
            totalMinutesWorked += (entry['duration'] as num).toInt();
          } else if (entry['in'] != null && entry['out'] == null && day.isAtSameMomentAs(now)) {
            actualWorkDays++;
            final clockInTime = DateTime.parse(entry['in']);
            final currentDuration = now.difference(clockInTime).inMinutes;
            totalMinutesWorked += currentDuration;
          }
        }
      } else {
        totalNonWorkDays++;
      }
    }

    // Calculate progress based on actual minutes vs expected minutes
    final progress = expectedMinutes > 0
        ? (totalMinutesWorked / expectedMinutes).clamp(0.0, 1.0)
        : 0.0;


    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Progress',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: progress >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hours Worked',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(totalMinutesWorked ~/ 60)}h ${(totalMinutesWorked % 60)}m',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(expectedMinutes ~/ 60)}h ${(expectedMinutes % 60)}m',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
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
                      'Work Days',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$actualWorkDays / $totalWorkDays',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Off Days',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$actualOffDays',
                      style: Theme.of(context).textTheme.titleMedium,
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

  Widget _buildWeeklyBarChart() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getWeeklyWorkHours(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data ?? {};
        final List<BarChartGroupData> barGroups = [];

        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dailyTarget = HiveDb.getDailyTargetMinutes() / 60;

        // Find the maximum hours worked in a day to set appropriate Y-axis scale
        double maxHours = dailyTarget;
        for (int i = 0; i < 7; i++) {
          final double hours = (data[i.toString()] ?? 0.0) / 60.0;
          if (hours > maxHours) maxHours = hours;
        }
        // Set max Y to either 150% of daily target or 150% of max hours, whichever is greater
        final maxY = (maxHours > dailyTarget ? maxHours : dailyTarget) * 1.5;

        for (int i = 0; i < 7; i++) {
          final double hours = (data[i.toString()] ?? 0.0) / 60.0;

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
                      maxY: maxY,
                      barGroups: barGroups,
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
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
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: dailyTarget,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          );
                        },
                      ),
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

    for (int i = 0; i < 7; i++) {
      weeklyHours[i.toString()] = 0;
    }

    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final entry = HiveDb.getDayEntry(day);

      if (entry != null) {
        if (entry['offDay'] == true) {
          weeklyHours[i.toString()] = HiveDb.getDailyTargetMinutes();
        } else if (entry['duration'] != null) {
          weeklyHours[i.toString()] = (entry['duration'] as num).toInt();
        } else if (entry['in'] != null && entry['out'] == null && i == now.weekday - 1) {
          final clockInTime = DateTime.parse(entry['in']);
          final currentDuration = now.difference(clockInTime).inMinutes;
          weeklyHours[i.toString()] = currentDuration;
        }
      }
    }

    return weeklyHours;
  }

  Widget _buildLastMonthSummaryCard(Map<String, dynamic> summary, String lastMonthName) {
    final lastMonthTotal = (summary['lastMonthTotal'] as num?)?.toInt() ?? 0;
    final lastMonthWorkDays = (summary['lastMonthWorkDays'] as num?)?.toInt() ?? 0;
    final lastMonthOffDays = (summary['lastMonthOffDays'] as num?)?.toInt() ?? 0;
    final lastMonthOvertimeMinutes = (summary['lastMonthOvertimeMinutes'] as num?)?.toInt() ?? 0;
    final lastMonthExpectedMinutes = (summary['lastMonthExpectedMinutes'] as num?)?.toInt() ?? 0;

    final List<ChartData> pieData = [
      ChartData('Work Days', lastMonthWorkDays.toDouble(), AppColors.infoLight),
      ChartData('Off Days', lastMonthOffDays.toDouble(), AppColors.errorLight),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expected:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formatDuration(lastMonthTotal),
                      style: TextStyle(
                        fontSize: 16,
                        color: lastMonthOvertimeMinutes >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                      color: lastMonthOvertimeMinutes >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lastMonthOvertimeMinutes >= 0 ? '+' : ''}${formatDuration(lastMonthOvertimeMinutes.abs())}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: lastMonthOvertimeMinutes >= 0 ? Colors.green : Colors.red,
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
