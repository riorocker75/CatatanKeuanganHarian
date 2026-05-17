import 'package:cloud_firestore/cloud_firestore.dart';

enum BudgetPeriod { daily, monthly }

class BudgetModel {
  final String id;
  final String userId;
  final double amount;
  final BudgetPeriod period;
  final String category;
  final DateTime createdAt;
  final bool notifyWhenExceeded;

  BudgetModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.period,
    this.category = 'all',
    required this.createdAt,
    this.notifyWhenExceeded = true,
  });

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      period: data['period'] == 'daily' ? BudgetPeriod.daily : BudgetPeriod.monthly,
      category: data['category'] ?? 'all',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      notifyWhenExceeded: data['notifyWhenExceeded'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'period': period == BudgetPeriod.daily ? 'daily' : 'monthly',
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'notifyWhenExceeded': notifyWhenExceeded,
    };
  }
}