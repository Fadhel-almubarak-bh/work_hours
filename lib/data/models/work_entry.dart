import 'package:hive/hive.dart';

part 'work_entry.g.dart';

@HiveType(typeId: 1)
class WorkEntry {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final DateTime? clockIn;

  @HiveField(2)
  final DateTime? clockOut;

  @HiveField(3)
  final int duration; // in minutes

  @HiveField(4)
  final bool isOffDay;

  @HiveField(5)
  final String? description;

  WorkEntry({
    required this.date,
    this.clockIn,
    this.clockOut,
    required this.duration,
    required this.isOffDay,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'duration': duration,
      'isOffDay': isOffDay,
      'description': description,
    };
  }

  factory WorkEntry.fromJson(Map<String, dynamic> json) {
    return WorkEntry(
      date: DateTime.parse(json['date'] as String),
      duration: json['duration'] as int,
      isOffDay: json['isOffDay'] as bool,
      description: json['description'] as String?,
    );
  }

  WorkEntry copyWith({
    DateTime? date,
    DateTime? clockIn,
    DateTime? clockOut,
    int? duration,
    bool? isOffDay,
    String? description,
  }) {
    return WorkEntry(
      date: date ?? this.date,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      duration: duration ?? this.duration,
      isOffDay: isOffDay ?? this.isOffDay,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkEntry &&
        other.date == date &&
        other.duration == duration &&
        other.isOffDay == isOffDay &&
        other.description == description;
  }

  @override
  int get hashCode {
    return date.hashCode ^
        duration.hashCode ^
        isOffDay.hashCode ^
        description.hashCode;
  }
}
