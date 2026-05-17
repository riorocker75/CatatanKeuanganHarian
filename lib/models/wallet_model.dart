import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WalletModel {
  final String id;
  final String userId;
  final String name;
  final String type; // cash, bank, e-wallet
  final double balance;
  final String? accountNumber;
  final String? bankName;
  final DateTime createdAt;
  final bool isDefault;

  WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.balance = 0,
    this.accountNumber,
    this.bankName,
    required this.createdAt,
    this.isDefault = false,
  });

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WalletModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? 'cash',
      balance: (data['balance'] ?? 0).toDouble(),
      accountNumber: data['accountNumber'],
      bankName: data['bankName'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isDefault: data['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'balance': balance,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDefault': isDefault,
    };
  }

  IconData get icon {
    switch (type) {
      case 'bank':
        return Icons.account_balance;
      case 'e-wallet':
        return Icons.phone_android;
      case 'cash':
      default:
        return Icons.money;
    }
  }
}