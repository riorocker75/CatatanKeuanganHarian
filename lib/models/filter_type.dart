enum FilterType { daily, weekly, monthly }

extension FilterTypeExtension on FilterType {
  String get label {
    switch (this) {
      case FilterType.daily:
        return 'Harian';
      case FilterType.weekly:
        return 'Mingguan';
      case FilterType.monthly:
        return 'Bulanan';
    }
  }

  DateTime getStartDate() {
    final now = DateTime.now();
    switch (this) {
      case FilterType.daily:
        return DateTime(now.year, now.month, now.day);
      case FilterType.weekly:
        return now.subtract(Duration(days: now.weekday - 1));
      case FilterType.monthly:
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime getEndDate() {
    final now = DateTime.now();
    switch (this) {
      case FilterType.daily:
        return now.add(const Duration(days: 1));
      case FilterType.weekly:
        return now.add(Duration(days: 7 - now.weekday + 1));
      case FilterType.monthly:
        return DateTime(now.year, now.month + 1, 1);
    }
  }
}