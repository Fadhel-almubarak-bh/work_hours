import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/work_hours_repository.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SettingsController(
        context.read<WorkHoursRepository>(),
      ),
      child: const SettingsScreen(),
    );
  }
}
