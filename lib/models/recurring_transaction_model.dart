import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurringFrequency { daily, weekly, monthly, yearly }

class RecurringTransactionModel {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime lastGenerated;
  final bool isActive;

  RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.lastGenerated,
    this.isActive = true,
  });

  factory RecurringTransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RecurringTransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      frequency: _parseFrequency(data['frequency']),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      lastGenerated: (data['lastGenerated'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'frequency': frequency.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'lastGenerated': Timestamp.fromDate(lastGenerated),
      'isActive': isActive,
    };
  }

  // ⬇️ TAMBAHKAN METHOD INI
  RecurringTransactionModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    String? category,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastGenerated,
    bool? isActive,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastGenerated: lastGenerated ?? this.lastGenerated,
      isActive: isActive ?? this.isActive,
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

  DateTime getNextDate() {
    switch (frequency) {
      case RecurringFrequency.daily:
        return lastGenerated.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return lastGenerated.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(lastGenerated.year, lastGenerated.month + 1, lastGenerated.day);
      case RecurringFrequency.yearly:
        return DateTime(lastGenerated.year + 1, lastGenerated.month, lastGenerated.day);
    }
  }

  bool shouldGenerate() {
    if (!isActive) return false;
    if (endDate != null && DateTime.now().isAfter(endDate!)) return false;
    return DateTime.now().isAfter(getNextDate()) || 
           DateTime.now().day == getNextDate().day;
  }
}