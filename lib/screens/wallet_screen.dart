import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:keuangan_harian/screens/transfer_history_screen.dart';
import 'package:keuangan_harian/screens/transfer_screen.dart';
import '../models/wallet_model.dart';
import '../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  bool _isLoading = false;
  String _selectedType = 'cash';
  String? _editingWalletId; // ← BARU: Untuk edit mode

  final List<Map<String, dynamic>> _walletTypes = [
    {'value': 'cash', 'label': 'Cash / Tunai', 'icon': Icons.money},
    {'value': 'bank', 'label': 'Bank Account', 'icon': Icons.account_balance},
    {'value': 'e-wallet', 'label': 'E-Wallet', 'icon': Icons.phone_android},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  void _clearControllers() {
    _nameController.clear();
    _balanceController.clear();
    _accountNumberController.clear();
    _bankNameController.clear();
    _selectedType = 'cash';
    _editingWalletId = null;
  }

  void _setControllersForEdit(WalletModel wallet) {
    _nameController.text = wallet.name;
    _balanceController.text = wallet.balance.toString();
    _accountNumberController.text = wallet.accountNumber ?? '';
    _bankNameController.text = wallet.bankName ?? '';
    _selectedType = wallet.type;
    _editingWalletId = wallet.id;
  }

  Future<void> _saveWallet() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak login');

      final wallet = WalletModel(
        id: _editingWalletId ?? '', // ← BARU: Kalau edit pakai ID lama
        userId: user.uid,
        name: _nameController.text.trim(),
        type: _selectedType,
        balance: double.tryParse(_balanceController.text) ?? 0,
        accountNumber: _accountNumberController.text.isEmpty ? null : _accountNumberController.text,
        bankName: _bankNameController.text.isEmpty ? null : _bankNameController.text,
        createdAt: DateTime.now(),
      );

      if (_editingWalletId != null) {
        // Edit mode
        await _walletService.updateWallet(wallet);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dompet diperbarui'), backgroundColor: Colors.green),
          );
        }
      } else {
        // Add mode
        await _walletService.addWallet(wallet);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dompet berhasil ditambahkan'), backgroundColor: Colors.green),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _clearControllers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWallet(WalletModel wallet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Dompet'),
        content: Text(
          'Hapus dompet "${wallet.name}"?\n\n'
          'Semua transaksi terkait dompet ini juga akan dihapus!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        await _walletService.deleteWallet(wallet.id, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dompet dan transaksi terkait dihapus'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showAddWalletDialog({WalletModel? wallet}) {
    if (wallet != null) {
      _setControllersForEdit(wallet);
    } else {
      _clearControllers();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wallet != null ? 'Edit Dompet' : 'Tambah Dompet Baru',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Wallet Type
              const Text('Tipe Dompet', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: _walletTypes.map((type) {
                  final isSelected = _selectedType == type['value'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => _selectedType = type['value']),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.shade600 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              type['icon'],
                              color: isSelected ? Colors.white : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type['label'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.done,  
                onEditingComplete: () => FocusScope.of(context).unfocus(), 
                decoration: InputDecoration(
                  labelText: 'Nama Dompet',
                  hintText: 'Contoh: Dompet Utama',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,  
                onEditingComplete: () => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: 'Saldo',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              if (_selectedType == 'bank') ...[
                TextFormField(
                  controller: _bankNameController,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    labelText: 'Nama Bank',
                    hintText: 'Contoh: BCA, Mandiri, BRI',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    labelText: 'Nomor Rekening',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_selectedType == 'e-wallet') ...[
                TextFormField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    labelText: 'Nomor Telepon / ID',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveWallet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          wallet != null ? 'PERBARUI DOMPET' : 'TAMBAH DOMPET',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ).then((_) => _clearControllers());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Silakan login')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddWalletDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Transfer',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TransferHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Transfer',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TransferScreen(initialFromWallet: null),
              ),
            ),
  ),

        ],
      ),
      body: StreamBuilder<List<WalletModel>>(
        stream: _walletService.getUserWallets(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final wallets = snapshot.data ?? [];
          final totalBalance = wallets.fold(0.0, (sum, w) => sum + w.balance);

          return Column(
            children: [
              // Total Balance Card
              Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade600, Colors.purple.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Total Saldo Dompet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Rp. ${totalBalance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                       
                      ],
                    ),
                  ),

              // Wallets List dengan Swipe Edit & Delete
              Expanded(
                child: wallets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('Belum ada dompet', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        itemCount: wallets.length,
                        itemBuilder: (context, index) {
                          final wallet = wallets[index];
                          return Slidable(
                            
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              extentRatio: 0.40,
                              children: [
                                // Edit
                                
                                SlidableAction(
                                  onPressed: (_) => _showAddWalletDialog(wallet: wallet),
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit,
                                  
                                  flex: 1, // ← Bagi ruang sama rata
                                ),
                                // Delete
                                SlidableAction(
                                  onPressed: (_) => Navigator.push(context,
                                     MaterialPageRoute(
                                  builder: (_) => TransferScreen(initialFromWallet: wallet),
                                ),
                              ),
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.purple,
                                  icon: Icons.swap_horiz,
                                  
                                  flex: 1, // ← Bagi ruang sama rata
                               
                                ),
                                SlidableAction(
                                  onPressed: (_) => _deleteWallet(wallet),
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  
                                  flex: 1, // ← Bagi ruang sama rata
                               
                                ),
                                
                                
                              ],
                              
                            ),
                            
                            child: Container(
                               margin: const EdgeInsets.only(bottom: 12),  // ← MARGIN BOTTOM DI SINI
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(wallet.icon, color: Colors.purple.shade600),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          wallet.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                        ),
                                        if (wallet.bankName != null)
                                          Text(
                                            wallet.bankName!,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        if (wallet.accountNumber != null)
                                          Text(
                                            '•••• ${wallet.accountNumber!.substring(wallet.accountNumber!.length > 4 ? wallet.accountNumber!.length - 4 : 0)}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rp. ${wallet.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Geser untuk edit/hapus',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}