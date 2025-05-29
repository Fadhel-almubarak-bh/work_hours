import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 2)
class Settings {
  @HiveField(0)
  final double monthlySalary;

  @HiveField(1)
  final int dailyTargetHours;

  @HiveField(2)
  final List<bool> workDays; // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]

  @HiveField(3)
  final String currency;

  @HiveField(4)
  final double insuranceRate; // e.g., 0.08 for 8%

  @HiveField(5)
  final double overtimeRate; // e.g., 1.5 for 150%

  Settings({
    required this.monthlySalary,
    required this.dailyTargetHours,
    required this.workDays,
    this.currency = 'USD',
    this.insuranceRate = 0.08,
    this.overtimeRate = 1.5,
  }) : assert(workDays.length == 7, 'Work days must be a list of 7 boolean values');

  Map<String, dynamic> toJson() {
    return {
      'monthlySalary': monthlySalary,
      'dailyTargetHours': dailyTargetHours,
      'workDays': workDays,
      'currency': currency,
      'insuranceRate': insuranceRate,
      'overtimeRate': overtimeRate,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      monthlySalary: json['monthlySalary'] as double,
      dailyTargetHours: json['dailyTargetHours'] as int,
      workDays: List<bool>.from(json['workDays'] as List),
      currency: json['currency'] as String,
      insuranceRate: json['insuranceRate'] as double,
      overtimeRate: json['overtimeRate'] as double,
    );
  }

  Settings copyWith({
    double? monthlySalary,
    int? dailyTargetHours,
    List<bool>? workDays,
    String? currency,
    double? insuranceRate,
    double? overtimeRate,
  }) {
    return Settings(
      monthlySalary: monthlySalary ?? this.monthlySalary,
      dailyTargetHours: dailyTargetHours ?? this.dailyTargetHours,
      workDays: workDays ?? List<bool>.from(this.workDays),
      currency: currency ?? this.currency,
      insuranceRate: insuranceRate ?? this.insuranceRate,
      overtimeRate: overtimeRate ?? this.overtimeRate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Settings &&
        other.monthlySalary == monthlySalary &&
        other.dailyTargetHours == dailyTargetHours &&
        _listEquals(other.workDays, workDays) &&
        other.currency == currency &&
        other.insuranceRate == insuranceRate &&
        other.overtimeRate == overtimeRate;
  }

  @override
  int get hashCode {
    return monthlySalary.hashCode ^
        dailyTargetHours.hashCode ^
        _listHashCode(workDays) ^
        currency.hashCode ^
        insuranceRate.hashCode ^
        overtimeRate.hashCode;
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _listHashCode<T>(List<T> list) {
    int hash = 0;
    for (var item in list) {
      hash = hash * 31 + (item?.hashCode ?? 0);
    }
    return hash;
  }
}
