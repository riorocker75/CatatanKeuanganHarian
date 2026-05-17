import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum TransactionType { income, expense }

class TransactionModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final DateTime createdAt;
  final String? walletId;      // ← BARU
  final String? walletName;    // ← BARU

  TransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.createdAt,
    this.walletId,             // ← BARU
    this.walletName,           // ← BARU
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      category: data['category'] ?? 'Lainnya',
      date: (data['date'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      walletId: data['walletId'],           // ← BARU
      walletName: data['walletName'],         // ← BARU
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'category': category,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'walletId': walletId,                  // ← BARU
      'walletName': walletName,              // ← BARU
    };
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    DateTime? createdAt,
    String? walletId,                        // ← BARU
    String? walletName,                      // ← BARU
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      walletId: walletId ?? this.walletId,           // ← BARU
      walletName: walletName ?? this.walletName,     // ← BARU
    );
  }

  String get formattedAmount {
    final prefix = type == TransactionType.income ? '+' : '-';
    return '$prefix Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  static Map<String, IconData> categoryIcons = {
    'Makanan': Icons.restaurant,
    'Transportasi': Icons.directions_car,
    'Belanja': Icons.shopping_bag,
    'Hiburan': Icons.movie,
    'Kesehatan': Icons.local_hospital,
    'Pendidikan': Icons.school,
    'Gaji': Icons.work,
    'Investasi': Icons.trending_up,
    'Lainnya': Icons.category,
  };

  IconData get icon => categoryIcons[category] ?? Icons.category;
}