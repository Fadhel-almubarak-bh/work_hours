import 'package:flutter/material.dart';
import '../../data/local/hive_db.dart';
import '../../services/notification_service.dart';
import '../../services/permissions_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/work_hours_repository.dart';
import '../../data/models/work_entry.dart';

class HomeController extends ChangeNotifier {
  final WorkHoursRepository _repository;
  bool _isLoading = false;
  Map<DateTime, WorkEntry> _entries = {};
  DateTime _selectedDate = DateTime.now();

  HomeController(this._repository);

  bool get isLoading => _isLoading;
  Map<DateTime, WorkEntry> get entries => _entries;
  DateTime get selectedDate => _selectedDate;

  Future<void> loadEntries(DateTime startDate, DateTime endDate) async {
    _isLoading = true;
    notifyListeners();

    try {
      final entries = await _repository.getWorkEntriesForRange(startDate, endDate);
      _entries = Map.fromEntries(
        entries.map((entry) => MapEntry(entry.date, entry))
      );
    } catch (e) {
      debugPrint('Error loading entries: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clockIn() async {
    try {
      final now = DateTime.now();
      await _repository.saveWorkEntry(WorkEntry(
        date: now,
        clockIn: now,
        duration: 0,
        isOffDay: false,
      ));
      notifyListeners();
    } catch (e) {
      debugPrint('Error in clockIn: $e');
      rethrow;
    }
  }

  Future<void> clockOut() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entry = await _repository.getWorkEntry(today);
      
      if (entry == null) {
        throw Exception('No clock-in record found for today');
      }
      
      await _repository.saveWorkEntry(entry.copyWith(
        clockOut: now,
        duration: now.difference(entry.clockIn!).inMinutes,
      ));
      notifyListeners();
    } catch (e) {
      debugPrint('Error in clockOut: $e');
      rethrow;
    }
  }

  Future<void> markOffDay(DateTime date) async {
    try {
      final entry = WorkEntry(
        date: date,
        duration: 0,
        isOffDay: true,
      );
      
      await _repository.saveWorkEntry(entry);
      await loadEntries(
        DateTime(date.year, date.month - 1, 1),
        DateTime(date.year, date.month + 1, 0),
      );
    } catch (e) {
      debugPrint('Error marking off day: $e');
      rethrow;
    }
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> exportDataToExcel(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Text("Exporting data..."),
              ],
            ),
          );
        },
      );
      
      try {
        // Check permissions first
        final permissionsGranted = await PermissionService.checkAndRequestPermissions(context);
        if (!permissionsGranted) {
          // Hide loading dialog
          if (context.mounted) Navigator.of(context).pop();
          NotificationUtil.showWarning(context, 'Storage permission is required to export data');
          return;
        }
        
        await HiveDb.exportDataToExcel(context);
        
        // Hide loading dialog
        if (context.mounted) Navigator.of(context).pop();
        NotificationUtil.showSuccess(context, '✅ Excel export successful');
      } catch (e) {
        // Hide loading dialog if it's still showing
        if (context.mounted) Navigator.of(context).pop();
        throw e; // Re-throw for outer catch
      }
    } catch (e) {
      NotificationUtil.showError(context, '❌ Error exporting to Excel: ${e.toString()}');
      debugPrint('Export error: $e');
    }
  }

  Future<void> importDataFromExcel(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Text("Importing data..."),
              ],
            ),
          );
        },
      );
      
      try {
        // Check permissions first
        final permissionsGranted = await PermissionService.checkAndRequestPermissions(context);
        if (!permissionsGranted) {
          // Hide loading dialog
          if (context.mounted) Navigator.of(context).pop();
          NotificationUtil.showWarning(context, 'Storage permission is required to import data');
          return;
        }
        
        await HiveDb.importDataFromExcel(context);
        
        // Hide loading dialog
        if (context.mounted) Navigator.of(context).pop();
        NotificationUtil.showSuccess(context, '✅ Excel import successful');
      } catch (e) {
        // Hide loading dialog if it's still showing
        if (context.mounted) Navigator.of(context).pop();
        throw e; // Re-throw for outer catch
      }
    } catch (e) {
      NotificationUtil.showError(context, '❌ Error importing Excel: ${e.toString()}');
      debugPrint('Import error: $e');
    }
  }

  Map<String, dynamic>? getTodayStatus() {
    return HiveDb.getEntry(DateTime.now());
  }
}

