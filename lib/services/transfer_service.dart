import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transfer_model.dart';
import '../models/wallet_model.dart';

class TransferService {
  final FirebaseFirestore _firestore;
  final String _collection = 'transfers';

  TransferService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Transfer antar wallet (atomic dengan batch)
  // Future<void> transferBetweenWallets({
  //   required String userId,
  //   required WalletModel fromWallet,
  //   required WalletModel toWallet,
  //   required double amount,
  //   String? note,
  // }) async {
  //   if (amount <= 0) throw Exception('Jumlah harus lebih dari 0');
  //   if (fromWallet.id == toWallet.id) throw Exception('Tidak bisa transfer ke wallet yang sama');
  //   if (fromWallet.balance < amount) throw Exception('Saldo tidak mencukupi');

  //   final batch = _firestore.batch();
  //   final now = DateTime.now();

  //   // 1. Kurangi saldo wallet asal
  //   batch.update(
  //     _firestore.collection('wallets').doc(fromWallet.id),
  //     {'balance': FieldValue.increment(-amount)},
  //   );

  //   // 2. Tambah saldo wallet tujuan
  //   batch.update(
  //     _firestore.collection('wallets').doc(toWallet.id),
  //     {'balance': FieldValue.increment(amount)},
  //   );

  //   // 3. Catat history transfer
  //   final transferRef = _firestore.collection(_collection).doc();
  //   final transfer = TransferModel(
  //     id: transferRef.id,
  //     userId: userId,
  //     fromWalletId: fromWallet.id,
  //     fromWalletName: fromWallet.name,
  //     toWalletId: toWallet.id,
  //     toWalletName: toWallet.name,
  //     amount: amount,
  //     type: TransferType.transfer,
  //     note: note,
  //     createdAt: now,
  //   );

  //   batch.set(transferRef, transfer.toFirestore());

  //   await batch.commit();
  // }

  /// Withdraw (keluarkan uang dari wallet, tidak masuk ke wallet lain)
  // Future<void> withdrawFromWallet({
  //   required String userId,
  //   required WalletModel fromWallet,
  //   required double amount,
  //   String? note,
  //   String? destinationInfo, // misal: "Rekening BCA 1234"
  // }) async {
  //   if (amount <= 0) throw Exception('Jumlah harus lebih dari 0');
  //   if (fromWallet.balance < amount) throw Exception('Saldo tidak mencukupi');

  //   final batch = _firestore.batch();
  //   final now = DateTime.now();

  //   // 1. Kurangi saldo wallet
  //   batch.update(
  //     _firestore.collection('wallets').doc(fromWallet.id),
  //     {'balance': FieldValue.increment(-amount)},
  //   );

  //   // 2. Catat history withdraw
  //   final transferRef = _firestore.collection(_collection).doc();
  //   final transfer = TransferModel(
  //     id: transferRef.id,
  //     userId: userId,
  //     fromWalletId: fromWallet.id,
  //     fromWalletName: fromWallet.name,
  //     toWalletId: 'withdraw', // marker untuk withdraw
  //     toWalletName: destinationInfo ?? 'Withdraw',
  //     amount: amount,
  //     type: TransferType.withdraw,
  //     note: note ?? 'Penarikan dana',
  //     createdAt: now,
  //   );

  //   batch.set(transferRef, transfer.toFirestore());

  //   await batch.commit();
  // }

  // bagian overheat wallet transfer

  /// Transfer antar wallet dengan kondisi overdraft
  Future<void> transferBetweenWallets({
    required String userId,
    required WalletModel fromWallet,
    required WalletModel toWallet,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) throw Exception('Jumlah harus lebih dari 0');
    if (fromWallet.id == toWallet.id) throw Exception('Tidak bisa transfer ke wallet yang sama');

    // ===== CEK KONDISI OVERDRAFT =====
    if (!fromWallet.canTransfer(amount)) {
      throw Exception(
        'Saldo tidak mencukupi! '
        'Saldo ${fromWallet.name}: ${_formatCurrency(fromWallet.balance)}, '
        'Dibutuhkan: ${_formatCurrency(amount)}'
      );
    }

    // ===== KHUSUS BANK: DOUBLE CHECK =====
    if (fromWallet.type == 'bank' && fromWallet.balance < amount) {
      throw Exception(
        'Rekening bank tidak boleh minus. '
        'Silakan top-up saldo terlebih dahulu.'
      );
    }

    final batch = _firestore.batch();
    final now = DateTime.now();

    // 1. Kurangi saldo wallet asal (boleh minus untuk non-bank)
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
      note: note ?? (fromWallet.supportsOverdraft ? 'Transfer (Overdraft)' : 'Transfer'),
      createdAt: now,
    );

    batch.set(transferRef, transfer.toFirestore());
    await batch.commit();
  }

  /// Withdraw dengan kondisi overdraft
  Future<void> withdrawFromWallet({
    required String userId,
    required WalletModel fromWallet,
    required double amount,
    String? note,
    String? destinationInfo,
  }) async {
    if (amount <= 0) throw Exception('Jumlah harus lebih dari 0');

    // ===== CEK KONDISI OVERDRAFT =====
    if (!fromWallet.canTransfer(amount)) {
      throw Exception(
        'Saldo tidak mencukupi untuk withdraw! '
        'Saldo ${fromWallet.name}: ${_formatCurrency(fromWallet.balance)}'
      );
    }

    // ===== KHUSUS BANK: DOUBLE CHECK =====
    if (fromWallet.type == 'bank' && fromWallet.balance < amount) {
      throw Exception(
        'Rekening bank tidak boleh ditarik melebihi saldo. '
        'Silakan kurangi jumlah atau top-up terlebih dahulu.'
      );
    }

    final batch = _firestore.batch();
    final now = DateTime.now();

    // 1. Kurangi saldo wallet (boleh minus untuk non-bank)
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
      toWalletId: 'withdraw',
      toWalletName: destinationInfo ?? 'Withdraw',
      amount: amount,
      type: TransferType.withdraw,
      note: note ?? (fromWallet.supportsOverdraft ? 'Withdraw (Overdraft)' : 'Withdraw'),
      createdAt: now,
    );

    batch.set(transferRef, transfer.toFirestore());
    await batch.commit();
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

// end overheat wallet transfer



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