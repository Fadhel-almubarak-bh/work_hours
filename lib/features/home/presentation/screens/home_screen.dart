import 'package:flutter/material.dart';
import '../../../salary/presentation/screens/salary_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../../data/repositories/work_hours_repository.dart';
import 'package:provider/provider.dart';
import 'work_hours_screen.dart';
import '../../../summary/presentation/screens/summary_screen.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../home_controller.dart';
import '../../../../data/local/hive_db.dart';
import 'package:hive/hive.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const WorkHoursScreen(),
    const HistoryScreen(),
    const SummaryScreen(),
    const SalaryScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  Future<void> _initializeRepository() async {
    final repository = context.read<WorkHoursRepository>();
    await repository.initialize();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveDb.getWorkHoursListenable(),
      builder: (context, Box workHours, _) {
        return ValueListenableBuilder(
          valueListenable: HiveDb.getSettingsListenable(),
          builder: (context, Box settings, _) {
            return Scaffold(
              body: _pages[_selectedIndex],
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.summarize),
                    label: 'Summary',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.attach_money),
                    label: 'Salary',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
