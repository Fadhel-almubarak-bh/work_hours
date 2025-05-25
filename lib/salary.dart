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
      
      // Get work days configuration and daily hours
      final workDays = HiveDb.getWorkDays();
      final dailyHours = HiveDb.getDailyTargetHours();
      final monthlySalary = HiveDb.getMonthlySalary();
      
      // Debug print all months data
      debugPrint('\n📊 [SALARY PAGE] All Months Data:');
      debugPrint('==========================================');
      
      // Get all entries
      final allEntries = HiveDb.getAllEntries();
      
      // Group entries by month
      Map<String, List<MapEntry<String, dynamic>>> monthlyEntries = {};
      allEntries.forEach((key, value) {
        final date = DateTime.parse(key);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        if (!monthlyEntries.containsKey(monthKey)) {
          monthlyEntries[monthKey] = [];
        }
        monthlyEntries[monthKey]!.add(MapEntry(key, value));
      });
      
      // Sort months
      final sortedMonths = monthlyEntries.keys.toList()..sort();
      
      // Process each month
      for (final monthKey in sortedMonths) {
        final monthEntries = monthlyEntries[monthKey]!;
        final monthDate = DateTime.parse('$monthKey-01');
        final monthStart = DateTime(monthDate.year, monthDate.month, 1);
        final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 0);
        
        // Calculate weekends for this month
        int weekendDays = 0;
        for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
          if (!workDays[day.weekday - 1]) {
            weekendDays++;
          }
        }
        
        // Calculate off days for this month
        int offDaysCount = 0;
        for (var entry in monthEntries) {
          if (entry.value['offDay'] == true) {
            offDaysCount++;
          }
        }
        
        // Calculate expected work days
        int expectedWorkDays = 0;
        for (var day = monthStart; day.isBefore(monthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
          if (workDays[day.weekday - 1]) {
            expectedWorkDays++;
          }
        }
        
        // Calculate actual minutes
        int actualMinutes = 0;
        for (var entry in monthEntries) {
          if (entry.value['duration'] != null) {
            actualMinutes += (entry.value['duration'] as num).toInt();
          }
        }
        
        // Calculate rates
        final expectedMinutes = expectedWorkDays * dailyHours * 60;
        final overtimeMinutes = actualMinutes - expectedMinutes;
        final dailyRate = expectedWorkDays > 0 ? monthlySalary / expectedWorkDays : 0.0;
        final hourlyRate = dailyHours > 0 ? dailyRate / dailyHours : 0.0;
        final overtimePay = overtimeMinutes > 0 && hourlyRate > 0 ? (overtimeMinutes / 60) * hourlyRate * 1.5 : 0.0;
        final totalEarnings = hourlyRate > 0 ? (actualMinutes / 60) * hourlyRate : 0.0;
        final earningsAfterInsurance = totalEarnings > 0 ? totalEarnings * 0.92 : 0.0;
        
        // Print month data
        debugPrint('\n📅 Month: ${DateFormat('MMMM yyyy').format(monthStart)}');
        debugPrint('----------------------');
        debugPrint('Total Days: ${monthEnd.day}');
        debugPrint('Expected Work Days: $expectedWorkDays');
        debugPrint('Non-working Days: $weekendDays');
        debugPrint('Off Days (Excused): $offDaysCount');
        debugPrint('Total Days Off: ${weekendDays + offDaysCount}');
        debugPrint('Actual Minutes: $actualMinutes');
        debugPrint('Expected Minutes: $expectedMinutes');
        debugPrint('Overtime Minutes: $overtimeMinutes');
        debugPrint('Daily Rate: ${formatCurrency(dailyRate.toDouble())}');
        debugPrint('Hourly Rate: ${formatCurrency(hourlyRate.toDouble())}');
        debugPrint('Overtime Pay: ${formatCurrency(overtimePay.toDouble())}');
        debugPrint('Total Earnings: ${formatCurrency(totalEarnings.toDouble())}');
        debugPrint('After Insurance: ${formatCurrency(earningsAfterInsurance.toDouble())}');
        debugPrint('----------------------');
      }
      
      debugPrint('\n==========================================\n');
      
      // Continue with current month calculations for the UI
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
      
      // Calculate weekends for current month
      int weekendDays = 0;
      for (var day = currentMonthStart; day.isBefore(currentMonthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        if (!workDays[day.weekday - 1]) {
          weekendDays++;
        }
      }
      
      // Calculate off days count
      int offDaysCount = 0;
      for (var entry in entries) {
        if (entry['offDay'] == true) {
          offDaysCount++;
        }
      }
      
      // Calculate expected work days
      int expectedWorkDays = 0;
      for (var day = currentMonthStart; day.isBefore(currentMonthEnd.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        if (workDays[day.weekday - 1]) {
          expectedWorkDays++;
        }
      }
      
      // Get stats for the month
      final monthStats = HiveDb.getStatsForRange(currentMonthStart, now);
      
      // Calculate expected minutes for the month (only for days up to today)
      int expectedMinutes = 0;
      for (var day = currentMonthStart; day.isBefore(now.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        if (workDays[day.weekday - 1]) {
          expectedMinutes += dailyHours * 60;
        }
      }
      
      // Calculate actual minutes worked
      final actualMinutes = monthStats['totalMinutes'] as int;
      
      // Calculate overtime
      final overtimeMinutes = actualMinutes - expectedMinutes;
      
      // Calculate daily and hourly rates
      final dailyRate = expectedWorkDays > 0 ? monthlySalary / expectedWorkDays : 0.0;
      final hourlyRate = dailyHours > 0 ? dailyRate / dailyHours : 0.0;
      
      // Calculate overtime pay (only for positive overtime)
      final overtimeHours = overtimeMinutes > 0 ? overtimeMinutes / 60 : 0;
      final overtimePay = overtimeMinutes > 0 && hourlyRate > 0 ? (overtimeHours * hourlyRate * 1.5) : 0.0;
      
      // Calculate total earnings
      double totalEarnings = 0.0;
      if (hourlyRate > 0) {
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
      
      // Calculate earnings after insurance
      final earningsAfterInsurance = totalEarnings > 0 ? totalEarnings * 0.92 : 0.0;
      
      // Calculate today's earnings
      double todayEarnings = 0.0;
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
      
      // Debug print salary calculations
      debugPrint('\n💰 [SALARY PAGE] Salary Calculations:');
      debugPrint('----------------------');
      debugPrint('Monthly Salary: $monthlySalary');
      debugPrint('Expected Work Days: $expectedWorkDays');
      debugPrint('Daily Hours: $dailyHours');
      debugPrint('Daily Rate: $dailyRate');
      debugPrint('Hourly Rate: $hourlyRate');
      debugPrint('Actual Minutes: $actualMinutes');
      debugPrint('Expected Minutes: $expectedMinutes');
      debugPrint('Overtime Minutes: $overtimeMinutes');
      debugPrint('Overtime Pay: $overtimePay');
      debugPrint('Total Earnings: $totalEarnings');
      debugPrint('After Insurance: $earningsAfterInsurance');
      debugPrint('----------------------\n');
      
      return {
        'monthlyTotal': actualMinutes,
        'lastMonthTotal': 0,
        'overtimeMinutes': overtimeMinutes,
        'lastMonthOvertimeMinutes': 0,
        'currentMonthExpectedMinutes': expectedMinutes,
        'lastMonthExpectedMinutes': 0,
        'offDaysCount': offDaysCount,
        'nonWorkingDaysCount': weekendDays,
        'totalDaysOff': weekendDays + offDaysCount,
        'dailyRate': dailyRate,
        'hourlyRate': hourlyRate,
        'overtimePay': overtimePay,
        'totalEarnings': totalEarnings,
        'earningsAfterInsurance': earningsAfterInsurance,
        'expectedHours': expectedWorkDays * dailyHours,
        'workDaysCount': expectedWorkDays,
        'dailyHours': dailyHours,
        'todayEarnings': todayEarnings,
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
    if (amount.isInfinite || amount.isNaN) return '0.000 BHD';
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
              double hourlyRate = summary['hourlyRate'] ?? 0.0;
              double dailyRate = summary['dailyRate'] ?? 0.0;
              double overtimePay = summary['overtimePay'] ?? 0.0;
              double totalEarnings = summary['totalEarnings'] ?? 0.0;
              double earningsAfterInsurance = summary['earningsAfterInsurance'] ?? 0.0;
              int workDaysCount = summary['workDaysCount'] ?? 0;
              int expectedHours = summary['expectedHours'] ?? 0;
              int dailyHours = summary['dailyHours'] ?? 0;
              double todayEarnings = summary['todayEarnings'] ?? 0.0;

              // Debug print today's entry
              final todayEntry = HiveDb.getDayEntry(now);
              debugPrint('\n📅 [SALARY PAGE] Today\'s Entry:');
              debugPrint('----------------------');
              debugPrint('Entry: $todayEntry');
              debugPrint('Hourly Rate: $hourlyRate');
              debugPrint('Today\'s Earnings: $todayEarnings');
              debugPrint('----------------------\n');

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
                            '${expectedHours} hours (${workDaysCount} days × ${dailyHours}h)',
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
                            '${(summary['monthlyTotal'] ?? 0) ~/ 60}h ${(summary['monthlyTotal'] ?? 0) % 60}m',
                          ),
                          const SizedBox(height: 8),
                          _buildSalaryInfoRow(
                            'Hours Left to Do:',
                            '${((summary['currentMonthExpectedMinutes'] ?? 0) - (summary['monthlyTotal'] ?? 0)) ~/ 60}h ${((summary['currentMonthExpectedMinutes'] ?? 0) - (summary['monthlyTotal'] ?? 0)).abs() % 60}m',
                            textColor: ((summary['currentMonthExpectedMinutes'] ?? 0) - (summary['monthlyTotal'] ?? 0)) < 0 ? Colors.green : Colors.orange,
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
