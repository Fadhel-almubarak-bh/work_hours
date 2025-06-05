import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../settings_controller.dart';
import '../widgets/settings_widgets.dart';
import '../../../../data/local/hive_db.dart';
import '../../../../core/constants/app_constants.dart';

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
                // Theme Selection
                SettingsCard(
                  title: 'Theme',
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('System'),
                        value: ThemeMode.system,
                        groupValue: settings.themeMode,
                        onChanged: (mode) => controller.updateThemeMode(mode, context),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Light'),
                        value: ThemeMode.light,
                        groupValue: settings.themeMode,
                        onChanged: (mode) => controller.updateThemeMode(mode, context),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Dark'),
                        value: ThemeMode.dark,
                        groupValue: settings.themeMode,
                        onChanged: (mode) => controller.updateThemeMode(mode, context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Salary Settings
                SettingsCard(
                  title: 'Salary Settings',
                  child: Column(
                    children: [
                      CurrencyTextField(
                        label: 'Monthly Salary',
                        value: settings.monthlySalary,
                        onChanged: controller.updateMonthlySalary,
                        currency: settings.currency,
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
                      PercentageTextField(
                        label: 'Insurance Rate',
                        value: settings.insuranceRate,
                        onChanged: (value) => controller.updateInsuranceRate(value),
                      ),
                      const SizedBox(height: 16),
                      PercentageTextField(
                        label: 'Overtime Rate',
                        value: settings.overtimeRate,
                        onChanged: (value) => controller.updateOvertimeRate(value),
                        isOvertime: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Data Management
                SettingsCard(
                  title: 'Data Management',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export your work hours data to Excel or import from a backup.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => controller.exportDataToExcel(context),
                              icon: const Icon(Icons.save_alt, color: Colors.white),
                              label: const Text('Export'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => controller.importDataFromExcel(context),
                              icon: const Icon(Icons.upload_file, color: Colors.white),
                              label: const Text('Import'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Debug Information
                SettingsCard(
                  title: 'Debug Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View detailed debug information about the app\'s state and data.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => controller.printDebugInfo(context),
                              icon: const Icon(Icons.bug_report, color: Colors.white),
                              label: const Text('Show Debug Info'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => controller.printSalaryDebugInfo(context),
                              icon: const Icon(Icons.attach_money, color: Colors.white),
                              label: const Text('Salary Debug'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => controller.printSummaryDebugInfo(context),
                              icon: const Icon(Icons.summarize, color: Colors.white),
                              label: const Text('Summary Debug'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
