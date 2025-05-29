import 'package:flutter/material.dart';
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

class SummaryController extends ChangeNotifier {
  final WorkHoursRepository _repository;
  List<WorkEntry> _entries = [];
  bool _isLoading = false;
  SummaryData? _summary;

  SummaryController(this._repository);

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
}
