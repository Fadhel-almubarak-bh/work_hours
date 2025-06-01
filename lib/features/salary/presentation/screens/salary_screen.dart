import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../salary_controller.dart';
import '../widgets/salary_widgets.dart';

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
          if (currentSalary == null) {
            return const Center(child: Text('No salary data available'));
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
                            'Current Month (${controller.getCurrentMonthName()})',
                              style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                            ),
                            const SizedBox(height: 16),
                      _buildSalaryInfoRow(
                        'Monthly Salary:',
                        controller.formatCurrency(currentSalary['monthlySalary'] as double),
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Expected Hours:',
                        '${currentSalary['expectedHours']} hours (${currentSalary['workDaysCount']} days × ${currentSalary['dailyHours']}h)',
                            ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Off Days (Excused):',
                        '${currentSalary['offDaysCount']} days',
                        textColor: Colors.grey[600],
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Weekends:',
                        '${currentSalary['nonWorkingDaysCount']} days',
                        textColor: Colors.grey[600],
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Total Days Off:',
                        '${currentSalary['totalDaysOff']} days',
                        textColor: Theme.of(context).colorScheme.primary,
                        primary: true,
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Daily Rate:',
                        controller.formatCurrency(currentSalary['dailyRate'] as double),
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Hourly Rate:',
                        '${controller.formatCurrency(currentSalary['hourlyRate'] as double)}/hour',
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Overtime Pay:',
                        controller.formatCurrency(currentSalary['overtimePay'] as double),
                        textColor: (currentSalary['overtimePay'] as double) > 0 ? Colors.green : null,
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Off Days Earnings:',
                        controller.formatCurrency((currentSalary['offDaysCount'] as int) * (currentSalary['dailyRate'] as double)),
                        textColor: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Earnings from Work Days:',
                        controller.formatCurrency(currentSalary['workDaysEarnings'] as double),
                        primary: true,
                        textColor: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Total Earnings:',
                        controller.formatCurrency(currentSalary['totalEarnings'] as double),
                        primary: true,
                        textColor: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'After Insurance (92%):',
                        controller.formatCurrency(currentSalary['earningsAfterInsurance'] as double),
                        textColor: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Hours Worked:',
                        controller.formatDuration(currentSalary['actualMinutes'] as int),
                      ),
                      const SizedBox(height: 8),
                      _buildSalaryInfoRow(
                        'Hours Left to Do:',
                                controller.formatDuration(
                          (currentSalary['expectedMinutes'] as int) - (currentSalary['actualMinutes'] as int),
                                ),
                        textColor: ((currentSalary['expectedMinutes'] as int) - (currentSalary['actualMinutes'] as int)) < 0 
                            ? Colors.green 
                            : Colors.orange,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
