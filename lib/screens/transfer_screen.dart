import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wallet_model.dart';
import '../models/transfer_model.dart';
import '../services/wallet_service.dart';
import '../services/transfer_service.dart';

class TransferScreen extends StatefulWidget {
  final WalletModel? initialFromWallet;
  
  const TransferScreen({super.key, this.initialFromWallet});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final WalletService _walletService = WalletService();
  final TransferService _transferService = TransferService();
  
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _destinationController = TextEditingController(); // untuk withdraw
  
  bool _isLoading = false;
  TransferType _selectedType = TransferType.transfer;
  
  WalletModel? _fromWallet;
  WalletModel? _toWallet;
  List<WalletModel> _wallets = [];

  @override
  void initState() {
    super.initState();
    _fromWallet = widget.initialFromWallet;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _showWalletPicker({required bool isFrom}) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFrom ? 'Pilih Wallet Asal' : 'Pilih Wallet Tujuan',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._wallets.map((wallet) {
              // Jika picker "to", exclude wallet yang dipilih di "from"
              if (!isFrom && wallet.id == _fromWallet?.id) return const SizedBox.shrink();
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade50,
                  child: Icon(wallet.icon, color: Colors.purple.shade600),
                ),
                title: Text(wallet.name),
                subtitle: Text('Saldo: ${wallet.balance.toStringAsFixed(0)}'),
                trailing: Text(
                  'Rp ${wallet.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  setState(() {
                    if (isFrom) {
                      _fromWallet = wallet;
                      // Reset to wallet kalau sama dengan from
                      if (_toWallet?.id == wallet.id) _toWallet = null;
                    } else {
                      _toWallet = wallet;
                    }
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _executeTransfer() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      _showError('Masukkan jumlah yang valid');
      return;
    }

    if (_fromWallet == null) {
      _showError('Pilih wallet asal');
      return;
    }

    if (_selectedType == TransferType.transfer && _toWallet == null) {
      _showError('Pilih wallet tujuan');
      return;
    }

    if (_selectedType == TransferType.withdraw && _destinationController.text.isEmpty) {
      _showError('Masukkan tujuan withdraw');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak login');

      if (_selectedType == TransferType.transfer) {
        await _transferService.transferBetweenWallets(
          userId: user.uid,
          fromWallet: _fromWallet!,
          toWallet: _toWallet!,
          amount: amount,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
      } else {
        await _transferService.withdrawFromWallet(
          userId: user.uid,
          fromWallet: _fromWallet!,
          amount: amount,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          destinationInfo: _destinationController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedType == TransferType.transfer
                  ? 'Transfer berhasil!'
                  : 'Withdraw berhasil!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Silakan login')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer / Withdraw'),
      ),
      body: StreamBuilder<List<WalletModel>>(
        stream: _walletService.getUserWallets(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          _wallets = snapshot.data ?? [];
          
          // Auto-select first wallet kalau belum ada selection
          if (_fromWallet == null && _wallets.isNotEmpty) {
            _fromWallet = _wallets.first;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pilihan Tipe: Transfer vs Withdraw
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedType = TransferType.transfer),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _selectedType == TransferType.transfer
                                  ? Colors.purple.shade600
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  color: _selectedType == TransferType.transfer
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Transfer',
                                  style: TextStyle(
                                    color: _selectedType == TransferType.transfer
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedType = TransferType.withdraw),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _selectedType == TransferType.withdraw
                                  ? Colors.orange.shade600
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  color: _selectedType == TransferType.withdraw
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    color: _selectedType == TransferType.withdraw
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Wallet Asal
                const Text('Dari Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showWalletPicker(isFrom: true),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _fromWallet?.icon ?? Icons.account_balance_wallet,
                          color: Colors.purple.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fromWallet?.name ?? 'Pilih Wallet',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (_fromWallet != null)
                                Text(
                                  'Saldo: ${_fromWallet!.balance.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Arrow indicator (hanya untuk transfer)
                if (_selectedType == TransferType.transfer) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_downward, color: Colors.purple.shade600),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Wallet Tujuan
                  const Text('Ke Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showWalletPicker(isFrom: false),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _toWallet?.icon ?? Icons.account_balance_wallet,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _toWallet?.name ?? 'Pilih Wallet Tujuan',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (_toWallet != null)
                                  Text(
                                    'Saldo: ${_toWallet!.balance.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Withdraw: Tujuan Penarikan
                if (_selectedType == TransferType.withdraw) ...[
                  const Text('Tujuan Penarikan', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Rekening BCA 1234567890',
                      prefixIcon: const Icon(Icons.account_balance),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Jumlah
                const Text('Jumlah', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_fromWallet != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Saldo tersedia: Rp ${_fromWallet!.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 20),

                // Catatan
                const Text('Catatan (Opsional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Tambahkan catatan...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),

                // Tombol Eksekusi
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _executeTransfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedType == TransferType.transfer
                          ? Colors.purple.shade600
                          : Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedType == TransferType.transfer
                                    ? Icons.swap_horiz
                                    : Icons.arrow_upward,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedType == TransferType.transfer
                                    ? 'TRANSFER SEKARANG'
                                    : 'WITHDRAW SEKARANG',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}