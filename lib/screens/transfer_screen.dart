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
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFrom ? 'Pilih Wallet Asal' : 'Pilih Wallet Tujuan',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = _wallets[index];
                    
                    // ==== FILTER WALLET ====
                    // Kalau pilih tujuan, sembunyikan wallet asal
                    if (!isFrom && wallet.id == _fromWallet?.id) {
                      return const SizedBox.shrink();
                    }
                    
                    // Kalau pilih asal, sembunyikan wallet tujuan (opsional)
                    if (isFrom && wallet.id == _toWallet?.id) {
                      return const SizedBox.shrink();
                    }

                    // ==== CEK SELECTED ====
                    final isSelected = isFrom
                        ? _fromWallet?.id == wallet.id
                        : _toWallet?.id == wallet.id;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: wallet.supportsOverdraft
                            ? Colors.orange.shade50
                            : Colors.blue.shade50,
                        child: Icon(
                          wallet.icon,
                          color: wallet.supportsOverdraft
                              ? Colors.orange.shade600
                              : Colors.blue.shade600,
                        ),
                      ),
                      title: Text(wallet.name),
                      subtitle: Text(
                        'Saldo: ${_formatCurrency(wallet.balance)}',
                        style: TextStyle(
                          color: wallet.balance < 0 ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Colors.green.shade600)
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        // Update modal state
                        setModalState(() {});
                        
                        // Update parent state — HANYA YANG DIPILIH
                        setState(() {
                          if (isFrom) {
                            _fromWallet = wallet;
                            // Reset tujuan kalau sama dengan asal baru
                            if (_toWallet?.id == wallet.id) {
                              _toWallet = null;
                            }
                          } else {
                            _toWallet = wallet;
                            // Reset asal kalau sama dengan tujuan baru
                            if (_fromWallet?.id == wallet.id) {
                              _fromWallet = null;
                            }
                          }
                        });
                        
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
      appBar: AppBar(title: const Text('Transfer / Withdraw')),
      body: StreamBuilder<List<WalletModel>>(
        stream: _walletService.getUserWallets(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          _wallets = snapshot.data ?? [];
          
          if (_fromWallet == null && _wallets.isNotEmpty) {
          _fromWallet = _wallets.first;
        }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle Transfer / Withdraw
                _buildTypeToggle(),
                const SizedBox(height: 24),

                // Wallet Asal
               // ===== WALLET ASAL =====
              const Text('Dari Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildWalletPickerCard('Pilih Wallet Asal', _fromWallet),
              const SizedBox(height: 20),

                // Arrow (hanya transfer)
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

                   // ===== WALLET TUJUAN =====
                const Text('Ke Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildWalletPickerCard(
                  'Pilih Wallet Tujuan',
                  _toWallet,
                  isFrom: false,
                ),
                const SizedBox(height: 20),
              ],
                // Withdraw: Tujuan
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
                  Row(
                    children: [
                      Text(
                        'Saldo tersedia: ${_formatCurrency(_fromWallet!.balance)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (_fromWallet!.supportsOverdraft) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Bisa minus',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                              Icon(_selectedType == TransferType.transfer
                                  ? Icons.swap_horiz
                                  : Icons.arrow_upward),
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

  Widget _buildTypeToggle() {
    return Container(
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
    );
  }


   Widget _buildFromWalletCard(WalletModel? wallet) {
    if (wallet == null) {
      return _buildWalletPickerCard('Pilih Wallet Asal', null);
    }

    final canOverdraft = wallet.supportsOverdraft;
    final isBalanceLow = wallet.balance <= 0;

    return GestureDetector(
      onTap: () => _showWalletPicker(isFrom: true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isBalanceLow && !canOverdraft
                ? Colors.red.shade300
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isBalanceLow && canOverdraft
              ? Colors.orange.shade50
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: canOverdraft
                    ? Colors.orange.shade100
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                wallet.icon,
                color: canOverdraft
                    ? Colors.orange.shade700
                    : Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Text(
                        'Saldo: ${_formatCurrency(wallet.balance)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: wallet.balance < 0
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (canOverdraft) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Overdraft',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (wallet.balance < 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Saldo minus tersedia untuk transfer',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }

Widget _buildWalletPickerCard(String label, WalletModel? wallet, {bool isFrom = true}) {
  final isSelected = wallet != null;
  
  return GestureDetector(
    onTap: () => _showWalletPicker(isFrom: isFrom),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.purple.shade300 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.purple.shade50 : Colors.white,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? (wallet!.supportsOverdraft
                      ? Colors.orange.shade100
                      : Colors.purple.shade100)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              wallet?.icon ?? Icons.account_balance_wallet,
              color: isSelected
                  ? (wallet!.supportsOverdraft
                      ? Colors.orange.shade700
                      : Colors.purple.shade700)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet?.name ?? label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
                if (wallet != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Saldo: ${_formatCurrency(wallet.balance)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: wallet.balance < 0
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (wallet.supportsOverdraft) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Overdraft',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(
            isSelected ? Icons.check_circle : Icons.chevron_right,
            color: isSelected ? Colors.green.shade600 : Colors.grey,
          ),
        ],
      ),
    ),
  );
}

  
}