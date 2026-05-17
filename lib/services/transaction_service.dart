import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import 'wallet_service.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'transactions';
  final WalletService _walletService = WalletService();
  // Tambah transaksi
   // UPDATE: Tambah transaksi + update saldo wallet
  Future<void> addTransaction(TransactionModel transaction) async {
    // Simpan transaksi
    await _firestore.collection(_collection).add(transaction.toFirestore());
    
    // Update saldo wallet kalau ada walletId
    if (transaction.walletId != null && transaction.walletId!.isNotEmpty) {
      await _walletService.updateBalance(
        transaction.walletId!,
        transaction.amount,
        transaction.type == TransactionType.income,
      );
    }
  }

  //UPDATE: Update transaksi + adjust saldo wallet
  Future<void> updateTransaction(TransactionModel oldTransaction, TransactionModel newTransaction) async {
    await _firestore
        .collection(_collection)
        .doc(newTransaction.id)
        .update(newTransaction.toFirestore());

    // Adjust saldo wallet kalau wallet berubah atau amount berubah
    if (oldTransaction.walletId != null && oldTransaction.walletId!.isNotEmpty) {
      // Kembalikan saldo lama
      await _walletService.updateBalance(
        oldTransaction.walletId!,
        oldTransaction.amount,
        oldTransaction.type == TransactionType.expense, // reverse
      );
    }
    
    if (newTransaction.walletId != null && newTransaction.walletId!.isNotEmpty) {
      // Kurangi/tambah saldo baru
      await _walletService.updateBalance(
        newTransaction.walletId!,
        newTransaction.amount,
        newTransaction.type == TransactionType.income,
      );
    }
  }

  //  Hapus transaksi + kembalikan saldo wallet
  Future<void> deleteTransaction(TransactionModel transaction) async {
    // Kembalikan saldo wallet kalau ada
    if (transaction.walletId != null && transaction.walletId!.isNotEmpty) {
      await _walletService.updateBalance(
        transaction.walletId!,
        transaction.amount,
        transaction.type == TransactionType.expense, // reverse = kembalikan
      );
    }
    
    await _firestore.collection(_collection).doc(transaction.id).delete();
  }

  // Stream transaksi user hari ini
  Stream<List<TransactionModel>> getTodayTransactions(String userId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  // Stream semua transaksi user
  Stream<List<TransactionModel>> getUserTransactions(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  // Stream transaksi per bulan
  Stream<List<TransactionModel>> getMonthlyTransactions(
      String userId, int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  // Get summary hari ini
  Future<Map<String, double>> getTodaySummary(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    double income = 0;
    double expense = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      if (data['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }

  // Tambahkan method ini ke class TransactionService

Stream<List<TransactionModel>> getTransactionsByDateRange({
  required String userId,
  required DateTime startDate,
  required DateTime endDate,
  TransactionType? type,
}) {
  var query = _firestore
      .collection(_collection)
      .where('userId', isEqualTo: userId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
      .where('date', isLessThan: Timestamp.fromDate(endDate));

  if (type != null) {
    query = query.where('type', isEqualTo: type == TransactionType.income ? 'income' : 'expense');
  }

  return query
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList());
}

  // Get summary per bulan
  Future<Map<String, double>> getMonthlySummary(
      String userId, int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
        .get();

    double income = 0;
    double expense = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      if (data['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }
}