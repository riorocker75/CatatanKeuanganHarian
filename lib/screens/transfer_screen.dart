import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wallet_model.dart';
import '../models/transfer_model.dart';
import '../services/wallet_service.dart';
import '../services/transfer_service.dart';
import '../utils/currency_formatter.dart';

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

  void _addQuickAmount(double value) {
    HapticFeedback.selectionClick();
    final current = CurrencyFormatHelper.parse(_amountController.text);
    final updated = current + value;
    _amountController.text = CurrencyFormatHelper.format(updated);
    setState(() {});
  }

  void _showWalletPicker({required bool isFrom}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isFrom ? 'Pilih Dompet Asal' : 'Pilih Dompet Tujuan',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.builder(
                    itemCount: _wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = _wallets[index];
                      
                      if (!isFrom && wallet.id == _fromWallet?.id) {
                        return const SizedBox.shrink();
                      }
                      
                      if (isFrom && wallet.id == _toWallet?.id) {
                        return const SizedBox.shrink();
                      }

                      final isSelected = isFrom
                          ? _fromWallet?.id == wallet.id
                          : _toWallet?.id == wallet.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50)
                              : (isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.purple.shade400 : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: wallet.supportsOverdraft
                                  ? Colors.orange.shade100.withOpacity(0.3)
                                  : Colors.purple.shade100.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              wallet.icon,
                              color: wallet.supportsOverdraft ? Colors.orange.shade600 : Colors.purple.shade600,
                            ),
                          ),
                          title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Saldo: ${_formatCurrency(wallet.balance)}',
                            style: TextStyle(
                              color: wallet.balance < 0 ? Colors.red : Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded, color: Colors.purple.shade600)
                              : const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            setModalState(() {});
                            setState(() {
                              if (isFrom) {
                                _fromWallet = wallet;
                                if (_toWallet?.id == wallet.id) _toWallet = null;
                              } else {
                                _toWallet = wallet;
                                if (_fromWallet?.id == wallet.id) _fromWallet = null;
                              }
                            });
                            Navigator.pop(context);
                          },
                        ),
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
    final amount = CurrencyFormatHelper.parse(_amountController.text);
    if (amount <= 0) {
      _showError('Masukkan jumlah yang valid');
      return;
    }

    if (_fromWallet == null) {
      _showError('Pilih dompet asal');
      return;
    }

    if (_selectedType == TransferType.transfer && _toWallet == null) {
      _showError('Pilih dompet tujuan');
      return;
    }

    if (_selectedType == TransferType.withdraw && _destinationController.text.isEmpty) {
      _showError('Masukkan tujuan penarikan');
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
                  ? 'Transfer berhasil diselesaikan!'
                  : 'Penarikan berhasil dicatat!',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTransfer = _selectedType == TransferType.transfer;
    final themeColor = isTransfer ? const Color(0xFF8B5CF6) : const Color(0xFFF97316);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer / Withdraw', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmented Toggle
                _buildTypeToggle(),
                const SizedBox(height: 20),

                // HERO AMOUNT INPUT CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2430) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTransfer ? 'Nominal Transfer' : 'Nominal Penarikan (Withdraw)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Rp',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_fromWallet != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Saldo sumber: ${_formatCurrency(_fromWallet!.balance)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                            if (_fromWallet!.supportsOverdraft) ...[
                              const SizedBox(width: 6),
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
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const Divider(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickChip('+50k', 50000),
                            _buildQuickChip('+100k', 100000),
                            _buildQuickChip('+250k', 250000),
                            _buildQuickChip('+500k', 500000),
                            _buildQuickChip('+1jt', 1000000),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // WALLET ASAL
                const Text('Dari Dompet / Rekening', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                _buildWalletPickerCard('Pilih Dompet Asal', _fromWallet, isFrom: true),
                const SizedBox(height: 14),

                // Arrow Divider (Transfer)
                if (isTransfer) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.purple.shade900.withOpacity(0.4) : Colors.purple.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.purple.shade300, width: 1.2),
                      ),
                      child: Icon(Icons.arrow_downward_rounded, color: Colors.purple.shade400, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // WALLET TUJUAN
                  const Text('Ke Dompet / Rekening Tujuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  _buildWalletPickerCard('Pilih Dompet Tujuan', _toWallet, isFrom: false),
                  const SizedBox(height: 18),
                ],

                // WITHDRAW: TUJUAN PENARIKAN
                if (!isTransfer) ...[
                  const Text('Tujuan Penarikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  _buildInputContainer(
                    isDark: isDark,
                    child: TextFormField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        labelText: 'Nomor Rekening / E-Wallet Tujuan',
                        hintText: 'Contoh: Rekening BCA 1234567890 a/n John',
                        prefixIcon: _buildIconBadge(Icons.account_balance_rounded, Colors.orange),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // CATATAN
                const Text('Catatan (Opsional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                _buildInputContainer(
                  isDark: isDark,
                  child: TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Keterangan Transfer',
                      hintText: 'Tambahkan catatan...',
                      prefixIcon: _buildIconBadge(Icons.notes_rounded, Colors.blue),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // TOMBOL EKSEKUSI (Clean Pill CTA)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _executeTransfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: themeColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isTransfer ? Icons.swap_horiz_rounded : Icons.arrow_upward_rounded),
                              const SizedBox(width: 8),
                              Text(
                                isTransfer ? 'TRANSFER SEKARANG' : 'WITHDRAW SEKARANG',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = TransferType.transfer),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == TransferType.transfer
                      ? const Color(0xFF8B5CF6)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedType == TransferType.transfer
                      ? [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      color: _selectedType == TransferType.transfer ? Colors.white : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Transfer Dompet',
                      style: TextStyle(
                        color: _selectedType == TransferType.transfer ? Colors.white : Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == TransferType.withdraw
                      ? const Color(0xFFF97316)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedType == TransferType.withdraw
                      ? [
                          BoxShadow(
                            color: const Color(0xFFF97316).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: _selectedType == TransferType.withdraw ? Colors.white : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Withdraw / Tarik',
                      style: TextStyle(
                        color: _selectedType == TransferType.withdraw ? Colors.white : Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }

  Widget _buildWalletPickerCard(String label, WalletModel? wallet, {bool isFrom = true}) {
    final isSelected = wallet != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => _showWalletPicker(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Colors.purple.shade400 
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.2,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected 
              ? (isDark ? Colors.purple.shade900.withOpacity(0.2) : Colors.purple.shade50) 
              : (isDark ? const Color(0xFF1E2430) : Colors.white),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: wallet != null
                    ? (wallet.supportsOverdraft
                        ? (isDark ? Colors.orange.shade900.withOpacity(0.4) : Colors.orange.shade100)
                        : (isDark ? Colors.purple.shade900.withOpacity(0.4) : Colors.purple.shade100))
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                wallet?.icon ?? Icons.account_balance_wallet_rounded,
                color: wallet != null
                    ? (wallet.supportsOverdraft
                        ? Colors.orange.shade400
                        : Colors.purple.shade400)
                    : Colors.grey.shade400,
                size: 22,
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
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected 
                          ? (isDark ? Colors.white : Colors.black87) 
                          : Colors.grey.shade500,
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
                            color: wallet.balance < 0 ? Colors.red : Colors.grey.shade500,
                          ),
                        ),
                        if (wallet.supportsOverdraft) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Overdraft',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade400,
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
              isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: isSelected ? Colors.purple.shade400 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputContainer({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildQuickChip(String label, double amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _addQuickAmount(amount),
        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF0F172A),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}