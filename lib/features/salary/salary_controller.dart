import 'package:flutter/material.dart';
import '../../data/repositories/work_hours_repository.dart';
import '../../data/models/settings.dart';

class SalaryController extends ChangeNotifier {
  final WorkHoursRepository _repository;
  
  bool _isLoading = false;
  Map<String, dynamic>? _currentMonthSalary;
  Map<String, dynamic>? _selectedMonthSalary;
  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _monthlyHistory = [];
  Settings? _settings;

  SalaryController(this._repository);

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get currentMonthSalary => _currentMonthSalary;
  Map<String, dynamic>? get selectedMonthSalary => _selectedMonthSalary;
  DateTime get selectedMonth => _selectedMonth;
  List<Map<String, dynamic>> get monthlyHistory => _monthlyHistory;

  String getCurrentMonthName() {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[DateTime.now().month - 1];
  }

  Future<void> initialize() async {
    _settings = await _repository.getSettings();
    await loadCurrentMonthSalary();
    await loadMonthlyHistory();
  }

  Future<void> loadCurrentMonthSalary() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentMonthSalary = await _repository.calculateSalary(DateTime.now());
    } catch (e) {
      debugPrint('Error loading current month salary: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSelectedMonthSalary() async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedMonthSalary = await _repository.calculateSalary(_selectedMonth);
    } catch (e) {
      debugPrint('Error loading selected month salary: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMonthlyHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final settings = await _repository.getSettings();
      if (settings == null) return;

      final now = DateTime.now();
      final months = <Map<String, dynamic>>[];

      // Get last 12 months
      for (var i = 0; i < 12; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final salary = await _repository.calculateSalary(month);
        months.add({
          'month': month,
          'salary': salary,
        });
      }

      _monthlyHistory = months;
    } catch (e) {
      debugPrint('Error loading monthly history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectMonth(DateTime month) {
    _selectedMonth = month;
    loadSelectedMonthSalary();
  }

  String formatCurrency(double amount) {
    if (_settings == null) return '\$${amount.toStringAsFixed(2)}';
    return '${_settings!.currency} ${amount.toStringAsFixed(2)}';
  }

  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${remainingMinutes.toString().padLeft(2, '0')}';
  }
}
