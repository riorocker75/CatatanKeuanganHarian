import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet_model.dart';

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'wallets';

  Future<void> addWallet(WalletModel wallet) async {
    await _firestore.collection(_collection).add(wallet.toFirestore());
  }

  // ⬇️ BARU: Edit wallet
  Future<void> updateWallet(WalletModel wallet) async {
    await _firestore.collection(_collection).doc(wallet.id).update(wallet.toFirestore());
  }

  // ⬇️ BARU: Delete wallet + semua transaksi terkait (cascade delete)
  Future<void> deleteWallet(String walletId, String userId) async {
    // Hapus semua transaksi yang terkait dengan wallet ini
    final transactionsQuery = await _firestore
        .collection('transactions')
        .where('walletId', isEqualTo: walletId)
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    
    for (var doc in transactionsQuery.docs) {
      batch.delete(doc.reference);
    }
    
    // Hapus wallet
    batch.delete(_firestore.collection(_collection).doc(walletId));
    
    await batch.commit();
  }

  Stream<List<WalletModel>> getUserWallets(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletModel.fromFirestore(doc))
            .toList());
  }

  Future<WalletModel?> getDefaultWallet(String userId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isDefault', isEqualTo: true)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    return WalletModel.fromFirestore(snapshot.docs.first);
  }

  // ⬇️ BARU: Update balance (tambah/kurang)
  Future<void> updateBalance(String walletId, double amount, bool isIncome) async {
    final doc = await _firestore.collection(_collection).doc(walletId).get();
    if (!doc.exists) return;
    
    final currentBalance = (doc.data()?['balance'] ?? 0).toDouble();
    final newBalance = isIncome ? currentBalance + amount : currentBalance - amount;
    
    await _firestore.collection(_collection).doc(walletId).update({
      'balance': newBalance,
    });
  }

  // ⬇️ BARU: Get wallet by ID
  Future<WalletModel?> getWalletById(String walletId) async {
    final doc = await _firestore.collection(_collection).doc(walletId).get();
    if (!doc.exists) return null;
    return WalletModel.fromFirestore(doc);
  }
}