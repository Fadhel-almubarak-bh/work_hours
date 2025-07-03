import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io';
import '../data/repositories/work_hours_repository.dart';
import '../data/models/work_entry.dart';
import '../data/models/settings.dart';
import '../features/settings/settings_controller.dart';
import '../features/salary/salary_controller.dart';
import '../features/home/home_controller.dart';
import '../features/history/history_controller.dart';
import '../features/summary/summary_controller.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../services/windows_tray_service.dart';
import 'theme/theme.dart';
import '../data/local/hive_db.dart';
import 'package:path_provider/path_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  static WorkHoursRepository? _repository;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Initialize Hive with the same path as background callback
    final dir = await getApplicationDocumentsDirectory();
    final hivePath = '${dir.path}/hive';
    Hive.init(hivePath);
    debugPrint('[main_app] Initializing Hive at: $hivePath');
    
    // Register Hive adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SettingsAdapter());
    }
    
    // Open Hive boxes
    await Hive.openBox('work_entries');
    await Hive.openBox('settings');
    
    // Initialize repository
    _repository = WorkHoursRepository();
    await _repository!.initialize();

    // Initialize services
    await NotificationService.initialize();
    
    // Initialize platform-specific services
    if (Platform.isWindows) {
      await WindowsTrayService.initialize();
    } else if (Platform.isAndroid || Platform.isIOS) {
      await WidgetService.initialize();
      // Test widget functionality
      await WidgetService.testWidgetFunctionality();
      // Initialize widget with overtime and remaining data
      await HiveDb.updateWidgetWithOvertimeInfo();
    }
    
    _isInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WorkHoursRepository>(
          create: (context) => _repository!,
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (context) => SettingsController(
            context.read<WorkHoursRepository>(),
          ),
        ),
        ChangeNotifierProvider<SalaryController>(
          create: (context) => SalaryController(
            context.read<WorkHoursRepository>(),
          ),
        ),
        ChangeNotifierProvider<HomeController>(
          create: (context) => HomeController(
            context.read<WorkHoursRepository>(),
          ),
        ),
        ChangeNotifierProvider<HistoryController>(
          create: (context) => HistoryController(
            context.read<WorkHoursRepository>(),
          ),
        ),
        ChangeNotifierProvider<SummaryController>(
          create: (context) => SummaryController(
            context.read<WorkHoursRepository>(),
          ),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) => ThemeProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Work Hours',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

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
    
    debugPrint('✅ [WIDGET_DEBUG] Widget state check complete');
  } catch (e) {
    debugPrint('❌ [WIDGET_DEBUG] Error checking widget state: $e');
  }
}

// Widget callback for background actions
@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri == null) return;

  debugPrint('[home_widget] Interactive callback received URI: $uri');

  try {
    // Set Hive directory for background isolate - use the same as main app
    final dir = await getApplicationDocumentsDirectory();
    final hivePath = '${dir.path}/hive';
    Hive.init(hivePath);

    debugPrint('[home_widget] Initializing Hive for widget action at: $hivePath');
    
    // Ensure we're using the same box instance as the main app
    if (!Hive.isBoxOpen('work_entries')) {
      await Hive.openBox('work_entries');
    }
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox('settings');
    }
    
    // Handle widget actions based on the URI host
    if (uri.host == 'clock_in_out') {
      debugPrint('[home_widget] Processing clock in/out action via background callback');
      
      // Check current status
      final isClockedIn = HiveDb.isClockedIn();
      debugPrint('[home_widget] Current status - isClockedIn: $isClockedIn');
      
      if (isClockedIn) {
        // Clock out
        debugPrint('[home_widget] Attempting to clock out');
        await HiveDb.clockOut(DateTime.now());
        debugPrint('[home_widget] ✅ Successfully clocked out via widget background callback');
      } else {
        // Clock in
        debugPrint('[home_widget] Attempting to clock in');
        await HiveDb.clockIn(DateTime.now());
        debugPrint('[home_widget] ✅ Successfully clocked in via widget background callback');
        
        // Debug: Check if data was actually saved
        final savedData = HiveDb.getDayEntry(DateTime.now());
        debugPrint('[home_widget] 🔍 Debug: Saved data check - $savedData');
        if (savedData != null) {
          debugPrint('[home_widget] 🔍 Debug: Clock in time - ${savedData['in']}');
          debugPrint('[home_widget] 🔍 Debug: Clock out time - ${savedData['out']}');
        } else {
          debugPrint('[home_widget] ❌ Debug: No data found after clock in!');
        }
        
        // Debug: Print all entries to see what's in the database
        debugPrint('[home_widget] 🔍 Debug: All entries in database:');
        HiveDb.printAllWorkHourEntries();
      }
      
      // Update widget display
      await _updateWidgetDisplay();
      
    } else {
      debugPrint('[home_widget] ⚠️ Unknown widget action: ${uri.host}');
    }
    
  } catch (e) {
    debugPrint('[home_widget] ❌ Error processing widget action: $e');
  }
}

// Helper function to update widget display
Future<void> _updateWidgetDisplay() async {
  try {
    debugPrint('[home_widget] Updating widget display');
    
    // Get current status
    final isClockedIn = HiveDb.isClockedIn();
    final currentDuration = HiveDb.getCurrentDuration();
    
    // Format duration
    final hours = currentDuration.inHours;
    final minutes = currentDuration.inMinutes.remainder(60);
    final seconds = currentDuration.inSeconds.remainder(60);
    final durationText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    // Update widget data
    await HomeWidget.saveWidgetData('_isClockedIn', isClockedIn);
    await HomeWidget.saveWidgetData('_durationText', durationText);
    await HomeWidget.saveWidgetData('_lastUpdate', DateTime.now().toIso8601String());
    
    // Update widget UI with correct provider name
    await HomeWidget.updateWidget(
      androidName: 'MyHomeWidgetProvider',
      iOSName: 'MyHomeWidgetProvider',
    );
    
    debugPrint('[home_widget] ✅ Widget UI updated with new clock times');
    
    // Update overtime and remaining information
    await HiveDb.updateWidgetWithOvertimeInfo();
    
    debugPrint('[home_widget] ✅ Widget display updated successfully');
  } catch (e) {
    debugPrint('[home_widget] ❌ Error updating widget display: $e');
  }
} 