import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:work_hours/salary.dart';
import 'dart:async';
import 'config.dart';
import 'home.dart';
import 'history.dart';
import 'summary.dart';
import 'settings.dart';
import 'hive_db.dart';
import 'permissions.dart';
import 'notification_service.dart';
import 'package:flutter/services.dart';

// Function to format duration for the widget

// Function to debug widget state
Future<void> debugWidgetState() async {
  try {
    debugPrint('🔍 [WIDGET_DEBUG] Checking widget state...');
    
    // Check widget page value
    final widgetPage = await HomeWidget.getWidgetData<dynamic>('_widgetPage');
    debugPrint('🔍 [WIDGET_DEBUG] Widget page: $widgetPage (${widgetPage?.runtimeType})');
    
    // Check clock in/out text values
    final clockInText = await HomeWidget.getWidgetData<String>('_clockInText');
    final clockOutText = await HomeWidget.getWidgetData<String>('_clockOutText');
    debugPrint('🔍 [WIDGET_DEBUG] Clock in text: $clockInText');
    debugPrint('🔍 [WIDGET_DEBUG] Clock out text: $clockOutText');
    
    // Check overtime values
    final overtimeText = await HomeWidget.getWidgetData<String>('_overtimeText');
    debugPrint('🔍 [WIDGET_DEBUG] Overtime text: $overtimeText');
    
    // Get native widget information
    const methodChannel = MethodChannel('com.example.work_hours/widget');
    try {
      final Map<dynamic, dynamic> widgetInfo = 
          await methodChannel.invokeMethod('getWidgetInfo');
      
      debugPrint('🔍 [WIDGET_DEBUG] Widget count: ${widgetInfo['widgetCount']}');
      debugPrint('🔍 [WIDGET_DEBUG] Settings mode: ${widgetInfo['isSettingsMode']}');
      debugPrint('🔍 [WIDGET_DEBUG] Widget IDs: ${widgetInfo['widgetIds']}');
    } catch (e) {
      debugPrint('⚠️ [WIDGET_DEBUG] Could not get native widget info: $e');
    }
    
    debugPrint('✅ [WIDGET_DEBUG] Widget state check complete');
  } catch (e) {
    debugPrint('❌ [WIDGET_DEBUG] Error checking widget state: $e');
  }
}

