import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/holiday_service.dart';
import 'transaction_model.dart';

enum RecurringFrequency { daily, weekly, monthly, yearly }

class RecurringTransactionModel {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime lastGenerated;
  final bool isActive;
  final String? walletId;
  final String? walletName;
  final BusinessDayRule businessDayRule;
  final int? targetDayOfMonth; // e.g. 25
  final int executionHour;     // 0..23 (default 8)
  final int executionMinute;   // 0..59 (default 0)

  RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.type = TransactionType.expense,
    required this.category,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.lastGenerated,
    this.isActive = true,
    this.walletId,
    this.walletName,
    this.businessDayRule = BusinessDayRule.none,
    this.targetDayOfMonth,
    this.executionHour = 8,
    this.executionMinute = 0,
  });

  factory RecurringTransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RecurringTransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      category: data['category'] ?? '',
      frequency: _parseFrequency(data['frequency']),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      lastGenerated: (data['lastGenerated'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      walletId: data['walletId'],
      walletName: data['walletName'],
      businessDayRule: _parseBusinessDayRule(data['businessDayRule']),
      targetDayOfMonth: data['targetDayOfMonth'],
      executionHour: data['executionHour'] ?? 8,
      executionMinute: data['executionMinute'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'category': category,
      'frequency': frequency.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'lastGenerated': Timestamp.fromDate(lastGenerated),
      'isActive': isActive,
      'walletId': walletId,
      'walletName': walletName,
      'businessDayRule': businessDayRule.name,
      'targetDayOfMonth': targetDayOfMonth,
      'executionHour': executionHour,
      'executionMinute': executionMinute,
    };
  }

  RecurringTransactionModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastGenerated,
    bool? isActive,
    String? walletId,
    String? walletName,
    BusinessDayRule? businessDayRule,
    int? targetDayOfMonth,
    int? executionHour,
    int? executionMinute,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastGenerated: lastGenerated ?? this.lastGenerated,
      isActive: isActive ?? this.isActive,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      businessDayRule: businessDayRule ?? this.businessDayRule,
      targetDayOfMonth: targetDayOfMonth ?? this.targetDayOfMonth,
      executionHour: executionHour ?? this.executionHour,
      executionMinute: executionMinute ?? this.executionMinute,
    );
  }

  static RecurringFrequency _parseFrequency(String? freq) {
    switch (freq) {
      case 'daily': return RecurringFrequency.daily;
      case 'weekly': return RecurringFrequency.weekly;
      case 'yearly': return RecurringFrequency.yearly;
      case 'monthly':
      default: return RecurringFrequency.monthly;
    }
  }

  static BusinessDayRule _parseBusinessDayRule(String? rule) {
    switch (rule) {
      case 'previousWorkingDay': return BusinessDayRule.previousWorkingDay;
      case 'nextWorkingDay': return BusinessDayRule.nextWorkingDay;
      case 'none':
      default: return BusinessDayRule.none;
    }
  }

  /// Menghitung tanggal kalender jadwal berikutnya
  DateTime getRawNextDate() {
    switch (frequency) {
      case RecurringFrequency.daily:
        if (lastGenerated.isBefore(startDate)) {
          return startDate;
        }
        return DateTime(lastGenerated.year, lastGenerated.month, lastGenerated.day + 1);

      case RecurringFrequency.weekly:
        if (lastGenerated.isBefore(startDate)) {
          return startDate;
        }
        return DateTime(lastGenerated.year, lastGenerated.month, lastGenerated.day + 7);

      case RecurringFrequency.monthly:
        final targetDay = targetDayOfMonth ?? startDate.day;

        // Jika transaksi ini belum pernah dieksekusi (lastGenerated < startDate)
        if (lastGenerated.isBefore(startDate)) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final startDay = DateTime(startDate.year, startDate.month, startDate.day);

          // Selama belum masuk/lewat di tanggal bulan tersebut (hari ini <= startDay),
          // gunakan tanggal target bulan tersebut (startDate)
          if (!today.isAfter(startDay)) {
            return startDate;
          }

          // Jika tanggal di bulan tersebut sudah lewat hari-hari sebelumnya,
          // baru lompat ke bulan selanjutnya
          var nextYear = startDate.year;
          var nextMonth = startDate.month + 1;
          if (nextMonth > 12) {
            nextYear += 1;
            nextMonth = 1;
          }
          final daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          final actualDay = targetDay > daysInMonth ? daysInMonth : targetDay;
          return DateTime(nextYear, nextMonth, actualDay);
        }

        // Hitung bulan berikutnya dari lastGenerated jika sudah pernah dieksekusi
        var nextYear = lastGenerated.year;
        var nextMonth = lastGenerated.month + 1;
        if (nextMonth > 12) {
          nextYear += 1;
          nextMonth = 1;
        }
        // Pastikan tanggal valid di bulan tersebut (misal tgl 31 di Feb -> 28/29)
        final daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final actualDay = targetDay > daysInMonth ? daysInMonth : targetDay;
        return DateTime(nextYear, nextMonth, actualDay);

      case RecurringFrequency.yearly:
        if (lastGenerated.isBefore(startDate)) {
          return startDate;
        }
        return DateTime(lastGenerated.year + 1, lastGenerated.month, lastGenerated.day);
    }
  }

  /// Menghitung tanggal efektif berikutnya yang sudah disesuaikan dengan aturan hari kerja / libur nasional
  DateTime getEffectiveNextDate() {
    final rawDate = getRawNextDate();
    if (frequency == RecurringFrequency.daily) {
      // Harian tidak perlu penyesuaian mundur/maju hari
      return rawDate;
    }
    return HolidayService().getAdjustedDate(rawDate, businessDayRule);
  }

  /// Memeriksa apakah transaksi rutin ini sudah memenuhi syarat tanggal dan jam eksekusi
  bool shouldGenerate() {
    if (!isActive) return false;
    final now = DateTime.now();

    // Cek batas akhir jika ada
    if (endDate != null && now.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59))) {
      return false;
    }

    // Hitung waktu efektif eksekusi
    final effectiveDate = getEffectiveNextDate();
    final executionDateTime = DateTime(
      effectiveDate.year,
      effectiveDate.month,
      effectiveDate.day,
      executionHour,
      executionMinute,
    );

    // Sudah melewati atau tepat pada waktu eksekusi
    return now.isAtSameMomentAs(executionDateTime) || now.isAfter(executionDateTime);
  }

  String get formattedExecutionTime {
    final h = executionHour.toString().padLeft(2, '0');
    final m = executionMinute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }
}