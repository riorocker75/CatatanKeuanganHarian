import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';
import 'holiday_service.dart';

class RecurringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'recurring_transactions';
  final TransactionService _transactionService = TransactionService();
  final HolidayService _holidayService = HolidayService();

  Future<void> addRecurring(RecurringTransactionModel recurring) async {
    await _firestore.collection(_collection).add(recurring.toFirestore());
  }

  Future<void> updateRecurring(RecurringTransactionModel recurring) async {
    await _firestore.collection(_collection).doc(recurring.id).update(recurring.toFirestore());
  }

  Future<void> deleteRecurring(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<RecurringTransactionModel>> getUserRecurring(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RecurringTransactionModel.fromFirestore(doc)).toList());
  }

  Future<void> processRecurringTransactions(String userId) async {
    try {
      final now = DateTime.now();
      // Pastikan data libur nasional tahun ini dan tahun depan sudah dimuat
      await _holidayService.loadHolidaysForYear(now.year);
      await _holidayService.loadHolidaysForYear(now.year + 1);

      final recurringList = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in recurringList.docs) {
        final recurring = RecurringTransactionModel.fromFirestore(doc);
        
        if (recurring.shouldGenerate()) {
          final rawDate = recurring.getRawNextDate();
          final effectiveDate = recurring.getEffectiveNextDate();
          
          String description = 'Transaksi rutin otomatis (${recurring.frequency.name})';
          if (recurring.businessDayRule != BusinessDayRule.none && rawDate.day != effectiveDate.day) {
            description = 'Transaksi otomatis ${recurring.title} (Disesuaikan ke tgl ${effectiveDate.day} karena tgl ${rawDate.day} libur/akhir pekan)';
          }

          // Generate transaction
          final transaction = TransactionModel(
            id: '',
            userId: userId,
            title: recurring.title,
            description: description,
            amount: recurring.amount,
            type: recurring.type,
            category: recurring.category,
            date: now,
            createdAt: now,
            walletId: recurring.walletId,
            walletName: recurring.walletName,
          );

          // Menambahkan transaksi dan otomatis update saldo dompet secara atomic
          await _transactionService.addTransaction(transaction);
          
          // Update lastGenerated ke tanggal kalender rawDate agar siklus berikutnya konsisten
          await _firestore.collection(_collection).doc(doc.id).update({
            'lastGenerated': Timestamp.fromDate(rawDate),
          });
        }
      }
    } catch (_) {
      // Handled silently
    }
  }
}