// Renamed callback for clarity with interactivity
@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri == null) return;

  debugPrint('🔍 [WIDGET_DEBUG] Interactive callback received URI: $uri');

  // Handle widget actions based on the URI host
  if (uri.host == 'clock_in') {
    try {
      // Ensure Hive is initialized if coming from background
      debugPrint('🔍 [WIDGET_DEBUG] Initializing Hive for clock_in widget action');
      await Hive.initFlutter(); // Might need path_provider setup for background
      await Hive.openBox('work_hours');
      await Hive.openBox('settings');

      await HiveDb.clockIn(DateTime.now());
      debugPrint('✅ [WIDGET_DEBUG] Clocked in via widget callback');
      // Trigger an update AFTER the action

      await HiveDb.updateWidget();
    } catch (e) {
      debugPrint('❌ [WIDGET_DEBUG] Error clocking in via widget callback: $e');
    }
  } else if (uri.host == 'clock_out') {
    try {
      // Ensure Hive is initialized
      debugPrint('🔍 [WIDGET_DEBUG] Initializing Hive for clock_out widget action');
      await Hive.initFlutter();
      await Hive.openBox('work_hours');
      await Hive.openBox('settings');

      final now = DateTime.now();
      final todayEntry = HiveDb.getDayEntry(now);
      debugPrint('🔍 [WIDGET_DEBUG] Today entry for clock_out: ${todayEntry != null ? 'found' : 'not found'}');
      
      if (todayEntry != null &&
          todayEntry['in'] != null &&
          todayEntry['out'] == null) {
        final clockInTime = DateTime.parse(todayEntry['in'] as String);
        debugPrint('🔍 [WIDGET_DEBUG] Found clock-in time: $clockInTime, clocking out now');
        await HiveDb.clockOut(now, clockInTime);
        debugPrint('✅ [WIDGET_DEBUG] Clocked out via widget callback');
        // Trigger an update AFTER the action
        await HiveDb.updateWidget();
      } else {
        debugPrint(
            '⚠️ [WIDGET_DEBUG] Cannot clock out via widget callback: Not clocked in or already clocked out.');
      }
    } catch (e) {
      debugPrint('❌ [WIDGET_DEBUG] Error clocking out via widget callback: $e');
    }
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Home Widget with more debugging
    debugPrint('📱 [WIDGET_DEBUG] Initializing Home Widget...');
    // Set App Group ID
    await HomeWidget.setAppGroupId('group.com.example.work_hours');
    debugPrint('📱 [WIDGET_DEBUG] App Group ID set');
    // Register the INTERACTIVITY callback
    await HomeWidget.registerInteractivityCallback(interactiveCallback);
    debugPrint('📱 [WIDGET_DEBUG] Interactivity callback registered');

    // Set up method channel for direct widget actions
    const actionChannel = MethodChannel('com.example.work_hours/actions');
    actionChannel.setMethodCallHandler((call) async {
      debugPrint('🔍 [WIDGET_DEBUG] Received action method call: ${call.method}');
      
      if (call.method == 'clockIn') {
        debugPrint('🔍 [WIDGET_DEBUG] Processing clock-in action from method channel');
        await Hive.initFlutter(); // Ensure Hive is initialized
        await Hive.openBox('work_hours');
        await Hive.openBox('settings');
        
        await HiveDb.clockIn(DateTime.now());
        await HiveDb.updateWidget();
        debugPrint('✅ [WIDGET_DEBUG] Completed clock-in via method channel');
      } else if (call.method == 'clockOut') {
        debugPrint('🔍 [WIDGET_DEBUG] Processing clock-out action from method channel');
        await Hive.initFlutter();
        await Hive.openBox('work_hours');
        await Hive.openBox('settings');
        
        final now = DateTime.now();
        final todayEntry = HiveDb.getDayEntry(now);
        if (todayEntry != null && todayEntry['in'] != null && todayEntry['out'] == null) {
          final clockInTime = DateTime.parse(todayEntry['in'] as String);
          await HiveDb.clockOut(now, clockInTime);
          await HiveDb.updateWidget();
          debugPrint('✅ [WIDGET_DEBUG] Completed clock-out via method channel');
        } else {
          debugPrint('⚠️ [WIDGET_DEBUG] Cannot clock out: Not clocked in or already clocked out');
        }
      }
      
      return null;
    });

    // Pre-initialize widget data
    debugPrint('🔍 [WIDGET_DEBUG] Setting default widget data values');
    await HomeWidget.saveWidgetData<String>('_clockInText', 'In: --:--');
    await HomeWidget.saveWidgetData<String>('_clockOutText', 'Out: --:--');
    await HomeWidget.saveWidgetData<String>('_overtimeText', 'Overtime: 0h 0m');
    await HomeWidget.saveWidgetData<int>('_widgetPage', 0);
    
    // Force exit settings mode in case widgets are stuck
    const methodChannel = MethodChannel('com.example.work_hours/widget');
    try {
      debugPrint('🔍 [WIDGET_DEBUG] Forcing widgets to exit settings mode');
      await methodChannel.invokeMethod('exitSettingsMode');
      debugPrint('✅ [WIDGET_DEBUG] Successfully exited widget settings mode');
    } catch (e) {
      debugPrint('⚠️ [WIDGET_DEBUG] Could not exit settings mode: $e');
    }
    
    debugPrint('📱 [WIDGET_DEBUG] Default widget data initialized');

    // Send explicit update to the widget
    debugPrint('🔍 [WIDGET_DEBUG] Sending initial widget update');
    await HomeWidget.updateWidget(
      name: 'MyHomeWidgetProvider',
      androidName: 'MyHomeWidgetProvider',
      iOSName: 'MyHomeWidgetProvider',
    );
    debugPrint('📱 [WIDGET_DEBUG] Initial widget update sent');

    tz.initializeTimeZones();
    await Hive.initFlutter(); // Ensure this is called before accessing Hive
    await Future.wait([
      Hive.openBox('work_hours'),
      Hive.openBox('settings'),
    ]);
    debugPrint('📱 [WIDGET_DEBUG] Hive boxes opened successfully');

    // Set up widget event channel
    const EventChannel eventChannel = EventChannel('widget_events');
    debugPrint('🔍 [WIDGET_DEBUG] Setting up widget event channel');
    eventChannel.receiveBroadcastStream().listen((dynamic event) {
      debugPrint('🔍 [WIDGET_DEBUG] Received widget event: $event');
      if (event == 'clock_in') {
        debugPrint('🔍 [WIDGET_DEBUG] Processing clock_in event from channel');
        HiveDb.clockIn(DateTime.now());
      } else if (event == 'clock_out') {
        debugPrint('🔍 [WIDGET_DEBUG] Processing clock_out event from channel');
        final now = DateTime.now();
        final todayEntry = HiveDb.getDayEntry(now);
        if (todayEntry != null && todayEntry['in'] != null && todayEntry['out'] == null) {
          final clockInTime = DateTime.parse(todayEntry['in'] as String);
          HiveDb.clockOut(now, clockInTime);
        }
      }
    });

    runApp(const MyApp());

    // await _checkInitialPermissions();
    await NotificationService.initialize();
    await NotificationService.scheduleNotifications();

    // Check widget state before update
    await debugWidgetState();

    // Update widget with real data after app start
    debugPrint('📱 [WIDGET_DEBUG] Updating widget with real data...');
    await HiveDb.updateWidget();
    await HiveDb.updateWidgetWithOvertimeInfo();
    debugPrint('📱 [WIDGET_DEBUG] Widget updated with real data');
    
    // Check widget state after update
    await debugWidgetState();
    
    // Schedule periodic widget state checks
    Timer.periodic(const Duration(minutes: 5), (_) async {
      debugPrint('🕒 [WIDGET_DEBUG] Running periodic widget state check');
      await debugWidgetState();
    });
    
  } catch (e, stackTrace) {
    debugPrint('❌ [WIDGET_DEBUG] Error during initialization: $e');
    debugPrint('❌ [WIDGET_DEBUG] Stack trace: $stackTrace');
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
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const HistoryPage(),
    const SummaryPage(),
    const SalaryPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;

    final permissionsGranted =
        await PermissionService.checkAndRequestPermissions(context);
    if (!permissionsGranted && mounted) {
      NotificationUtil.showWarning(
          context,
          'Some features may not work without the required permissions.');
    }
  }

  void onItemTapped(int index) {
    setState(() {
      if (index == 2) {
        _pages[2] = SummaryPage(key: UniqueKey());
      }
      _selectedIndex = index;
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
              onTap: onItemTapped,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.access_time), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.history), label: 'History'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.assessment), label: 'Summary'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.attach_money_rounded), label: 'Salary'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
