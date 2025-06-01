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

class App extends StatelessWidget {
  const App({super.key});

  static WorkHoursRepository? _repository;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Initialize Hive
    await Hive.initFlutter();
    
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
      
      // Check for widget action when app is launched
      try {
        final widgetAction = await HomeWidget.getWidgetData<String>('action');
        debugPrint('🔍 [WIDGET_DEBUG] Checking for widget action on launch: $widgetAction');
        
        if (widgetAction != null) {
          debugPrint('🔍 [WIDGET_DEBUG] Processing widget action: $widgetAction');
          await WidgetService.handleWidgetAction(widgetAction);
          // Clear the action after handling
          await HomeWidget.saveWidgetData('action', null);
          debugPrint('✅ [WIDGET_DEBUG] Widget action processed and cleared');
        }
      } catch (e) {
        debugPrint('❌ [WIDGET_DEBUG] Error handling widget action: $e');
        debugPrint('❌ [WIDGET_DEBUG] Error details: ${e.toString()}');
      }
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
      await Hive.initFlutter();
      await Hive.openBox('work_entries');
      await Hive.openBox('settings');

      await WidgetService.handleWidgetAction('clockInOut');
      debugPrint('✅ [WIDGET_DEBUG] Clocked in via widget callback');
    } catch (e) {
      debugPrint('❌ [WIDGET_DEBUG] Error clocking in via widget callback: $e');
    }
  } else if (uri.host == 'clock_out') {
    try {
      // Ensure Hive is initialized
      debugPrint('🔍 [WIDGET_DEBUG] Initializing Hive for clock_out widget action');
      await Hive.initFlutter();
      await Hive.openBox('work_entries');
      await Hive.openBox('settings');

      await WidgetService.handleWidgetAction('clockInOut');
      debugPrint('✅ [WIDGET_DEBUG] Clocked out via widget callback');
    } catch (e) {
      debugPrint('❌ [WIDGET_DEBUG] Error clocking out via widget callback: $e');
    }
  }
} 