import 'package:flutter/material.dart';
import '../../data/local/hive_db.dart';
import '../../data/repositories/work_hours_repository.dart';
import '../../data/models/work_entry.dart';

class SummaryData {
  final double totalHours;
  final int workDays;
  final double overtimeHours;
  final double averageDailyHours;

  SummaryData({
    required this.totalHours,
    required this.workDays,
    required this.overtimeHours,
    required this.averageDailyHours,
  });
}

class HistoryController extends ChangeNotifier {
  final WorkHoursRepository _repository;
  List<WorkEntry> _entries = [];
  bool _isLoading = false;
  bool _isCalculating = false;
  SummaryData? _summary;

  HistoryController(this._repository);

  List<WorkEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  SummaryData? get summary => _summary;

  Future<void> loadHistory(DateTime month) async {
    _isLoading = true;
    notifyListeners();

    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);
      _entries = await _repository.getWorkEntries(startDate, endDate);
    } catch (e) {
      debugPrint('Error loading history: $e');
      _entries = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEntry(WorkEntry entry) async {
    try {
      await _repository.deleteWorkEntry(entry.date);
      _entries.removeWhere((e) => e.date == entry.date);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting entry: $e');
    }
  }

  Future<void> updateEntry(WorkEntry oldEntry, WorkEntry newEntry) async {
    try {
      await _repository.saveWorkEntry(newEntry);
      final index = _entries.indexWhere((e) => e.date == oldEntry.date);
      if (index != -1) {
        _entries[index] = newEntry;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating entry: $e');
    }
  }

  Future<void> markAsOffDay(DateTime date, {String? description}) async {
    try {
      final entry = WorkEntry(
        date: date,
        duration: 0,
        isOffDay: true,
        description: description,
      );
      await _repository.saveWorkEntry(entry);
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking as off day: $e');
      rethrow;
    }
  }

  Future<void> loadSummary(DateTime month) async {
    _isLoading = true;
    notifyListeners();

    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);
      
      final entries = await _repository.getWorkEntries(startDate, endDate);
      final settings = await _repository.getSettings();
      
      if (settings == null) {
        _summary = null;
        return;
      }

      final totalMinutes = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.duration,
      );

      final workDays = entries.where((entry) => !entry.isOffDay).length;
      final totalHours = totalMinutes / 60;
      
      final expectedMinutes = workDays * settings.dailyTargetHours * 60;
      final overtimeHours = (totalMinutes - expectedMinutes) / 60;
      
      final averageDailyHours = workDays > 0 ? totalHours / workDays : 0.0;

      _summary = SummaryData(
        totalHours: totalHours,
        workDays: workDays,
        overtimeHours: overtimeHours > 0 ? overtimeHours : 0,
        averageDailyHours: averageDailyHours,
      );
    } catch (e) {
      debugPrint('Error loading summary: $e');
      _summary = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> calculateSummary() async {
    if (_isCalculating) return {};
    _isCalculating = true;

    try {
      final now = DateTime.now();
      // Calculate week start (Saturday) by going back to the previous Saturday
      final weekStart = now.subtract(Duration(days: (now.weekday + 1) % 7)); // Saturday
      final monthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);

      // Get today's entry to calculate current progress
      final todayEntry = HiveDb.getDayEntry(now);
      int todayMinutes = 0;
      bool isCurrentlyClockedIn = false;

      if (todayEntry != null) {
        if (todayEntry['offDay'] == true) {
          todayMinutes = HiveDb.getDailyTargetMinutes();
        } else if (todayEntry['duration'] != null) {
          todayMinutes = (todayEntry['duration'] as num).toInt();
        }
        // If currently clocked in, add current duration
        if (todayEntry['in'] != null && todayEntry['out'] == null) {
          isCurrentlyClockedIn = true;
          final clockInTime = DateTime.parse(todayEntry['in']);
          final currentDuration = now.difference(clockInTime).inMinutes;
          todayMinutes = currentDuration;
        }
      }

      // Get stats excluding today
      final weekStats = HiveDb.getStatsForRange(weekStart, now.subtract(const Duration(days: 1)));
      final monthStats = HiveDb.getStatsForRange(monthStart, now.subtract(const Duration(days: 1)));
      final lastMonthStats = HiveDb.getStatsForRange(lastMonthStart, lastMonthEnd);

      // Calculate monthly total including today if checked out
      int monthlyTotal = (monthStats['totalMinutes'] as num).toInt();
      if (!isCurrentlyClockedIn && todayEntry != null && todayEntry['out'] != null) {
        if (todayEntry['offDay'] == true) {
          monthlyTotal += HiveDb.getDailyTargetMinutes();
        } else if (todayEntry['duration'] != null) {
          monthlyTotal += (todayEntry['duration'] as num).toInt();
        }
      }

      // Calculate monthly overtime using the new method
      final overtimeMinutes = HiveDb.getMonthlyOvertime();

      // Calculate last month's overtime
      final lastMonthOvertimeMinutes = HiveDb.getLastMonthOvertime();

      // Get expected minutes for both months
      final currentMonthExpectedMinutes = HiveDb.getCurrentMonthExpectedMinutes();
      final lastMonthExpectedMinutes = HiveDb.getLastMonthExpectedMinutes();

      // Calculate weekly and monthly totals separately
      final weeklyTotal = (weekStats['totalMinutes'] as num).toInt() + (isCurrentlyClockedIn ? 0 : todayMinutes);

      return {
        'weeklyTotal': weeklyTotal,
        'monthlyTotal': monthlyTotal,
        'lastMonthTotal': (lastMonthStats['totalMinutes'] as num).toInt(),
        'weeklyWorkDays': (weekStats['workDays'] as num).toInt() + (isCurrentlyClockedIn ? 0 : (todayMinutes > 0 ? 1 : 0)),
        'monthlyWorkDays': (monthStats['workDays'] as num).toInt(),
        'lastMonthWorkDays': (lastMonthStats['workDays'] as num).toInt(),
        'weeklyOffDays': (weekStats['offDays'] as num).toInt() + (isCurrentlyClockedIn ? 0 : (todayEntry?['offDay'] == true ? 1 : 0)),
        'monthlyOffDays': (monthStats['offDays'] as num).toInt(),
        'lastMonthOffDays': (lastMonthStats['offDays'] as num).toInt(),
        'overtimeMinutes': overtimeMinutes,
        'lastMonthOvertimeMinutes': lastMonthOvertimeMinutes,
        'currentMonthExpectedMinutes': currentMonthExpectedMinutes,
        'lastMonthExpectedMinutes': lastMonthExpectedMinutes,
      };
    } catch (e) {
      debugPrint('Error calculating summary: $e');
      return {};
    } finally {
      _isCalculating = false;
    }
  }

  void refreshSummary() {
    HiveDb.printAllWorkHourEntries();
    debugPrint("---------------->");
    HiveDb.calculateAndPrintMonthlyOvertime();

    // Current month details
    final currentMonthExpected = HiveDb.getCurrentMonthExpectedMinutes();
    final currentMonthOvertime = HiveDb.getMonthlyOvertime();
    debugPrint("\n📅 [CURRENT MONTH]");
    debugPrint("Expected Hours: ${formatDuration(currentMonthExpected)}");
    debugPrint("Overtime: ${currentMonthOvertime >= 0 ? '+' : ''}${formatDuration(currentMonthOvertime.abs())}");

    // Last month details
    final lastMonthExpected = HiveDb.getLastMonthExpectedMinutes();
    final lastMonthOvertime = HiveDb.getLastMonthOvertime();
    debugPrint("\n📅 [LAST MONTH]");
    debugPrint("Expected Hours: ${formatDuration(lastMonthExpected)}");
    debugPrint("Overtime: ${lastMonthOvertime >= 0 ? '+' : ''}${formatDuration(lastMonthOvertime.abs())}");
  }

  String formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
