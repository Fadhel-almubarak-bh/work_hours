import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'config.dart';
import 'home.dart';
import 'history.dart';
import 'summary.dart';
import 'settings.dart';
import 'hive_db.dart';
import 'permissions.dart';
import 'notification_service.dart';

// Function to format duration for the widget
String _formatDurationForWidget(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h ${minutes}m';
}

// Renamed callback for clarity with interactivity
@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri == null) return;

  debugPrint('Interactive callback received URI: ${uri}');

  // Handle widget actions based on the URI host
  if (uri.host == 'clock_in') {
    try {
      // Ensure Hive is initialized if coming from background
      await Hive.initFlutter(); // Might need path_provider setup for background
      await Hive.openBox('work_hours');
      await Hive.openBox('settings');
      
      await HiveDb.clockIn(DateTime.now());
      debugPrint('Clocked in via widget callback');
      // Trigger an update AFTER the action
      await HiveDb.updateWidget(); 
    } catch (e) {
      debugPrint('Error clocking in via widget callback: $e');
    }
  } else if (uri.host == 'clock_out') {
    try {
      // Ensure Hive is initialized
      await Hive.initFlutter(); 
      await Hive.openBox('work_hours');
      await Hive.openBox('settings');
      
      final now = DateTime.now();
      final todayEntry = HiveDb.getDayEntry(now);
      if (todayEntry != null && todayEntry['in'] != null && todayEntry['out'] == null) {
        final clockInTime = DateTime.parse(todayEntry['in'] as String);
        await HiveDb.clockOut(now, clockInTime);
        debugPrint('Clocked out via widget callback');
        // Trigger an update AFTER the action
        await HiveDb.updateWidget(); 
      } else {
        debugPrint('Cannot clock out via widget callback: Not clocked in or already clocked out.');
      }
    } catch (e) {
      debugPrint('Error clocking out via widget callback: $e');
    }
  }
  // Potentially handle the updatewidget host if needed for simple refresh?
  // else if (uri.host == 'updatewidget') { ... }
}

Future<void> _checkInitialPermissions() async {
  try {
    final permissionsGranted = await PermissionService.checkAndRequestPermissions(
      // We can't use context here as the app isn't built yet
      // Permissions will be checked again in MainPage
      null,
    );
    if (!permissionsGranted) {
      debugPrint('Some permissions were not granted during initialization');
    }
  } catch (e) {
    debugPrint('Error checking permissions: $e');
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // Set App Group ID
    await HomeWidget.setAppGroupId('group.com.example.work_hours');
    // Register the INTERACTIVITY callback
    HomeWidget.registerInteractivityCallback(interactiveCallback);
    
    tz.initializeTimeZones();
    await Hive.initFlutter(); // Ensure this is called before accessing Hive
    await Future.wait([
      Hive.openBox('work_hours'),
      Hive.openBox('settings'),
    ]);

    runApp(const MyApp());

    await _checkInitialPermissions();
    await NotificationService.initialize();
    await NotificationService.scheduleNotifications();
    
    // Initial widget update on app start
    await HiveDb.updateWidget();
    
  } catch (e) {
    debugPrint('Error during initialization: $e');
    // Show error UI instead of crashing
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Error initializing app: $e'),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveDb.getSettingsListenable(),
      builder: (context, Box settings, _) {
        final isDarkMode = HiveDb.getIsDarkMode();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Work Hours Tracker',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainPage(),
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _isDarkMode = false;
  final List<Widget> _pages = [
    const HomePage(),
    const HistoryPage(),
    const SummaryPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;

    final permissionsGranted = await PermissionService.checkAndRequestPermissions(context);
    if (!permissionsGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some features may not work without the required permissions.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      if (index == 2) {
        _pages[2] = SummaryPage(key: UniqueKey());
      }
      _selectedIndex = index;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
                BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Summary'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
