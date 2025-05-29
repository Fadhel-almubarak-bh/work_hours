import 'package:flutter/material.dart';
import '../../data/repositories/work_hours_repository.dart';
import '../../data/models/work_entry.dart';

class HistoryController extends ChangeNotifier {
  final WorkHoursRepository _repository;
  List<WorkEntry> _entries = [];
  bool _isLoading = false;

  HistoryController(this._repository);

  List<WorkEntry> get entries => _entries;
  bool get isLoading => _isLoading;

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
      await _repository.saveWorkEntry(WorkEntry(
        date: date,
        duration: 0,
        isOffDay: true,
        description: description,
      ));
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking as off day: $e');
      rethrow;
    }
  }
}
