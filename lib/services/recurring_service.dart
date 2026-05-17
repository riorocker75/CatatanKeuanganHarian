import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';

class RecurringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'recurring_transactions';
  final TransactionService _transactionService = TransactionService();

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
    final recurringList = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    for (var doc in recurringList.docs) {
      final recurring = RecurringTransactionModel.fromFirestore(doc);
      
      if (recurring.shouldGenerate()) {
        // Generate transaction
        final transaction = TransactionModel(
          id: '',
          userId: userId,
          title: recurring.title,
          description: 'Transaksi rutin - ${recurring.frequency.name}',
          amount: recurring.amount,
          type: TransactionType.expense,
          category: recurring.category,
          date: recurring.getNextDate(),
          createdAt: DateTime.now(),
        );

        await _transactionService.addTransaction(transaction);
        
        // Update lastGenerated
        await _firestore.collection(_collection).doc(doc.id).update({
          'lastGenerated': Timestamp.fromDate(recurring.getNextDate()),
        });
      }
    }
  }
}