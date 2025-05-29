import 'package:flutter/material.dart';
import '../../data/repositories/work_hours_repository.dart';
import '../../data/models/settings.dart';

class SettingsController extends ChangeNotifier {
  final WorkHoursRepository _repository;
  
  bool _isLoading = false;
  Settings? _settings;
  String? _error;

  SettingsController(this._repository);

  bool get isLoading => _isLoading;
  Settings? get settings => _settings;
  String? get error => _error;

  Future<void> initialize() async {
    await loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _repository.getSettings();
      if (_settings == null) {
        // Create default settings if none exist
        _settings = Settings(
          monthlySalary: 0,
          dailyTargetHours: 8,
          workDays: [true, true, true, true, true, false, false], // Mon-Fri
          currency: 'USD',
          insuranceRate: 0.08,
          overtimeRate: 1.5,
        );
        await saveSettings(_settings!);
      }
    } catch (e) {
      _error = 'Failed to load settings: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSettings(Settings newSettings) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.saveSettings(newSettings);
      _settings = newSettings;
    } catch (e) {
      _error = 'Failed to save settings: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMonthlySalary(double salary) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(monthlySalary: salary);
    await saveSettings(newSettings);
  }

  Future<void> updateDailyTargetHours(int hours) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(dailyTargetHours: hours);
    await saveSettings(newSettings);
  }

  Future<void> updateWorkDays(List<bool> workDays) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(workDays: workDays);
    await saveSettings(newSettings);
  }

  Future<void> updateCurrency(String currency) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(currency: currency);
    await saveSettings(newSettings);
  }

  Future<void> updateInsuranceRate(double rate) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(insuranceRate: rate);
    await saveSettings(newSettings);
  }

  Future<void> updateOvertimeRate(double rate) async {
    if (_settings == null) return;
    final newSettings = _settings!.copyWith(overtimeRate: rate);
    await saveSettings(newSettings);
  }

  String formatCurrency(double amount) {
    if (_settings == null) return '\$${amount.toStringAsFixed(2)}';
    return '${_settings!.currency} ${amount.toStringAsFixed(2)}';
  }

  String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}
