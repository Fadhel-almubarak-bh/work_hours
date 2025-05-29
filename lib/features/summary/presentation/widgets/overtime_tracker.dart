import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/intl.dart';
import '../../../../data/local/hive_db.dart';

class OvertimeTracker extends StatelessWidget {
  const OvertimeTracker({super.key});

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    // Get the accurate overtime using our new method
    final currentMonthOvertimeMinutes = HiveDb.getMonthlyOvertime();
    final dailyTarget = HiveDb.getDailyTargetMinutes();

    // Convert to hours for better readability
    final overtimeHours = currentMonthOvertimeMinutes / 60.0;
    final maxGaugeValue = dailyTarget / 30.0; // About one day's worth in either direction

    // Determine the gauge values and colors
    double gaugeValue = overtimeHours.abs().clamp(0.0, maxGaugeValue);
    double percentage = (gaugeValue / maxGaugeValue) * 100;

    final isAhead = currentMonthOvertimeMinutes >= 0;
    final displayValue = _formatDuration(currentMonthOvertimeMinutes.abs());
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
                    Text('Expected Hours: ${configuredWorkDaysThisMonth * dailyTarget ~/ 60}h',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('($configuredWorkDaysThisMonth days × ${dailyTarget ~/ 60}h)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Required Days: $configuredWorkDaysThisMonth',
                        style: TextStyle(fontSize: 13)),
                    Text('Missed Days: $missedWorkDays',
                        style: TextStyle(fontSize: 13, color: Colors.red)),
                    Text('Daily Target: ${_formatDuration(dailyTarget)}',
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
} 