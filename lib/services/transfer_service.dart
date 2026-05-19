import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transfer_model.dart';
import '../models/wallet_model.dart';

class TransferService {
  final FirebaseFirestore _firestore;
  final String _collection = 'transfers';

  TransferService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Transfer antar wallet (atomic dengan batch)
  Future<void> transferBetweenWallets({
    required String userId,
    required WalletModel fromWallet,
    required WalletModel toWallet,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) throw Exception('Jumlah harus lebih dari 0');
    if (fromWallet.id == toWallet.id) throw Exception('Tidak bisa transfer ke wallet yang sama');
    if (fromWallet.balance < amount) throw Exception('Saldo tidak mencukupi');

    final batch = _firestore.batch();
    final now = DateTime.now();

    // 1. Kurangi saldo wallet asal
    batch.update(
      _firestore.collection('wallets').doc(fromWallet.id),
      {'balance': FieldValue.increment(-amount)},
    );

    // 2. Tambah saldo wallet tujuan
    batch.update(
      _firestore.collection('wallets').doc(toWallet.id),
      {'balance': FieldValue.increment(amount)},
    );

    // 3. Catat history transfer
    final transferRef = _firestore.collection(_collection).doc();
    final transfer = TransferModel(
      id: transferRef.id,
      userId: userId,
      fromWalletId: fromWallet.id,
      fromWalletName: fromWallet.name,
      toWalletId: toWallet.id,
      toWalletName: toWallet.name,
      amount: amount,
      type: TransferType.transfer,
      note: note,
      createdAt: now,
    );

    batch.set(transferRef, transfer.toFirestore());

    await batch.commit();
  }

  /// Withdraw (keluarkan uang dari wallet, tidak masuk ke wallet lain)
  Future<void> withdrawFromWallet({
    required String userId,
    required WalletModel fromWallet,
    required double amount,
    String? note,
    String? destinationInfo, // misal: "Rekening BCA 1234"
  }) async {
    if (amount <= 0) throw Exception('Jumlah harus lebih dari 0');
    if (fromWallet.balance < amount) throw Exception('Saldo tidak mencukupi');

    final batch = _firestore.batch();
    final now = DateTime.now();

    // 1. Kurangi saldo wallet
    batch.update(
      _firestore.collection('wallets').doc(fromWallet.id),
      {'balance': FieldValue.increment(-amount)},
    );

    // 2. Catat history withdraw
    final transferRef = _firestore.collection(_collection).doc();
    final transfer = TransferModel(
      id: transferRef.id,
      userId: userId,
      fromWalletId: fromWallet.id,
      fromWalletName: fromWallet.name,
      toWalletId: 'withdraw', // marker untuk withdraw
      toWalletName: destinationInfo ?? 'Withdraw',
      amount: amount,
      type: TransferType.withdraw,
      note: note ?? 'Penarikan dana',
      createdAt: now,
    );

    batch.set(transferRef, transfer.toFirestore());

    await batch.commit();
  }

  /// Stream history transfer user
  Stream<List<TransferModel>> getUserTransfers(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransferModel.fromFirestore(doc))
            .toList());
  }

  /// Stream history transfer untuk wallet tertentu (sebagai pengirim atau penerima)
  Stream<List<TransferModel>> getWalletTransfers(String walletId) {
    return _firestore
        .collection(_collection)
        .where(Filter.or(
          Filter('fromWalletId', isEqualTo: walletId),
          Filter('toWalletId', isEqualTo: walletId),
        ))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransferModel.fromFirestore(doc))
            .toList());
  }

  /// Hapus history transfer (jika diperlukan)
  Future<void> deleteTransfer(String transferId) async {
    await _firestore.collection(_collection).doc(transferId).delete();
  }
  
  /// Hapus history transfer + rollback saldo (atomic batch)
  Future<void> deleteTransferWithRollback(TransferModel transfer) async {
    final batch = _firestore.batch();

    if (transfer.isWithdraw) {
      // ========== ROLLBACK WITHDRAW ==========
      // Withdraw: saldo dikurangi → rollback: saldo ditambah kembali
      batch.update(
        _firestore.collection('wallets').doc(transfer.fromWalletId),
        {'balance': FieldValue.increment(transfer.amount)},
      );
    } else {
      // ========== ROLLBACK TRANSFER ==========
      // Transfer: from dikurangi, to ditambah → rollback: from ditambah, to dikurangi
      batch.update(
        _firestore.collection('wallets').doc(transfer.fromWalletId),
        {'balance': FieldValue.increment(transfer.amount)},
      );
      batch.update(
        _firestore.collection('wallets').doc(transfer.toWalletId),
        {'balance': FieldValue.increment(-transfer.amount)},
      );
    }

    // Hapus history transfer
    batch.delete(_firestore.collection(_collection).doc(transfer.id));

    await batch.commit();
  }

}