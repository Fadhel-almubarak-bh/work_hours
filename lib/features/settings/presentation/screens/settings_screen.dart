import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../settings_controller.dart';
import '../widgets/settings_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<SettingsController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.loadSettings(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final settings = controller.settings;
          if (settings == null) {
            return const Center(child: Text('No settings available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Salary Settings
                SettingsCard(
                  title: 'Salary Settings',
                  child: Column(
                    children: [
                      CurrencyTextField(
                        label: 'Monthly Salary',
                        value: settings.monthlySalary,
                        onChanged: controller.updateMonthlySalary,
                      ),
                      const SizedBox(height: 16),
                      HoursTextField(
                        label: 'Daily Target Hours',
                        value: settings.dailyTargetHours,
                        onChanged: controller.updateDailyTargetHours,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Work Days
                SettingsCard(
                  title: 'Work Days',
                  child: WorkDaysSelector(
                    workDays: settings.workDays,
                    onChanged: controller.updateWorkDays,
                  ),
                ),
                const SizedBox(height: 16),

                // Currency and Rates
                SettingsCard(
                  title: 'Currency and Rates',
                  child: Column(
                    children: [
                      CurrencySelector(
                        value: settings.currency,
                        onChanged: controller.updateCurrency,
                      ),
                      const SizedBox(height: 16),
                      PercentageSlider(
                        label: 'Insurance Rate',
                        value: settings.insuranceRate,
                        onChanged: (value) => controller.updateInsuranceRate(value),
                      ),
                      const SizedBox(height: 16),
                      PercentageSlider(
                        label: 'Overtime Rate',
                        value: settings.overtimeRate,
                        onChanged: (value) => controller.updateOvertimeRate(value),
                        isOvertime: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Summary Card
                SettingsCard(
                  title: 'Summary',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryRow(
                        'Monthly Salary',
                        controller.formatCurrency(settings.monthlySalary),
                      ),
                      _buildSummaryRow(
                        'Daily Rate',
                        controller.formatCurrency(
                          settings.monthlySalary / 20, // Assuming 20 work days
                        ),
                      ),
                      _buildSummaryRow(
                        'Hourly Rate',
                        controller.formatCurrency(
                          settings.monthlySalary / (20 * settings.dailyTargetHours),
                        ),
                      ),
                      _buildSummaryRow(
                        'Insurance Rate',
                        controller.formatPercentage(settings.insuranceRate),
                      ),
                      _buildSummaryRow(
                        'Overtime Rate',
                        controller.formatPercentage(settings.overtimeRate),
                      ),
                    ],
                  ),
                ),
              ],
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
