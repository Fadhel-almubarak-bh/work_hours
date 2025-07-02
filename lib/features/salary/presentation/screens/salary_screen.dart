import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../salary_controller.dart';
import '../widgets/salary_widgets.dart';
import 'dart:math' as math;

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<SalaryController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await context.read<SalaryController>().loadCurrentMonthSalary();
              await context.read<SalaryController>().loadMonthlyHistory();
            },
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: Consumer<SalaryController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentSalary = controller.currentMonthSalary;
          final lastMonthSalary = controller.selectedMonthSalary;
          if (currentSalary == null) {
            return const Center(child: Text('No salary data available'));
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildTodayEarningsCard(controller, currentSalary),
              const SizedBox(height: 16),
              _buildCurrentMonthCard(controller, currentSalary),
              const SizedBox(height: 16),
              _buildLastMonthCard(controller, lastMonthSalary),
              const SizedBox(height: 16),
              _buildMonthlyComparisonChart(controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodayEarningsCard(SalaryController controller, Map<String, dynamic> currentSalary) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                controller.formatCurrency(currentSalary['todayEarnings'] as double),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Based on ${controller.formatDuration(currentSalary['todayMinutes'] as int)} worked today',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMonthCard(SalaryController controller, Map<String, dynamic> currentSalary) {
    final totalEarnings = currentSalary['totalEarnings'] as double;
    final monthlySalary = currentSalary['monthlySalary'] as double;
    final progress = (totalEarnings / monthlySalary).clamp(0.0, 1.0);
    final overtimePay = currentSalary['overtimePay'] as double;
    final workDaysEarnings = currentSalary['workDaysEarnings'] as double;
    final offDaysEarnings = (currentSalary['offDaysCount'] as int) * (currentSalary['dailyRate'] as double);

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
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current Month \n(${controller.getCurrentMonthName()})',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: overtimePay > 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: overtimePay > 0
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    overtimePay > 0 ? 'With Overtime' : 'Regular Hours',
                    style: TextStyle(
                      color: overtimePay > 0 ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Main Earnings Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Earnings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.formatCurrency(totalEarnings),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: progress >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% of Monthly Target',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Earnings Breakdown
            Text(
              'Earnings Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEarningsItem(
                    'Work Days',
                    controller.formatCurrency(workDaysEarnings),
                    Icons.work_outline,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEarningsItem(
                    'Off Days',
                    controller.formatCurrency(offDaysEarnings),
                    Icons.event_busy_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEarningsItem(
                    'Overtime',
                    controller.formatCurrency(overtimePay),
                    Icons.timer_outlined,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Additional Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Monthly Salary',
                    controller.formatCurrency(monthlySalary),
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Daily Rate',
                    controller.formatCurrency(currentSalary['dailyRate'] as double),
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Hourly Rate',
                    '${controller.formatCurrency(currentSalary['hourlyRate'] as double)}/hour',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'After Insurance',
                    controller.formatCurrency(currentSalary['earningsAfterInsurance'] as double),
                    isHighlighted: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: isHighlighted ? Theme.of(context).colorScheme.primary : Colors.grey[700],
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: TextStyle(
              color: isHighlighted ? Theme.of(context).colorScheme.primary : Colors.grey[700],
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLastMonthCard(SalaryController controller, Map<String, dynamic>? lastMonthSalary) {
    if (lastMonthSalary == null) {
      return const SizedBox.shrink();
    }

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
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Last Month Summary',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (lastMonthSalary['overtimePay'] as double) > 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (lastMonthSalary['overtimePay'] as double) > 0
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    (lastMonthSalary['overtimePay'] as double) > 0 ? 'With Overtime' : 'Regular Hours',
                    style: TextStyle(
                      color: (lastMonthSalary['overtimePay'] as double) > 0 ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLastMonthPieChart(lastMonthSalary),
            const SizedBox(height: 24),
            _buildLastMonthBreakdown(controller, lastMonthSalary),
          ],
        ),
      ),
    );
  }

  Widget _buildLastMonthPieChart(Map<String, dynamic> salary) {
    final workDaysEarnings = salary['workDaysEarnings'] as double;
    final offDaysEarnings = (salary['offDaysCount'] as int) * (salary['dailyRate'] as double);
    final overtimePay = salary['overtimePay'] as double;

    final List<ChartData> pieData = [
      ChartData('Work Days', workDaysEarnings, Theme.of(context).colorScheme.primary),
      ChartData('Off Days', offDaysEarnings, Colors.blue),
      ChartData('Overtime', overtimePay, Colors.green),
    ];

    return SizedBox(
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
    );
  }

  Widget _buildLastMonthBreakdown(SalaryController controller, Map<String, dynamic> salary) {
    return Column(
      children: [
        _buildSalaryInfoRow(
          'Total Earnings:',
          controller.formatCurrency(salary['totalEarnings'] as double),
          primary: true,
          textColor: Colors.green,
        ),
        const SizedBox(height: 8),
        _buildSalaryInfoRow(
          'Work Days:',
          '${salary['workDaysCount']} days',
        ),
        const SizedBox(height: 8),
        _buildSalaryInfoRow(
          'Off Days:',
          '${salary['offDaysCount']} days',
        ),
        const SizedBox(height: 8),
        _buildSalaryInfoRow(
          'Hours Worked:',
          controller.formatDuration(salary['actualMinutes'] as int),
        ),
        const SizedBox(height: 8),
        _buildSalaryInfoRow(
          'Overtime Hours:',
          controller.formatDuration((salary['overtimeMinutes'] as int).abs()),
          textColor: (salary['overtimeMinutes'] as int) > 0 ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildMonthlyComparisonChart(SalaryController controller) {
    final monthlyHistory = controller.monthlyHistory;
    if (monthlyHistory.isEmpty) {
      return const SizedBox.shrink();
    }

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
                Expanded(
                  child: Text(
                    'Monthly Earnings Trend',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Last 12 Months',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: monthlyHistory.fold<double>(
                    0,
                    (max, entry) => math.max(
                      max,
                      (entry['salary'] as Map<String, dynamic>)['totalEarnings'] as double,
                    ),
                  ),
                  barGroups: monthlyHistory.asMap().entries.map((entry) {
                    final salary = entry.value['salary'] as Map<String, dynamic>;
                    final date = entry.value['month'] as DateTime;
                    final earnings = salary['totalEarnings'] as double;
                    final monthlySalary = salary['monthlySalary'] as double;
                    final progress = (earnings / monthlySalary).clamp(0.0, 1.0);

                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: earnings,
                          color: progress >= 1.0
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= monthlyHistory.length) return const Text('');
                          final date = monthlyHistory[value.toInt()]['month'] as DateTime;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              // '${date.month}/${date.year.toString().substring(2)}',
                              '${date.month.toString()}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              controller.formatCurrency(value),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
                    horizontalInterval: math.max(
                      monthlyHistory.fold<double>(
                        0,
                        (max, entry) => math.max(
                          max,
                          (entry['salary'] as Map<String, dynamic>)['totalEarnings'] as double,
                        ),
                      ) / 5,
                      1.0, // Ensure minimum interval of 1.0
                    ),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Theme.of(context).colorScheme.primary, 'Regular'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.green, 'Above Target'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
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
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: primary
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: primary
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textColor ?? Theme.of(context).colorScheme.primary,
                    )
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Data model for pie chart
class ChartData {
  final String x;
  final double y;
  final Color color;

  ChartData(this.x, this.y, this.color);
}
