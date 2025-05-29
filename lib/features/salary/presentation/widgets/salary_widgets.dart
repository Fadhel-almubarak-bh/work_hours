import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/intl.dart';

class SalaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const SalaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class HoursProgressGauge extends StatelessWidget {
  final int actualMinutes;
  final int expectedMinutes;
  final String label;

  const HoursProgressGauge({
    super.key,
    required this.actualMinutes,
    required this.expectedMinutes,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = expectedMinutes > 0 
        ? (actualMinutes / expectedMinutes * 100.0).clamp(0.0, 100.0) 
        : 0.0;

    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 100,
          showLabels: false,
          showTicks: false,
          axisLineStyle: const AxisLineStyle(
            thickness: 0.2,
            color: Colors.grey,
            thicknessUnit: GaugeSizeUnit.factor,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: percentage,
              width: 0.2,
              sizeUnit: GaugeSizeUnit.factor,
              color: _getColorForPercentage(percentage),
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage < 50) return Colors.red;
    if (percentage < 80) return Colors.orange;
    if (percentage < 100) return Colors.blue;
    return Colors.green;
  }
}

class MonthlySalaryChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthlyData;

  const MonthlySalaryChart({
    super.key,
    required this.monthlyData,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: monthlyData.asMap().entries.map((entry) {
                final salary = entry.value['salary'] as Map<String, dynamic>;
                return FlSpot(
                  entry.key.toDouble(),
                  (salary['totalEarnings'] as double) / 1000, // Convert to thousands
                );
              }).toList(),
              isCurved: true,
              color: Theme.of(context).primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final Function(DateTime) onMonthSelected;

  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final newMonth = DateTime(
              selectedMonth.year,
              selectedMonth.month - 1,
              1,
            );
            onMonthSelected(newMonth);
          },
        ),
        Text(
          DateFormat('MMMM yyyy').format(selectedMonth),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final newMonth = DateTime(
              selectedMonth.year,
              selectedMonth.month + 1,
              1,
            );
            if (newMonth.isBefore(DateTime.now())) {
              onMonthSelected(newMonth);
            }
          },
        ),
      ],
    );
  }
}
