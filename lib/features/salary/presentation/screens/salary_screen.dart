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
      ),
      body: Consumer<SalaryController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentSalary = controller.currentMonthSalary;
          final selectedSalary = controller.selectedMonthSalary;
          final isCurrentMonth = controller.selectedMonth.year == DateTime.now().year &&
              controller.selectedMonth.month == DateTime.now().month;

          return RefreshIndicator(
            onRefresh: () async {
              await controller.loadCurrentMonthSalary();
              await controller.loadMonthlyHistory();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month selector
                  MonthSelector(
                    selectedMonth: controller.selectedMonth,
                    onMonthSelected: controller.selectMonth,
                  ),
                  const SizedBox(height: 24),

                  // Hours progress gauge
                  if (selectedSalary != null) ...[
                    SizedBox(
                      height: 200,
                      child: HoursProgressGauge(
                        actualMinutes: selectedSalary['actualMinutes'] as int,
                        expectedMinutes: selectedSalary['expectedMinutes'] as int,
                        label: 'Hours Progress',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Salary cards
                  if (selectedSalary != null) ...[
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        SalaryCard(
                          title: 'Total Earnings',
                          value: controller.formatCurrency(
                            selectedSalary['totalEarnings'] as double,
                          ),
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                        SalaryCard(
                          title: 'After Insurance',
                          value: controller.formatCurrency(
                            selectedSalary['earningsAfterInsurance'] as double,
                          ),
                          icon: Icons.health_and_safety,
                          color: Colors.blue,
                        ),
                        SalaryCard(
                          title: 'Overtime Pay',
                          value: controller.formatCurrency(
                            selectedSalary['overtimePay'] as double,
                          ),
                          icon: Icons.timer,
                          color: Colors.orange,
                        ),
                        SalaryCard(
                          title: 'Daily Rate',
                          value: controller.formatCurrency(
                            selectedSalary['dailyRate'] as double,
                          ),
                          icon: Icons.calendar_today,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Monthly history chart
                  if (controller.monthlyHistory.isNotEmpty) ...[
                    Text(
                      'Monthly History',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    MonthlySalaryChart(
                      monthlyData: controller.monthlyHistory,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Work days summary
                  if (selectedSalary != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Work Days Summary',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            _buildSummaryRow(
                              'Expected Work Days',
                              selectedSalary['expectedWorkDays'].toString(),
                            ),
                            _buildSummaryRow(
                              'Off Days',
                              selectedSalary['offDaysCount'].toString(),
                            ),
                            _buildSummaryRow(
                              'Hours Worked',
                              controller.formatDuration(
                                selectedSalary['actualMinutes'] as int,
                              ),
                            ),
                            if (selectedSalary['overtimeMinutes'] as int > 0)
                              _buildSummaryRow(
                                'Overtime Hours',
                                controller.formatDuration(
                                  selectedSalary['overtimeMinutes'] as int,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
