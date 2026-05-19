import 'package:cloud_firestore/cloud_firestore.dart';

enum TransferType { transfer, withdraw }

class TransferModel {
  final String id;
  final String userId;
  final String fromWalletId;
  final String fromWalletName;
  final String toWalletId;
  final String toWalletName;
  final double amount;
  final TransferType type;
  final String? note;
  final DateTime createdAt;

  const TransferModel({
    required this.id,
    required this.userId,
    required this.fromWalletId,
    required this.fromWalletName,
    required this.toWalletId,
    required this.toWalletName,
    required this.amount,
    this.type = TransferType.transfer,
    this.note,
    required this.createdAt,
  });

  factory TransferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TransferModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      fromWalletId: data['fromWalletId'] as String? ?? '',
      fromWalletName: data['fromWalletName'] as String? ?? '',
      toWalletId: data['toWalletId'] as String? ?? '',
      toWalletName: data['toWalletName'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransferType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'transfer'),
        orElse: () => TransferType.transfer,
      ),
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fromWalletId': fromWalletId,
      'fromWalletName': fromWalletName,
      'toWalletId': toWalletId,
      'toWalletName': toWalletName,
      'amount': amount,
      'type': type.name,
      if (note != null) 'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get isWithdraw => type == TransferType.withdraw;

  String get formattedAmount {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }

  @override
  String toString() =>
      'TransferModel(id: $id, from: $fromWalletName, to: $toWalletName, amount: $amount, type: $type)';
}