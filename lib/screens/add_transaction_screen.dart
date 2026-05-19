import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/category_model.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import '../services/category_service.dart';
import 'category_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TransactionService _transactionService = TransactionService();
  final WalletService _walletService = WalletService();
  final CategoryService _categoryService = CategoryService();

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Makanan';
  DateTime _selectedDate = DateTime.now();
  String? _selectedWalletId;
  String? _selectedWalletName;
  bool _isLoading = false;
  List<WalletModel> _wallets = [];

  @override
  void initState() {
    super.initState();
    _loadWallets();
    
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      _descriptionController.text = widget.transaction!.description;
      _selectedType = widget.transaction!.type;
      _selectedCategory = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;
      _selectedWalletId = widget.transaction!.walletId;
      _selectedWalletName = widget.transaction!.walletName;
    }
  }

  Future<void> _loadWallets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _walletService.getUserWallets(user.uid).listen((wallets) {
      if (mounted) {
        setState(() {
          _wallets = wallets;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak login');

      final transaction = TransactionModel(
        id: widget.transaction?.id ?? '',
        userId: user.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        type: _selectedType,
        category: _selectedCategory,
        date: _selectedDate,
        createdAt: widget.transaction?.createdAt ?? DateTime.now(),
        walletId: _selectedWalletId,
        walletName: _selectedWalletName,
      );

      if (widget.transaction != null) {
        await _transactionService.updateTransaction(widget.transaction!, transaction);
      } else {
        await _transactionService.addTransaction(transaction);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.transaction != null ? 'Transaksi diperbarui' : 'Transaksi ditambahkan',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null ? 'Edit Transaksi' : 'Tambah Transaksi',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selector
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton('Pengeluaran', TransactionType.expense, Colors.red),
                    ),
                    Expanded(
                      child: _buildTypeButton('Pemasukan', TransactionType.income, Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Jumlah',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Jumlah tidak boleh kosong';
                  if (double.tryParse(value) == null) return 'Jumlah tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Judul',
                  hintText: 'Contoh: Makan siang',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Judul tidak boleh kosong';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // KATEGORI DENGAN TOMBOL KELOLA
              StreamBuilder<List<CategoryModel>>(
                stream: user != null 
                    ? _categoryService.getUserCategories(
                        user.uid,
                        _selectedType == TransactionType.income ? 'income' : 'expense',
                      )
                    : null,
                builder: (context, snapshot) {
                  final customCategories = snapshot.data ?? [];
                  
                  final defaultCategories = _selectedType == TransactionType.income
                      ? ['Ngojol']
                      : ['Makanan'];

                  final allCategories = [
                    ...defaultCategories,
                    ...customCategories.map((c) => c.name),
                  ];

                  if (!allCategories.contains(_selectedCategory)) {
                    _selectedCategory = allCategories.first;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CategoryScreen(
                                    type: _selectedType == TransactionType.income ? 'income' : 'expense',
                                  ),
                                ),
                              ).then((_) => setState(() {}));
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Kelola'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: allCategories.contains(_selectedCategory) ? _selectedCategory : allCategories.first,
                        decoration: InputDecoration(
                          labelText: 'Pilih Kategori',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: allCategories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategory = value!);
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Sumber Dana / Wallet
              DropdownButtonFormField<String>(
                value: _selectedWalletId,
                decoration: InputDecoration(
                  labelText: 'Sumber Dana',
                  hintText: 'Pilih dompet atau cash',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  // const DropdownMenuItem(
                  //   value: null,
                  //   child: Row(
                  //     children: [
                  //       Icon(Icons.money, color: Colors.green),
                  //       SizedBox(width: 8),
                  //       Text('Cash (Tunai)'),
                  //     ],
                  //   ),
                  // ),
                  ..._wallets.map((wallet) => DropdownMenuItem(
                    value: wallet.id,
                    child: Row(
                      children: [
                        Icon(wallet.icon, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('${wallet.name} (Rp ${wallet.balance.toStringAsFixed(0)})'),
                      ],
                    ),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedWalletId = value;
                    _selectedWalletName = value == null 
                        ? 'Cash' 
                        : _wallets.firstWhere((w) => w.id == value).name;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Deskripsi (Opsional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType == TransactionType.expense
                        ? Colors.red.shade600
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.transaction != null ? 'PERBARUI' : 'SIMPAN',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, TransactionType type, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedCategory = type == TransactionType.income
              ? 'Gaji'
              : 'Makanan';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}