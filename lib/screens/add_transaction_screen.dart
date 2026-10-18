import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/category_model.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import '../services/category_service.dart';
import '../services/ocr_service.dart';
import '../widgets/searchable_chip_picker.dart';
import '../widgets/voice_input_modal.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import 'category_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final String? prefilledTitle;
  final double? prefilledAmount;
  final TransactionType? prefilledType;
  final String? prefilledCategory;
  final String? prefilledWalletId;

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.prefilledTitle,
    this.prefilledAmount,
    this.prefilledType,
    this.prefilledCategory,
    this.prefilledWalletId,
  });

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
  final OcrService _ocrService = OcrService();

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Makanan';
  DateTime _selectedDate = DateTime.now();
  String? _selectedWalletId;
  String? _selectedWalletName;
  bool _isLoading = false;
  bool _isScanning = false;
  List<WalletModel> _wallets = [];

  @override
  void initState() {
    super.initState();
    _loadWallets();

    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _amountController.text = CurrencyFormatHelper.format(widget.transaction!.amount);
      _descriptionController.text = widget.transaction!.description;
      _selectedType = widget.transaction!.type;
      _selectedCategory = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;
      _selectedWalletId = widget.transaction!.walletId;
      _selectedWalletName = widget.transaction!.walletName;
    } else {
      if (widget.prefilledTitle != null) {
        _titleController.text = widget.prefilledTitle!;
      } else {
        _titleController.text = _selectedCategory;
      }
      if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
        _amountController.text = CurrencyFormatHelper.format(widget.prefilledAmount!);
      }
      if (widget.prefilledType != null) _selectedType = widget.prefilledType!;
      if (widget.prefilledCategory != null) {
        _selectedCategory = widget.prefilledCategory!;
        if (widget.prefilledTitle == null) {
          _titleController.text = widget.prefilledCategory!;
        }
      }
      if (widget.prefilledWalletId != null) _selectedWalletId = widget.prefilledWalletId!;
    }
  }

  Future<void> _loadWallets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _walletService.getUserWallets(user.uid).listen((wallets) {
      if (mounted) {
        setState(() {
          _wallets = wallets;
          if (_selectedWalletId == null && _wallets.isNotEmpty) {
            final defaultW = _wallets.firstWhere(
              (w) => w.isDefault,
              orElse: () => _wallets.first,
            );
            _selectedWalletId = defaultW.id;
            _selectedWalletName = defaultW.name;
          } else if (_selectedWalletId != null && _wallets.isNotEmpty) {
            final current = _wallets.where((w) => w.id == _selectedWalletId).firstOrNull;
            if (current != null) {
              _selectedWalletName = current.name;
            }
          }
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

  void _addQuickAmount(double value) {
    HapticFeedback.selectionClick();
    final current = CurrencyFormatHelper.parse(_amountController.text);
    final updated = current + value;
    _amountController.text = CurrencyFormatHelper.format(updated);
    setState(() {});
  }

  Future<void> _openCategorySearch(List<String> allCategories, Color themeColor) async {
    HapticFeedback.lightImpact();
    final items = allCategories.map((cat) {
      return SearchableChipItem<String>(
        value: cat,
        label: cat,
        icon: AppConstants.getCategoryIcon(cat),
        iconColor: themeColor,
      );
    }).toList();

    final picked = await SearchableChipPicker.show<String>(
      context: context,
      title: 'Pilih Kategori',
      items: items,
      selectedValue: _selectedCategory,
      activeColor: themeColor,
      actionButton: TextButton.icon(
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryScreen(
                type: _selectedType == TransactionType.income ? 'income' : 'expense',
              ),
            ),
          );
        },
        icon: const Icon(Icons.tune_rounded, size: 16),
        label: const Text('Kelola', style: TextStyle(fontSize: 13)),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedCategory = picked;
        _titleController.text = picked;
      });
    }
  }

  Future<void> _openWalletSearch() async {
    HapticFeedback.lightImpact();
    final items = _wallets.map((w) {
      return SearchableChipItem<String>(
        value: w.id,
        label: w.name,
        icon: w.icon,
        iconColor: const Color(0xFF3B82F6),
        subtitle: 'Rp ${w.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
        badgeText: w.isDefault ? 'Utama' : null,
      );
    }).toList();

    final picked = await SearchableChipPicker.show<String>(
      context: context,
      title: 'Pilih Dompet / Rekening',
      items: items,
      selectedValue: _selectedWalletId,
      activeColor: const Color(0xFF3B82F6),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedWalletId = picked;
        _selectedWalletName = _wallets.firstWhere((w) => w.id == picked).name;
      });
    }
  }

  Future<void> _showScanReceiptSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pindai Struk / Nota Belanja',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: const Text('Ambil Foto Struk (Kamera)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Arahkan kamera ke struk belanja Anda', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _processReceiptScan(ImageSource.camera);
                },
              ),
              const Divider(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF3B82F6), size: 22),
                ),
                title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Gunakan foto struk yang sudah ada', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _processReceiptScan(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processReceiptScan(ImageSource source) async {
    setState(() => _isScanning = true);
    try {
      final parsed = await _ocrService.scanReceipt(source: source);
      if (parsed != null && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          if (parsed.merchantName != null && parsed.merchantName!.isNotEmpty) {
            _titleController.text = parsed.merchantName!;
          }
          if (parsed.totalAmount != null && parsed.totalAmount! > 0) {
            _amountController.text = CurrencyFormatHelper.format(parsed.totalAmount!);
          }
          if (parsed.date != null) {
            _selectedDate = parsed.date!;
          }
          if (parsed.suggestedCategory != null) {
            _selectedCategory = parsed.suggestedCategory!;
          }
          _selectedType = TransactionType.expense;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              parsed.merchantName != null
                  ? '✓ Struk "${parsed.merchantName}" berhasil dipindai!'
                  : '✓ Data struk berhasil diekstrak!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memindai struk: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyFormatHelper.parse(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah nominal harus lebih dari 0')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak login');

      final transaction = TransactionModel(
        id: widget.transaction?.id ?? '',
        userId: user.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: amount,
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
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.transaction != null ? '✓ Transaksi diperbarui' : '✓ Transaksi berhasil disimpan',
            ),
            backgroundColor: const Color(0xFF10B981),
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
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final now = DateTime.now();
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          now.hour,
          now.minute,
          now.second,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpense = _selectedType == TransactionType.expense;
    final themeColor = isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.transaction != null ? 'Edit Transaksi' : 'Catat Transaksi',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Scan Struk Button
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    )
                  : const Icon(Icons.document_scanner_rounded, size: 20, color: Color(0xFF10B981)),
              tooltip: 'Scan Struk / Nota',
              onPressed: _isScanning ? null : _showScanReceiptSheet,
            ),
          ),
          // Voice Assistant Button
          Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              icon: const Icon(Icons.mic_rounded, size: 20, color: Color(0xFF3B82F6)),
              tooltip: 'Catat Lewat Suara',
              onPressed: () => VoiceInputModal.show(context),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Tab Selector (Pengeluaran / Pemasukan)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        'Pengeluaran',
                        TransactionType.expense,
                        const Color(0xFFEF4444),
                      ),
                    ),
                    Expanded(
                      child: _buildTypeButton(
                        'Pemasukan',
                        TransactionType.income,
                        const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // HERO AMOUNT INPUT CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nominal ${isExpense ? "Pengeluaran" : "Pemasukan"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CurrencyInputFormatter(),
                            ],
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              letterSpacing: 0.5,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white24 : Colors.grey.shade400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Masukkan nominal';
                              final amount = CurrencyFormatHelper.parse(val);
                              if (amount <= 0) return 'Nominal harus > 0';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick Nominal Pills (+10k, +20k, +50k, +100k, +500k)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildQuickChip('+10rb', 10000, themeColor, isDark),
                          const SizedBox(width: 6),
                          _buildQuickChip('+20rb', 20000, themeColor, isDark),
                          const SizedBox(width: 6),
                          _buildQuickChip('+50rb', 50000, themeColor, isDark),
                          const SizedBox(width: 6),
                          _buildQuickChip('+100rb', 100000, themeColor, isDark),
                          const SizedBox(width: 6),
                          _buildQuickChip('+500rb', 500000, themeColor, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KATEGORI (Stream Real-time)
              if (user != null)
                StreamBuilder<List<CategoryModel>>(
                  stream: _categoryService.getUserCategories(
                    user.uid,
                    _selectedType == TransactionType.income ? 'income' : 'expense',
                  ),
                  builder: (context, snapshot) {
                    final defaultList = _selectedType == TransactionType.income
                        ? AppConstants.defaultIncomeCategories
                        : AppConstants.defaultExpenseCategories;
                    final customList = snapshot.data?.map((c) => c.name).toList() ?? [];
                    final allCategories = {...defaultList, ...customList}.toList();

                    if (!allCategories.contains(_selectedCategory)) {
                      _selectedCategory = allCategories.first;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kategori',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _openCategorySearch(allCategories, themeColor),
                              child: Row(
                                children: [
                                  Icon(Icons.search_rounded, size: 14, color: themeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Semua Kategori',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: themeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Horizontal Round Chips
                        SizedBox(
                          height: 42,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: allCategories.length,
                            itemBuilder: (context, index) {
                              final cat = allCategories[index];
                              final isSelected = _selectedCategory == cat;
                              final icon = AppConstants.getCategoryIcon(cat);

                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedCategory = cat;
                                    _titleController.text = cat;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? themeColor
                                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? themeColor
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: themeColor.withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icon,
                                        size: 16,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : Colors.grey.shade700),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        cat,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                        ),
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
              const SizedBox(height: 18),

              // DOMPET / REKENING ASAL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dompet / Rekening',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  if (_wallets.length > 3)
                    GestureDetector(
                      onTap: _openWalletSearch,
                      child: const Text(
                        'Pilih Semua →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_wallets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('Belum ada dompet terdaftar', style: TextStyle(fontSize: 12, color: Colors.grey)),
                )
              else
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = _wallets[index];
                      final isSelected = _selectedWalletId == wallet.id;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedWalletId = wallet.id;
                            _selectedWalletName = wallet.name;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF3B82F6)
                                : (isDark ? const Color(0xFF1E293B) : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                wallet.icon,
                                size: 16,
                                color: isSelected ? Colors.white : const Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    wallet.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                    ),
                                  ),
                                  Text(
                                    'Rp ${wallet.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isSelected ? Colors.white70 : Colors.grey.shade500,
                                    ),
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
              const SizedBox(height: 18),

              // JUDUL TRANSAKSI
              Text(
                'Judul / Keterangan Singkat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Nasi Padang, Bensin Shell, Token Listrik',
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Masukkan judul transaksi';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // TANGGAL TRANSAKSI
              Text(
                'Tanggal Transaksi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: themeColor),
                          const SizedBox(width: 10),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Ubah',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          widget.transaction != null ? 'Perbarui Transaksi' : 'Simpan Transaksi',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, TransactionType type, Color color) {
    final isSelected = _selectedType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (_selectedType != type) {
          final oldCat = _selectedCategory;
          final newDefaultCat = type == TransactionType.income ? 'Gaji' : 'Makanan';
          setState(() {
            _selectedType = type;
            _selectedCategory = newDefaultCat;
            if (_titleController.text.isEmpty || _titleController.text == oldCat) {
              _titleController.text = newDefaultCat;
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.grey.shade700),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, double value, Color color, bool isDark) {
    return GestureDetector(
      onTap: () => _addQuickAmount(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}