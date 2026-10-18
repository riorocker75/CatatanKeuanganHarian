import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/recurring_service.dart';
import '../services/wallet_service.dart';
import '../services/category_service.dart';
import '../services/holiday_service.dart';
import '../widgets/searchable_chip_picker.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import 'category_screen.dart';

class AddRecurringScreen extends StatefulWidget {
  const AddRecurringScreen({super.key});

  @override
  State<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends State<AddRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final RecurringService _recurringService = RecurringService();
  final WalletService _walletService = WalletService();
  final CategoryService _categoryService = CategoryService();
  final HolidayService _holidayService = HolidayService();
  bool _isLoading = false;

  TransactionType _selectedType = TransactionType.income;
  RecurringFrequency _selectedFrequency = RecurringFrequency.monthly;
  String _selectedCategory = 'Gaji';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int _targetDayOfMonth = 25;
  TimeOfDay _executionTime = const TimeOfDay(hour: 8, minute: 0);
  BusinessDayRule _selectedBusinessDayRule = BusinessDayRule.previousWorkingDay;

  String? _selectedWalletId;
  String? _selectedWalletName;
  List<WalletModel> _wallets = [];
  List<String> _categories = AppConstants.defaultIncomeCategories;

  @override
  void initState() {
    super.initState();
    _titleController.text = _selectedCategory;
    _holidayService.loadHolidaysForYear(DateTime.now().year);
    _holidayService.loadHolidaysForYear(DateTime.now().year + 1);
    _loadWalletsAndCategories();
  }

  Future<void> _loadWalletsAndCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _walletService.getUserWallets(user.uid).listen((wallets) {
      if (mounted) {
        setState(() {
          _wallets = wallets;
          if (_selectedWalletId == null && wallets.isNotEmpty) {
            final def = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
            _selectedWalletId = def.id;
            _selectedWalletName = def.name;
          }
        });
      }
    });

