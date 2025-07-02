import 'package:hive_flutter/hive_flutter.dart';
import 'models/work_entry.dart';
import 'models/settings.dart';
import 'repositories/work_hours_repository.dart';

class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  late final WorkHoursRepository _repository;

  Future<void> initialize() async {
    _repository = WorkHoursRepository();
    await _repository.initialize();
  }

  // Settings operations
  Future<Settings?> getSettings() async {
    return await _repository.getSettings();
  }

  Future<void> saveSettings(Settings settings) async {
    await _repository.saveSettings(settings);
  }

  // Work entry operations
  Future<void> saveWorkEntry(WorkEntry entry) async {
    await _repository.saveWorkEntry(entry);
  }

  Future<WorkEntry?> getWorkEntry(DateTime date) async {
    return await _repository.getWorkEntry(date);
  }

  Future<List<WorkEntry>> getWorkEntriesForRange(DateTime start, DateTime end) async {
    return await _repository.getWorkEntriesForRange(start, end);
  }

  Future<void> deleteWorkEntry(DateTime date) async {
    final entry = WorkEntry(
      date: date,
      duration: 0,
      isOffDay: false,
    );
    await _repository.deleteWorkEntry(entry);
  }

  // Statistics operations
  Future<Map<String, dynamic>> getStatsForRange(DateTime start, DateTime end) async {
    return await _repository.getStatsForRange(start, end);
  }

  Future<Map<String, dynamic>> calculateSalary(DateTime month) async {
    return await _repository.calculateSalary(month);
  }
} 