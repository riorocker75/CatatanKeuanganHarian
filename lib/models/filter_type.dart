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
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case FilterType.daily:
        return today;
      case FilterType.weekly:
        // Start of this week (Monday)
        return today.subtract(Duration(days: now.weekday - 1));
      case FilterType.monthly:
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime getEndDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case FilterType.daily:
        return today.add(const Duration(days: 1));
      case FilterType.weekly:
        // End of this week (Sunday 23:59:59 or Monday next week 00:00)
        return today.add(Duration(days: 7 - now.weekday + 1));
      case FilterType.monthly:
        return DateTime(now.year, now.month + 1, 1);
    }
  }
}