    _updateCategoryList();
  }

  Future<void> _updateCategoryList() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final typeStr = _selectedType == TransactionType.income ? 'income' : 'expense';
    final cats = await _categoryService.getAllCategories(user.uid, typeStr);
    if (mounted) {
      setState(() {
        _categories = cats;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _addQuickAmount(double value) {
    HapticFeedback.selectionClick();
    final current = CurrencyFormatHelper.parse(_amountController.text);
    final updated = current + value;
    _amountController.text = CurrencyFormatHelper.format(updated);
    setState(() {});
  }

  Future<void> _openCategorySearch(Color themeColor) async {
    final items = _categories.map((cat) {
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
    final items = _wallets.map((w) {
      return SearchableChipItem<String>(
        value: w.id,
        label: w.name,
        icon: w.icon,
        iconColor: Colors.purple.shade400,
        subtitle: 'Rp ${w.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
        badgeText: w.isDefault ? 'Utama' : null,
      );
    }).toList();

    final picked = await SearchableChipPicker.show<String>(
      context: context,
      title: 'Pilih Dompet / Rekening',
      items: items,
      selectedValue: _selectedWalletId,
      activeColor: Colors.purple.shade600,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedWalletId = picked;
        _selectedWalletName = _wallets.firstWhere((w) => w.id == picked).name;
      });
    }
  }

  Future<void> _saveRecurring() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak login');

      final amount = CurrencyFormatHelper.parse(_amountController.text);
      if (amount <= 0) throw Exception('Nominal harus lebih dari 0');

      DateTime initialStart = _startDate;
      DateTime lastGen;

      if (_selectedFrequency == RecurringFrequency.monthly) {
        final now = DateTime.now();
        final daysInThisMonth = DateTime(now.year, now.month + 1, 0).day;
        final day = _targetDayOfMonth > daysInThisMonth ? daysInThisMonth : _targetDayOfMonth;
        final thisMonthTarget = DateTime(now.year, now.month, day);
        final thisMonthExec = DateTime(now.year, now.month, day, _executionTime.hour, _executionTime.minute);

        if (now.isAfter(thisMonthExec)) {
          // Tanggal di bulan berjalan sudah lewat waktu eksekusinya -> Jadwalkan untuk bulan berikutnya
          var nextYear = now.year;
          var nextMonth = now.month + 1;
          if (nextMonth > 12) {
            nextYear += 1;
            nextMonth = 1;
          }
          final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          final nextD = _targetDayOfMonth > daysInNextMonth ? daysInNextMonth : _targetDayOfMonth;
          initialStart = DateTime(nextYear, nextMonth, nextD);
          lastGen = thisMonthTarget;
        } else {
          // Belum masuk/lewat di tanggal bulan tersebut -> tampung tanggal bulan ini
          initialStart = thisMonthTarget;
          var prevYear = now.year;
          var prevMonth = now.month - 1;
          if (prevMonth < 1) {
            prevYear -= 1;
            prevMonth = 12;
          }
          final daysInPrevMonth = DateTime(prevYear, prevMonth + 1, 0).day;
          final prevD = _targetDayOfMonth > daysInPrevMonth ? daysInPrevMonth : _targetDayOfMonth;
          lastGen = DateTime(prevYear, prevMonth, prevD);
        }
      } else if (_selectedFrequency == RecurringFrequency.weekly) {
        initialStart = _startDate;
        lastGen = initialStart.subtract(const Duration(days: 7));
      } else if (_selectedFrequency == RecurringFrequency.yearly) {
        initialStart = _startDate;
        lastGen = DateTime(initialStart.year - 1, initialStart.month, initialStart.day);
      } else {
        // Daily
        initialStart = _startDate;
        lastGen = initialStart.subtract(const Duration(days: 1));
      }

      final recurring = RecurringTransactionModel(
        id: '',
        userId: user.uid,
        title: _titleController.text.trim(),
        amount: amount,
        type: _selectedType,
        category: _selectedCategory,
        frequency: _selectedFrequency,
        startDate: initialStart,
        endDate: _endDate,
        lastGenerated: lastGen,
        isActive: true,
        walletId: _selectedWalletId,
        walletName: _selectedWalletName,
        businessDayRule: _selectedBusinessDayRule,
        targetDayOfMonth: _selectedFrequency == RecurringFrequency.monthly ? _targetDayOfMonth : null,
        executionHour: _executionTime.hour,
        executionMinute: _executionTime.minute,
      );

      await _recurringService.addRecurring(recurring);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedType == TransactionType.income
                  ? 'Pemasukan rutin otomatis berhasil disimpan'
                  : 'Pengeluaran rutin otomatis berhasil disimpan',
            ),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _executionTime,
      helpText: 'PILIH JAM MASUK / KELUAR',
    );
    if (picked != null) {
      setState(() => _executionTime = picked);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  String _getEffectivePreviewText() {
    final now = DateTime.now();
    DateTime targetDate;
    
    if (_selectedFrequency == RecurringFrequency.monthly) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final d = _targetDayOfMonth > daysInMonth ? daysInMonth : _targetDayOfMonth;
      targetDate = DateTime(now.year, now.month, d);
      final execNow = DateTime(targetDate.year, targetDate.month, targetDate.day, _executionTime.hour, _executionTime.minute);
      if (now.isAfter(execNow)) {
        var nextYear = now.year;
        var nextMonth = now.month + 1;
        if (nextMonth > 12) {
          nextYear += 1;
          nextMonth = 1;
        }
        final nextDays = DateTime(nextYear, nextMonth + 1, 0).day;
        final nextD = _targetDayOfMonth > nextDays ? nextDays : _targetDayOfMonth;
        targetDate = DateTime(nextYear, nextMonth, nextD);
      }
    } else {
      targetDate = _startDate;
    }

    final adjustedDate = _holidayService.getAdjustedDate(targetDate, _selectedBusinessDayRule);
    final dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    final adjDayName = dayNames[adjustedDate.weekday - 1];
    final adjDateStr = '$adjDayName, ${adjustedDate.day} ${monthNames[adjustedDate.month - 1]} ${adjustedDate.year}';
    final timeStr = '${_executionTime.hour.toString().padLeft(2, '0')}:${_executionTime.minute.toString().padLeft(2, '0')} WIB';

    if (_selectedBusinessDayRule != BusinessDayRule.none && targetDate.day != adjustedDate.day) {
      final rawDayName = dayNames[targetDate.weekday - 1];
      final diff = targetDate.difference(adjustedDate).inDays;
      final actionStr = diff > 0 ? 'Maju $diff hari' : 'Mundur ${-diff} hari';
      return 'Jadwal Riil: $adjDateStr pk $timeStr\n($actionStr dari tgl ${targetDate.day} karena hari $rawDayName / libur nasional)';
    }

    return 'Jadwal Riil: $adjDateStr pk $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpense = _selectedType == TransactionType.expense;
    final themeColor = isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final quickCats = _categories.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Transaksi Rutin', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Tab Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        'Pemasukan (Gaji)',
                        TransactionType.income,
                        const Color(0xFF10B981),
                      ),
                    ),
                    Expanded(
                      child: _buildTypeButton(
                        'Pengeluaran (Tagihan)',
                        TransactionType.expense,
                        const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
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
                      'Nominal Per Periode',
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
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Nominal tidak boleh kosong';
                              final amount = CurrencyFormatHelper.parse(value);
                              if (amount <= 0) return 'Nominal tidak valid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickChip('+100k', 100000),
                          _buildQuickChip('+500k', 500000),
                          _buildQuickChip('+1jt', 1000000),
                          _buildQuickChip('+5jt', 5000000),
                          _buildQuickChip('+10jt', 10000000),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title
              _buildInputContainer(
                isDark: isDark,
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul Transaksi Rutin',
                    hintText: _selectedType == TransactionType.income
                        ? 'Contoh: Gaji Bulanan PT ABC, Dividen'
                        : 'Contoh: Bayar Kost, Listrik PLN, Tagihan Internet',
                    prefixIcon: _buildIconBadge(Icons.repeat_rounded, Colors.teal),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Judul tidak boleh kosong';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 18),

              // KATEGORI (ROUND CHIPS SELECTOR)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton.icon(
                    onPressed: () => _openCategorySearch(themeColor),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Cari Semua...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...quickCats.map((cat) {
                      final isSelected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedCategory = cat;
                            _titleController.text = cat;
                          }),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? themeColor.withOpacity(isDark ? 0.25 : 0.15)
                                  : (isDark ? const Color(0xFF1E2430) : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? themeColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.8 : 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(AppConstants.getCategoryIcon(cat), size: 16, color: isSelected ? themeColor : Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? (isDark ? Colors.white : themeColor) : (isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.check_circle_rounded, size: 14, color: themeColor),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.more_horiz_rounded, size: 16),
                      label: const Text('Lainnya...'),
                      onPressed: () => _openCategorySearch(themeColor),
                      backgroundColor: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // DOMPET / REKENING TARGET (ROUND CARD SELECTOR)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Target Dompet / Rekening Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (_wallets.length > 2)
                    TextButton.icon(
                      onPressed: _openWalletSearch,
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Cari Dompet...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (_wallets.isEmpty)
                _buildInputContainer(
                  isDark: isDark,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Belum ada dompet.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _wallets.map((w) {
                      final isSelected = w.id == _selectedWalletId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedWalletId = w.id;
                              _selectedWalletName = w.name;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.purple.shade900.withOpacity(isDark ? 0.3 : 0.12)
                                  : (isDark ? const Color(0xFF1E2430) : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? Colors.purple.shade500 : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.8 : 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(w.icon, size: 18, color: isSelected ? Colors.purple.shade500 : Colors.purple.shade300),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          w.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? (isDark ? Colors.white : Colors.purple.shade700) : (isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        if (w.isDefault) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('Utama', style: TextStyle(fontSize: 8, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      'Rp ${w.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.check_circle_rounded, size: 16, color: Colors.purple.shade500),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),

              // Frequency
              const Text('Frekuensi Rutinitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFrequencyChip('Bulanan', RecurringFrequency.monthly),
                  _buildFrequencyChip('Harian', RecurringFrequency.daily),
                  _buildFrequencyChip('Mingguan', RecurringFrequency.weekly),
                  _buildFrequencyChip('Tahunan', RecurringFrequency.yearly),
                ],
              ),
              const SizedBox(height: 18),

              // Tanggal Target Eksekusi (ROUND PILL CHIPS)
              if (_selectedFrequency == RecurringFrequency.monthly) ...[
                const Text('Tanggal Target Setiap Bulan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(31, (index) => index + 1).map((day) {
                      final isSelected = day == _targetDayOfMonth;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() => _targetDayOfMonth = day),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.blue.shade900.withOpacity(0.4) : Colors.blue.shade50)
                                  : (isDark ? const Color(0xFF1E2430) : Colors.white),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? Colors.blue.shade400 : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Text(
                              'Tgl $day',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.blue.shade400 : (isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                _buildInputContainer(
                  isDark: isDark,
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          _buildIconBadge(Icons.calendar_today_rounded, Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal Mulai', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                const SizedBox(height: 2),
                                Text('${_startDate.day}/${_startDate.month}/${_startDate.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // JAM EKSEKUSI (WAKTU MASUK / KELUAR REKENING)
              const Text('Jam Masuk / Keluar Rekening', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              _buildInputContainer(
                isDark: isDark,
                child: InkWell(
                  onTap: _selectTime,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _buildIconBadge(Icons.access_time_filled_rounded, Colors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Jam Eksekusi Otomatis', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              const SizedBox(height: 2),
                              Text(
                                '${_executionTime.hour.toString().padLeft(2, '0')}:${_executionTime.minute.toString().padLeft(2, '0')} WIB',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Quick Time Presets
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.nightlight_round, size: 14),
                    label: const Text('00:00 (Dini Hari)'),
                    onPressed: () => setState(() => _executionTime = const TimeOfDay(hour: 0, minute: 0)),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.wb_sunny_outlined, size: 14),
                    label: const Text('08:00 (Payroll Pagi)'),
                    onPressed: () => setState(() => _executionTime = const TimeOfDay(hour: 8, minute: 0)),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.wb_sunny, size: 14),
                    label: const Text('12:00 (Siang)'),
                    onPressed: () => setState(() => _executionTime = const TimeOfDay(hour: 12, minute: 0)),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ATURAN HARI LIBUR NASIONAL & AKHIR PEKAN (SMART BUSINESS DAY)
              const Text('Penyesuaian Hari Libur Nasional & Akhir Pekan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                'Terhubung dengan Kalender Libur Nasional Indonesia (API)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 10),
              _buildBusinessDayRuleCard(
                title: 'Maju ke Hari Kerja Sebelumnya',
                subtitle: 'Sangat direkomendasikan untuk Gaji / Payroll. Jika tanggal gajian jatuh di hari libur/akhir pekan, saldo cair lebih awal di hari kerja terakhir.',
                rule: BusinessDayRule.previousWorkingDay,
                icon: Icons.fast_rewind_rounded,
                isRecommended: _selectedType == TransactionType.income,
              ),
              const SizedBox(height: 8),
              _buildBusinessDayRuleCard(
                title: 'Tepat Tanggal Kalender Biasa',
                subtitle: 'Tetap diproses pada tanggal tersebut tanpa mempedulikan hari libur (Cocok untuk tagihan otomatis bank / e-wallet).',
                rule: BusinessDayRule.none,
                icon: Icons.event_rounded,
                isRecommended: _selectedType == TransactionType.expense,
              ),
              const SizedBox(height: 8),
              _buildBusinessDayRuleCard(
                title: 'Mundur ke Hari Kerja Berikutnya',
                subtitle: 'Jika jatuh di hari libur/akhir pekan, transaksi diproses pada hari kerja setelah libur usai.',
                rule: BusinessDayRule.nextWorkingDay,
                icon: Icons.fast_forward_rounded,
              ),
              const SizedBox(height: 18),

              // LIVE PREVIEW CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getEffectivePreviewText(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // End Date (Optional)
              _buildInputContainer(
                isDark: isDark,
                child: InkWell(
                  onTap: _selectEndDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _buildIconBadge(Icons.event_available_rounded, Colors.indigo),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Batas Berakhir (Opsional)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              const SizedBox(height: 2),
                              Text(
                                _endDate != null
                                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                    : 'Berulang seterusnya (tanpa batas)',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (_endDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _endDate = null),
                          )
                        else
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button (Pill CTA)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRecurring,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: themeColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SIMPAN TRANSAKSI RUTIN',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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

  Widget _buildTypeButton(String label, TransactionType type, Color activeColor) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        final oldCat = _selectedCategory;
        final newCat = type == TransactionType.income ? 'Gaji' : 'Makanan';
        setState(() {
          _selectedType = type;
          if (type == TransactionType.income) {
            _categories = AppConstants.defaultIncomeCategories;
            _selectedCategory = 'Gaji';
            _selectedBusinessDayRule = BusinessDayRule.previousWorkingDay;
          } else {
            _categories = AppConstants.defaultExpenseCategories;
            _selectedCategory = 'Makanan';
            _selectedBusinessDayRule = BusinessDayRule.none;
          }
          if (_titleController.text.isEmpty || _titleController.text == oldCat) {
            _titleController.text = newCat;
          }
        });
        _updateCategoryList();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyChip(String label, RecurringFrequency frequency) {
    final isSelected = _selectedFrequency == frequency;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFrequency = frequency),
      selectedColor: Colors.green.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade800 : Colors.grey.shade600,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildBusinessDayRuleCard({
    required String title,
    required String subtitle,
    required BusinessDayRule rule,
    required IconData icon,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedBusinessDayRule == rule;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedBusinessDayRule = rule),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.green.shade500 : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1.2,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? (isDark ? Colors.green.shade900.withOpacity(0.2) : Colors.green.shade50)
              : (isDark ? const Color(0xFF1E2430) : Colors.white),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green.shade600 : Colors.grey.shade500,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade700,
                        ),
                      ),
                      if (isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Rekomendasi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Radio<BusinessDayRule>(
              value: rule,
              groupValue: _selectedBusinessDayRule,
              activeColor: Colors.green.shade600,
              onChanged: (val) {
                if (val != null) setState(() => _selectedBusinessDayRule = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}