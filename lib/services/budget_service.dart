import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'budgets';

  // METHOD INI HARUS ADA
  Future<void> setBudget(BudgetModel budget) async {
    final existing = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: budget.userId)
        .where('period', isEqualTo: budget.period == BudgetPeriod.daily ? 'daily' : 'monthly')
        .where('category', isEqualTo: budget.category)
        .get();

    if (existing.docs.isNotEmpty) {
      // Update existing budget
      await _firestore
          .collection(_collection)
          .doc(existing.docs.first.id)
          .update(budget.toFirestore());
    } else {
      // Create new budget
      await _firestore.collection(_collection).add(budget.toFirestore());
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    await _firestore.collection(_collection).doc(budgetId).delete();
  }

  Stream<List<BudgetModel>> getUserBudgets(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BudgetModel.fromFirestore(doc))
            .toList());
  }

  Future<BudgetModel?> getBudget(String userId, BudgetPeriod period, {String category = 'all'}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('period', isEqualTo: period == BudgetPeriod.daily ? 'daily' : 'monthly')
          .where('category', isEqualTo: category)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return BudgetModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Error getBudget: $e');
      return null;
    }
  }

  Stream<double> watchCurrentSpending(String userId, BudgetPeriod period, {String category = 'all'}) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (period == BudgetPeriod.daily) {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = startDate.add(const Duration(days: 1));
    } else {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 1);
    }

    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThan: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'expense') {
          if (category == 'all' || data['category'] == category) {
            final dynamic rawAmount = data['amount'];
            if (rawAmount != null) {
              total += (rawAmount as num).toDouble();
            }
          }
        }
      }
      return total;
    });
  }

  Future<double> getCurrentSpending(String userId, BudgetPeriod period, {String category = 'all'}) async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      if (period == BudgetPeriod.daily) {
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(const Duration(days: 1));
      } else {
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
      }

      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate))
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'expense') {
          if (category == 'all' || data['category'] == category) {
            final dynamic rawAmount = data['amount'];
            if (rawAmount != null) {
              total += (rawAmount as num).toDouble();
            }
          }
        }
      }
      return total;
    } catch (e) {
      print('Error getCurrentSpending: $e');
      return 0.0;
    }
  }
}