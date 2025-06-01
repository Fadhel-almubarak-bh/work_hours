import 'package:hive_flutter/hive_flutter.dart';
import '../models/work_entry.dart';
import '../models/settings.dart';
import '../../core/utils/date_time_utils.dart';
import '../local/hive_db.dart';

class WorkHoursRepository {
  static const String _workEntriesBox = 'work_entries';
  static const String _settingsBox = 'settings';

  Future<void> initialize() async {
    await HiveDb.initialize();
  }

  // Work Entry Methods
  Future<void> saveWorkEntry(WorkEntry entry) async {
    await HiveDb.saveWorkEntry(entry);
  }

  Future<WorkEntry?> getWorkEntry(DateTime date) async {
    final data = HiveDb.getDayEntry(date);
    if (data == null) return null;

    return WorkEntry(
      date: date,
      clockIn: data['in'] != null ? DateTime.parse(data['in'] as String) : null,
      clockOut: data['out'] != null ? DateTime.parse(data['out'] as String) : null,
      duration: data['duration'] as int? ?? 0,
      isOffDay: data['offDay'] as bool? ?? false,
      description: data['description'] as String?,
    );
  }

  Future<List<WorkEntry>> getWorkEntries(DateTime startDate, DateTime endDate) async {
    final entries = <WorkEntry>[];
    final allEntries = HiveDb.getAllEntries();
    
    for (var entry in allEntries.entries) {
      final date = DateTime.parse(entry.key);
      if (date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          date.isBefore(endDate.add(const Duration(days: 1)))) {
        entries.add(WorkEntry(
          date: date,
          clockIn: entry.value['in'] != null ? DateTime.parse(entry.value['in']) : null,
          clockOut: entry.value['out'] != null ? DateTime.parse(entry.value['out']) : null,
          duration: entry.value['duration'] ?? 0,
          isOffDay: entry.value['offDay'] ?? false,
          description: entry.value['description'],
        ));
      }
    }
    
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<List<WorkEntry>> getWorkEntriesForRange(DateTime startDate, DateTime endDate) async {
    final entries = HiveDb.getEntriesForRange(startDate, endDate);
    return entries.map((data) {
      final date = DateTime.parse(data['date'] as String);
      return WorkEntry(
        date: date,
        clockIn: data['in'] != null ? DateTime.parse(data['in'] as String) : null,
        clockOut: data['out'] != null ? DateTime.parse(data['out'] as String) : null,
        duration: data['duration'] as int? ?? 0,
        isOffDay: data['offDay'] as bool? ?? false,
        description: data['description'] as String?,
      );
    }).toList();
  }

  Future<void> deleteWorkEntry(WorkEntry entry) async {
    await HiveDb.deleteEntry(entry.date);
  }

  Future<void> deleteAllWorkEntries() async {
    await HiveDb.deleteAllEntries();
  }

  // Settings Methods
  Future<void> saveSettings(Settings settings) async {
    await HiveDb.setDailyTargetHours(settings.dailyTargetHours);
    await HiveDb.setMonthlySalary(settings.monthlySalary);
    await HiveDb.setWorkDays(settings.workDays);
  }

  Future<Settings?> getSettings() async {
    return Settings(
      dailyTargetHours: HiveDb.getDailyTargetHours(),
      monthlySalary: HiveDb.getMonthlySalary(),
      workDays: HiveDb.getWorkDays(),
      overtimeRate: 1.5, // Default value
      insuranceRate: 0.0, // Default value
    );
  }

  // Statistics Methods
  Future<Map<String, dynamic>> getStatistics(DateTime startDate, DateTime endDate) async {
    final entries = await getWorkEntries(startDate, endDate);
    final settings = await getSettings();

    if (settings == null) {
      return {
        'totalHours': 0.0,
        'workDays': 0,
        'overtimeHours': 0.0,
        'averageDailyHours': 0.0,
      };
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

    return {
      'totalHours': totalHours,
      'workDays': workDays,
      'overtimeHours': overtimeHours > 0 ? overtimeHours : 0,
      'averageDailyHours': averageDailyHours,
    };
  }

  // Statistics Operations
  Future<Map<String, int>> getStatsForRange(DateTime start, DateTime end) async {
    final entries = await getWorkEntries(start, end);
    int totalMinutes = 0;
    int offDaysCount = 0;

    for (final entry in entries) {
      if (entry.isOffDay) {
        offDaysCount++;
      } else {
        totalMinutes += entry.duration;
      }
    }

    return {
      'totalMinutes': totalMinutes,
      'offDaysCount': offDaysCount,
    };
  }

  Future<Map<String, dynamic>> calculateSalary(DateTime month) async {
    final settings = await getSettings();
    if (settings == null) {
      throw Exception('Settings not found');
    }

    final start = DateTimeUtils.startOfMonth(month);
    final end = DateTimeUtils.endOfMonth(month);
    final entries = await getWorkEntries(start, end);

    // Calculate expected work days and minutes
    final expectedWorkDays = DateTimeUtils.getWorkDaysInMonth(month, settings.workDays);
    final expectedMinutes = expectedWorkDays * settings.dailyTargetHours * 60;

    // Calculate actual minutes worked and overtime
    int actualMinutes = 0;
    int overtimeMinutes = 0;
    int offDaysCount = 0;

    for (final entry in entries) {
      if (entry.isOffDay) {
        offDaysCount++;
      } else {
        actualMinutes += entry.duration;
        if (entry.duration > settings.dailyTargetHours * 60) {
          overtimeMinutes += entry.duration - (settings.dailyTargetHours * 60);
        }
      }
    }

    // Calculate rates and earnings
    final dailyRate = settings.monthlySalary / expectedWorkDays;
    final hourlyRate = dailyRate / settings.dailyTargetHours;
    final overtimeRate = hourlyRate * settings.overtimeRate;
    final overtimePay = overtimeMinutes * overtimeRate / 60;
    final workDaysEarnings = (actualMinutes * hourlyRate / 60) + overtimePay;
    final offDaysEarnings = offDaysCount * dailyRate;
    final totalEarnings = workDaysEarnings + offDaysEarnings;
    final earningsAfterInsurance = totalEarnings * (1 - settings.insuranceRate);

    // Calculate today's earnings and minutes
    final today = DateTime.now();
    final todayEntry = await getWorkEntry(today);
    int todayMinutes = 0;
    double todayEarnings = 0.0;

    if (todayEntry != null) {
      if (todayEntry.isOffDay) {
        todayMinutes = settings.dailyTargetHours * 60;
      } else {
        todayMinutes = todayEntry.duration;
        if (todayEntry.clockOut == null && todayEntry.clockIn != null) {
          // If still working, calculate minutes up to now
          todayMinutes = DateTime.now().difference(todayEntry.clockIn!).inMinutes;
        }
      }
      todayEarnings = (todayMinutes * hourlyRate / 60);
      if (todayMinutes > settings.dailyTargetHours * 60) {
        final overtimeToday = todayMinutes - (settings.dailyTargetHours * 60);
        todayEarnings += overtimeToday * overtimeRate / 60;
      }
    }

    return {
      'expectedWorkDays': expectedWorkDays,
      'expectedMinutes': expectedMinutes,
      'actualMinutes': actualMinutes,
      'overtimeMinutes': overtimeMinutes,
      'offDaysCount': offDaysCount,
      'dailyRate': dailyRate,
      'hourlyRate': hourlyRate,
      'overtimeRate': overtimeRate,
      'overtimePay': overtimePay,
      'workDaysEarnings': workDaysEarnings,
      'offDaysEarnings': offDaysEarnings,
      'totalEarnings': totalEarnings,
      'earningsAfterInsurance': earningsAfterInsurance,
      'todayMinutes': todayMinutes,
      'todayEarnings': todayEarnings,
      'monthlySalary': settings.monthlySalary,
      'expectedHours': expectedWorkDays * settings.dailyTargetHours,
      'workDaysCount': expectedWorkDays,
      'dailyHours': settings.dailyTargetHours,
      'nonWorkingDaysCount': DateTimeUtils.getNonWorkingDaysInMonth(month, settings.workDays),
      'totalDaysOff': offDaysCount + DateTimeUtils.getNonWorkingDaysInMonth(month, settings.workDays),
    };
  }

  Future<List<WorkEntry>> getAllWorkEntries() async {
    final entries = <WorkEntry>[];
    final allEntries = HiveDb.getAllEntries();
    
    for (var entry in allEntries.entries) {
      final date = DateTime.parse(entry.key);
      entries.add(WorkEntry(
        date: date,
        clockIn: entry.value['in'] != null ? DateTime.parse(entry.value['in']) : null,
        clockOut: entry.value['out'] != null ? DateTime.parse(entry.value['out']) : null,
        duration: entry.value['duration'] ?? 0,
        isOffDay: entry.value['offDay'] ?? false,
        description: entry.value['description'],
      ));
    }
    
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> addWorkEntry({
    required DateTime date,
    required DateTime clockIn,
    DateTime? clockOut,
    required double hours,
    required double overtime,
  }) async {
    final totalHours = hours + overtime;
    final entry = WorkEntry(
      date: date,
      clockIn: clockIn,
      clockOut: clockOut,
      duration: (totalHours * 60).round(),
      isOffDay: false,
    );
    await saveWorkEntry(entry);
  }
}
