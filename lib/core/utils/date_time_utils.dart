import 'package:intl/intl.dart';

class DateTimeUtils {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _timeFormat = DateFormat('HH:mm');
  static final _monthYearFormat = DateFormat('MMMM yyyy');
  static final _dayFormat = DateFormat('EEEE');

  /// Formats a DateTime to 'yyyy-MM-dd'
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Formats a DateTime to 'HH:mm'
  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }

  /// Formats a DateTime to 'MMMM yyyy' (e.g., 'January 2024')
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  /// Formats a DateTime to day name (e.g., 'Monday')
  static String formatDay(DateTime date) {
    return _dayFormat.format(date);
  }

  /// Returns the start of the month for a given date
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Returns the end of the month for a given date
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Returns the start of the week (Monday) for a given date
  static DateTime startOfWeek(DateTime date) {
    final day = date.weekday;
    return date.subtract(Duration(days: day - 1));
  }

  /// Returns the end of the week (Sunday) for a given date
  static DateTime endOfWeek(DateTime date) {
    final day = date.weekday;
    return date.add(Duration(days: 7 - day));
  }

  /// Returns the number of work days in a date range
  static int getWorkDaysInRange(DateTime start, DateTime end, List<bool> workDays) {
    int count = 0;
    var current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (workDays[current.weekday - 1]) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  /// Returns the number of work days in a month
  static int getWorkDaysInMonth(DateTime date, List<bool> workDays) {
    return getWorkDaysInRange(
      startOfMonth(date),
      endOfMonth(date),
      workDays,
    );
  }

  /// Returns the expected work minutes for a month
  static int getExpectedWorkMinutes(DateTime date, int dailyTargetHours, List<bool> workDays) {
    final workDaysCount = getWorkDaysInMonth(date, workDays);
    return workDaysCount * dailyTargetHours * 60;
  }

  /// Returns true if the given date is a work day
  static bool isWorkDay(DateTime date, List<bool> workDays) {
    return workDays[date.weekday - 1];
  }

  /// Returns the duration between two times in minutes
  static int getDurationInMinutes(DateTime start, DateTime end) {
    return end.difference(start).inMinutes;
  }

  /// Returns a formatted duration string (e.g., "2h 30m")
  static String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    return '${remainingMinutes}m';
  }

  /// Returns a list of dates between start and end (inclusive)
  static List<DateTime> getDatesInRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    var current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  /// Returns a list of months between start and end (inclusive)
  static List<DateTime> getMonthsInRange(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var current = DateTime(start.year, start.month, 1);
    final endDate = DateTime(end.year, end.month, 1);
    
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }
}
