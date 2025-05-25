import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'hive_db.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'settings.dart';
import 'main.dart';

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
  
  // Add missing variable declarations
  double todayEarnings = 0;
  int expectedHours = 0;
  int workDaysCount = 0;
  int dailyHours = 0;
  double overtimePay = 0;
  double totalEarnings = 0;
  double earningsAfterInsurance = 0;
  int offDaysCount = 0;

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
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      
      // Get entries for the current month
      final entries = HiveDb.getEntriesForRange(monthStart, now);
      
      // Calculate off days count
      int offDaysCount = 0;
      for (var entry in entries) {
        if (entry['offDay'] == true) {
          offDaysCount++;
        }
      }
      
      // Get stats for the month
      final monthStats = HiveDb.getStatsForRange(monthStart, now);
      
      // Get work days configuration
      final workDays = HiveDb.getWorkDays();
      final dailyHours = HiveDb.getDailyTargetHours();
      
      // Calculate expected work days in the month
      int expectedWorkDays = 0;
      for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        if (workDays[day.weekday - 1]) {
          expectedWorkDays++;
        }
      }
      
      // Calculate expected minutes for the month
      final expectedMinutes = expectedWorkDays * dailyHours * 60;
      
      // Calculate actual minutes worked
      final actualMinutes = monthStats['totalMinutes'] as int;
      
      // Calculate overtime
      final overtimeMinutes = actualMinutes - expectedMinutes;
      
      // Calculate daily and hourly rates
      final monthlySalary = HiveDb.getMonthlySalary();
      final dailyRate = monthlySalary / expectedWorkDays;
      final hourlyRate = dailyRate / dailyHours;
      
      // Calculate overtime pay
      final overtimeHours = overtimeMinutes / 60;
      final overtimePay = overtimeMinutes > 0 ? (overtimeHours * hourlyRate * 1.5) : 0;
      
      // Calculate total earnings
      double totalEarnings = 0;
      for (var entry in entries) {
        int minutes = 0;
        if (entry['offDay'] == true) {
          minutes = HiveDb.getDailyTargetMinutes();
        } else if (entry['duration'] != null) {
          minutes = (entry['duration'] as num).toInt();
        }
        totalEarnings += (minutes / 60) * hourlyRate;
      }
      
      // Calculate earnings after insurance
      final earningsAfterInsurance = totalEarnings * 0.92;
      
      return {
        'monthlyTotal': actualMinutes,
        'lastMonthTotal': 0,
        'overtimeMinutes': overtimeMinutes,
        'lastMonthOvertimeMinutes': 0,
        'currentMonthExpectedMinutes': expectedMinutes,
        'lastMonthExpectedMinutes': 0,
        'offDaysCount': offDaysCount,
        'nonWorkingDaysCount': monthStats['nonWorkingDays'] as int,
        'totalDaysOff': monthStats['totalDaysOff'] as int,
        'dailyRate': dailyRate,
        'hourlyRate': hourlyRate,
        'overtimePay': overtimePay,
        'totalEarnings': totalEarnings,
        'earningsAfterInsurance': earningsAfterInsurance,
        'expectedHours': expectedWorkDays * dailyHours,
        'workDaysCount': expectedWorkDays,
        'dailyHours': dailyHours,
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
      _summaryFuture = _calculateSummary();
    });
  }

  String formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSummary,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveDb.getSettingsListenable(),
        builder: (context, Box settings, _) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final summary = snapshot.data ?? {};
              final now = DateTime.now();
              final monthNames = [
                'January', 'February', 'March', 'April', 'May', 'June',
                'July', 'August', 'September', 'October', 'November', 'December'
              ];
              
              final currentMonthName = monthNames[now.month - 1];
              final lastMonth = now.month == 1 ? 12 : now.month - 1;
              final lastMonthName = monthNames[lastMonth - 1];

              final overtimeMinutes = summary['overtimeMinutes'] ?? 0;
              final monthlyTotal = summary['monthlyTotal'] ?? 0;
              final currentMonthExpectedMinutes = summary['currentMonthExpectedMinutes'] ?? 0;

              // Get the monthly salary
              final monthlySalary = HiveDb.getMonthlySalary();
              
              // Calculate the hourly rate based on expected working minutes
              double hourlyRate = 0;
              double dailyRate = 0;
              if (currentMonthExpectedMinutes > 0 && monthlySalary > 0) {
                // Get work days for the current month
                final workDays = HiveDb.getWorkDays();
                final now = DateTime.now();
                final monthStart = DateTime(now.year, now.month, 1);
                final monthEnd = DateTime(now.year, now.month + 1, 0);
                
                // Count actual work days in the month
                int actualWorkDaysInMonth = 0;
                for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
                  if (workDays[day.weekday - 1]) {
                    actualWorkDaysInMonth++;
                  }
                }
                
                // Calculate daily rate based on actual work days
                dailyRate = monthlySalary / actualWorkDaysInMonth;
                
                // Calculate hourly rate
                final dailyHours = HiveDb.getDailyTargetHours();
                hourlyRate = dailyRate / dailyHours;

                // Calculate expected hours for the month
                int workDaysCount = 0;
                for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
                  if (workDays[day.weekday - 1]) {
                    workDaysCount++;
                  }
                }
                final expectedHours = workDaysCount * dailyHours;

                // Calculate the overtime pay (assuming 1.5x for overtime)
                overtimePay = 0;
                if (overtimeMinutes > 0 && hourlyRate > 0) {
                  overtimePay = (overtimeMinutes / 60) * hourlyRate * 1.5;
                }

                // Calculate today's earnings
                todayEarnings = 0;
                if (hourlyRate > 0) {
                  final todayEntry = HiveDb.getDayEntry(now);
                  if (todayEntry != null) {
                    int todayMinutes = 0;
                    if (todayEntry['offDay'] == true) {
                      todayMinutes = HiveDb.getDailyTargetMinutes();
                    } else if (todayEntry['duration'] != null) {
                      todayMinutes = (todayEntry['duration'] as num).toInt();
                    } else if (todayEntry['in'] != null && todayEntry['out'] == null) {
                      final clockInTime = DateTime.parse(todayEntry['in']);
                      todayMinutes = now.difference(clockInTime).inMinutes;
                    }
                    todayEarnings = (todayMinutes / 60) * hourlyRate;
                  }
                }

                // Calculate total earnings including all days
                totalEarnings = 0;
                if (hourlyRate > 0) {
                  // Get all entries for the current month
                  final entries = HiveDb.getEntriesForRange(monthStart, monthEnd);

                  for (var entry in entries) {
                    int minutes = 0;
                    if (entry['offDay'] == true) {
                      minutes = HiveDb.getDailyTargetMinutes();
                    } else if (entry['duration'] != null) {
                      minutes = (entry['duration'] as num).toInt();
                    }
                    totalEarnings += (minutes / 60) * hourlyRate;
                  }
                }

                // Calculate earnings after insurance (92% of total)
                earningsAfterInsurance = totalEarnings * 0.92;
              }

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Today's Earnings Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.today,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Today\'s Earnings',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              formatCurrency(todayEarnings),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Based on ${formatDuration(HiveDb.getDayEntry(now)?['duration'] ?? 0)} worked today',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Current Month Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current Month ($currentMonthName)',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSalaryInfoRow(
                            'Monthly Salary:',
                            formatCurrency(monthlySalary),
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Expected Hours:',
                            '${summary['expectedHours']} hours (${summary['workDaysCount']} days × ${summary['dailyHours']}h)',
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Off Days (Excused):',
                            '${summary['offDaysCount']} days',
                            textColor: Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Weekends:',
                            '${summary['nonWorkingDaysCount']} days',
                            textColor: Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Total Days Off:',
                            '${summary['totalDaysOff']} days',
                            textColor: Theme.of(context).colorScheme.primary,
                            primary: true,
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Daily Rate:',
                            formatCurrency(dailyRate),
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Hourly Rate:',
                            '${formatCurrency(hourlyRate)}/hour',
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Overtime Pay:',
                            formatCurrency(overtimePay),
                            textColor: overtimePay > 0 ? Colors.green : null,
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Total Earnings:',
                            formatCurrency(totalEarnings),
                            primary: true,
                            textColor: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'After Insurance (92%):',
                            formatCurrency(earningsAfterInsurance),
                            textColor: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Hours Worked:',
                            formatDuration(monthlyTotal),
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Hours Left to Do:',
                            formatDuration(-overtimeMinutes),
                            textColor: overtimeMinutes < 0 ? Colors.orange : Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSalaryInfoRow(
    String label,
    String value, {
    bool primary = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: primary
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
        ),
        Text(
          value,
          style: primary
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textColor ?? Theme.of(context).colorScheme.primary,
                  )
              : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    ),
        ),
      ],
    );
  }
}
