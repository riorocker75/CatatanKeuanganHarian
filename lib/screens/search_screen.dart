import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import '../widgets/transaction_card.dart';
import '../widgets/searchable_chip_picker.dart';
import '../utils/constants.dart';
import 'add_transaction_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final TransactionType? initialType;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.initialType,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TransactionService _transactionService = TransactionService();
  final WalletService _walletService = WalletService();

  String _searchQuery = '';
  TransactionType? _filterType;
  String? _filterCategory;
  String? _filterWalletId;
  String? _filterWalletName;
  DateTimeRange? _dateRange;
  String _datePreset = 'all'; // 'all', 'today', 'week', 'month', 'custom'
  double? _minAmount;
  double? _maxAmount;

  // Collapsible toggle for popular searches
  bool _isPopularExpanded = true;

  // List 1: Popular Categories
  final List<String> _popularCategories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Gaji',
    'Bonus',
    'Hiburan',
    'Kesehatan',
  ];

  // List 2: Popular Keywords & Merchants
  final List<String> _popularKeywords = [
    'Kopi',
    'Bensin',
    'Indomaret',
    'Alfamart',
    'Grab',
    'Gojek',
    'Listrik',
    'Shopee',
    'Pulsa',
    'Netflix',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!.toLowerCase();
      _searchController.text = widget.initialQuery!;
    }
    if (widget.initialCategory != null) {
      _filterCategory = widget.initialCategory;
    }
    if (widget.initialType != null) {
      _filterType = widget.initialType;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterType != null) count++;
    if (_filterCategory != null) count++;
    if (_filterWalletId != null) count++;
    if (_dateRange != null || _datePreset != 'all') count++;
    if (_minAmount != null || _maxAmount != null) count++;
    return count;
  }

  void _resetAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _filterType = null;
      _filterCategory = null;
      _filterWalletId = null;
      _filterWalletName = null;
      _dateRange = null;
      _datePreset = 'all';
      _minAmount = null;
      _maxAmount = null;
    });
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      if (preset == 'today') {
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
        _dateRange = DateTimeRange(start: startOfDay, end: endOfDay);
      } else if (preset == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _dateRange = DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      } else if (preset == 'month') {
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        _dateRange = DateTimeRange(start: startOfMonth, end: endOfMonth);
      } else {
        _dateRange = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Silakan login')));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF10B981);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: widget.initialQuery == null || widget.initialQuery!.isEmpty,
                  decoration: InputDecoration(
                    hintText: 'Cari judul, catatan, atau kategori...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 22),
                tooltip: 'Filter Lanjutan',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAdvancedFilterSheet(user.uid, isDark, primaryColor);
                },
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 8,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_activeFilterCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Quick Type Filters
                _buildFilterPill(
                  label: 'Semua Tipe',
                  isSelected: _filterType == null,
                  onTap: () => setState(() => _filterType = null),
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  label: '💸 Pengeluaran',
                  isSelected: _filterType == TransactionType.expense,
                  onTap: () => setState(() => _filterType = TransactionType.expense),
                  isDark: isDark,
                  primaryColor: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  label: '💰 Pemasukan',
                  isSelected: _filterType == TransactionType.income,
                  onTap: () => setState(() => _filterType = TransactionType.income),
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 8),

                // Quick Date Pills
                _buildFilterPill(
                  label: 'Hari Ini',
                  isSelected: _datePreset == 'today',
                  onTap: () => _applyDatePreset(_datePreset == 'today' ? 'all' : 'today'),
                  isDark: isDark,
                  primaryColor: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  label: 'Bulan Ini',
                  isSelected: _datePreset == 'month',
                  onTap: () => _applyDatePreset(_datePreset == 'month' ? 'all' : 'month'),
                  isDark: isDark,
                  primaryColor: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),

                // Category Filter Pill
                if (_filterCategory != null) ...[
                  _buildFilterPill(
                    label: '🏷️ $_filterCategory',
                    isSelected: true,
                    onTap: () => setState(() => _filterCategory = null),
                    isDark: isDark,
                    primaryColor: const Color(0xFFF59E0B),
                    showClose: true,
                  ),
                  const SizedBox(width: 8),
                ],

                // Wallet Filter Pill
                if (_filterWalletName != null) ...[
                  _buildFilterPill(
                    label: '💳 $_filterWalletName',
                    isSelected: true,
                    onTap: () => setState(() {
                      _filterWalletId = null;
                      _filterWalletName = null;
                    }),
                    isDark: isDark,
                    primaryColor: const Color(0xFF06B6D4),
                    showClose: true,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _transactionService.getUserTransactions(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Terjadi kesalahan: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final allTransactions = snapshot.data ?? [];

          // Apply filters
          final filteredTransactions = allTransactions.where((t) {
            // Text search (matches title, description, category, or formatted amount)
            if (_searchQuery.isNotEmpty) {
              final titleMatch = t.title.toLowerCase().contains(_searchQuery);
              final descMatch = t.description.toLowerCase().contains(_searchQuery);
              final catMatch = t.category.toLowerCase().contains(_searchQuery);
              final amountStr = t.amount.toStringAsFixed(0);
              final amountMatch = amountStr.contains(_searchQuery);

              if (!titleMatch && !descMatch && !catMatch && !amountMatch) {
                return false;
              }
            }

            // Type filter
            if (_filterType != null && t.type != _filterType) {
              return false;
            }

            // Category filter
            if (_filterCategory != null && t.category != _filterCategory) {
              return false;
            }

            // Wallet filter
            if (_filterWalletId != null && t.walletId != _filterWalletId) {
              return false;
            }

            // Date Range filter
            if (_dateRange != null) {
              final tDate = DateTime(t.date.year, t.date.month, t.date.day);
              final sDate = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
              final eDate = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);

              if (tDate.isBefore(sDate) || tDate.isAfter(eDate)) {
                return false;
              }
            }

            // Amount Range filter
            if (_minAmount != null && t.amount < _minAmount!) {
              return false;
            }
            if (_maxAmount != null && t.amount > _maxAmount!) {
              return false;
            }

            return true;
          }).toList();

          // Calculate search result stats
          double resultIncome = 0;
          double resultExpense = 0;
          for (var t in filteredTransactions) {
            if (t.type == TransactionType.income) {
              resultIncome += t.amount;
            } else {
              resultExpense += t.amount;
            }
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Collapsible Popular Searches Section (2 Structured Lists)
              if (_searchQuery.isEmpty && _activeFilterCount == 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Collapsible Dropdown Header
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isPopularExpanded = !_isPopularExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Rekomendasi Pencarian',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isPopularExpanded ? 'Sembunyikan' : 'Tampilkan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _isPopularExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 2 Structured Lists with Smooth Animation
                          AnimatedCrossFade(
                            firstChild: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),

                                  // List 1: Kategori Populer
                                  Row(
                                    children: [
                                      const Icon(Icons.category_rounded, size: 14, color: Color(0xFF10B981)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Kategori Populer',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: _popularCategories.map((cat) {
                                      return ActionChip(
                                        avatar: Icon(
                                          AppConstants.getCategoryIcon(cat),
                                          size: 14,
                                          color: const Color(0xFF10B981),
                                        ),
                                        label: Text(cat),
                                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        side: BorderSide(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        ),
                                        labelStyle: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _filterCategory = cat;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 14),

                                  // List 2: Kata Kunci & Merchant
                                  Row(
                                    children: [
                                      const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF3B82F6)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Kata Kunci & Merchant',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: _popularKeywords.map((kw) {
                                      return ActionChip(
                                        avatar: const Icon(Icons.search_rounded, size: 13, color: Color(0xFF3B82F6)),
                                        label: Text(kw),
                                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        side: BorderSide(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        ),
                                        labelStyle: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          _searchController.text = kw;
                                          setState(() => _searchQuery = kw.toLowerCase());
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: _isPopularExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 220),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Results Summary Banner
              if (filteredTransactions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.checklist_rounded, color: primaryColor, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${filteredTransactions.length} Transaksi Ditemukan',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (resultIncome > 0)
                                Text(
                                  '+${_formatCompactNumber(resultIncome)}',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (resultIncome > 0 && resultExpense > 0) const SizedBox(width: 6),
                              if (resultExpense > 0)
                                Text(
                                  '-${_formatCompactNumber(resultExpense)}',
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Empty Search Results
              if (filteredTransactions.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(28),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_off_rounded, size: 44, color: Color(0xFFEF4444)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak Ada Transaksi Cocok',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tidak ditemukan transaksi dengan kata kunci "$_searchQuery". Coba kata kunci lain atau sesuaikan filter.'
                              : 'Tidak ada transaksi dengan filter yang dipilih.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                        if (_activeFilterCount > 0 || _searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _resetAllFilters,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset Semua Filter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: const BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else ...[
                // Grouped by Date List
                ..._buildGroupedDateSlivers(filteredTransactions, context, isDark),
              ],

              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
    bool showClose = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? primaryColor
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ),
            if (showClose) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 14, color: primaryColor),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedDateSlivers(
    List<TransactionModel> transactions,
    BuildContext context,
    bool isDark,
  ) {
    final Map<String, List<TransactionModel>> grouped = {};
    for (var t in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(t.date);
      grouped.putIfAbsent(dateKey, () => []).add(t);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final List<Widget> slivers = [];

    for (var dateKey in sortedKeys) {
      final dateTransactions = grouped[dateKey]!;
      final date = DateTime.parse(dateKey);

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                _buildDailyTotal(dateTransactions),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, index) {
              final transaction = dateTransactions[index];
              return TransactionCard(
                transaction: transaction,
                onDelete: () async {
                  await _transactionService.deleteTransaction(transaction);
                  if (context.mounted) {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaksi dihapus'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(transaction: transaction),
                    ),
                  );
                },
              );
            },
            childCount: dateTransactions.length,
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildDailyTotal(List<TransactionModel> transactions) {
    double income = 0;
    double expense = 0;

    for (var t in transactions) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    return Row(
      children: [
        if (income > 0)
          Text(
            '+${_formatCompactNumber(income)}',
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (expense > 0) ...[
          if (income > 0) const SizedBox(width: 6),
          Text(
            '-${_formatCompactNumber(expense)}',
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  void _showAdvancedFilterSheet(String userId, bool isDark, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 16,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Lanjutan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _filterType = null;
                            _filterCategory = null;
                            _filterWalletId = null;
                            _filterWalletName = null;
                            _dateRange = null;
                            _datePreset = 'all';
                            _minAmount = null;
                            _maxAmount = null;
                          });
                        },
                        child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1. Transaction Type
                  const Text('Tipe Transaksi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceChip(
                          label: 'Semua',
                          isSelected: _filterType == null,
                          onTap: () => setSheetState(() => _filterType = null),
                          isDark: isDark,
                          primaryColor: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChoiceChip(
                          label: 'Pengeluaran',
                          isSelected: _filterType == TransactionType.expense,
                          onTap: () => setSheetState(() => _filterType = TransactionType.expense),
                          isDark: isDark,
                          primaryColor: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChoiceChip(
                          label: 'Pemasukan',
                          isSelected: _filterType == TransactionType.income,
                          onTap: () => setSheetState(() => _filterType = TransactionType.income),
                          isDark: isDark,
                          primaryColor: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Category Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (_filterCategory != null)
                        GestureDetector(
                          onTap: () => setSheetState(() => _filterCategory = null),
                          child: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final categories = [
                        ...AppConstants.defaultExpenseCategories,
                        ...AppConstants.defaultIncomeCategories,
                      ].toSet().toList();

                      final items = categories
                          .map((c) => SearchableChipItem<String>(
                                value: c,
                                label: c,
                                icon: Icons.category_rounded,
                              ))
                          .toList();

                      final selected = await SearchableChipPicker.show<String>(
                        context: context,
                        title: 'Pilih Kategori',
                        items: items,
                        selectedValue: _filterCategory,
                        activeColor: primaryColor,
                      );

                      if (selected != null) {
                        setSheetState(() => _filterCategory = selected);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _filterCategory ?? 'Pilih Kategori (Semua)',
                            style: TextStyle(
                              color: _filterCategory != null
                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              fontSize: 13,
                              fontWeight: _filterCategory != null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Wallet Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dompet / Sumber Dana', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (_filterWalletId != null)
                        GestureDetector(
                          onTap: () => setSheetState(() {
                            _filterWalletId = null;
                            _filterWalletName = null;
                          }),
                          child: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<WalletModel>>(
                    stream: _walletService.getUserWallets(userId),
                    builder: (context, snap) {
                      final wallets = snap.data ?? [];
                      return InkWell(
                        onTap: () async {
                          if (wallets.isEmpty) return;
                          final items = wallets
                              .map((w) => SearchableChipItem<String>(
                                    value: w.id,
                                    label: w.name,
                                    icon: Icons.account_balance_wallet_rounded,
                                    subtitle: w.bankName,
                                  ))
                              .toList();

                          final selected = await SearchableChipPicker.show<String>(
                            context: context,
                            title: 'Pilih Dompet',
                            items: items,
                            selectedValue: _filterWalletId,
                            activeColor: primaryColor,
                          );

                          if (selected != null) {
                            final pickedW = wallets.firstWhere((w) => w.id == selected);
                            setSheetState(() {
                              _filterWalletId = pickedW.id;
                              _filterWalletName = pickedW.name;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _filterWalletName ?? 'Pilih Dompet (Semua)',
                                style: TextStyle(
                                  color: _filterWalletName != null
                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  fontSize: 13,
                                  fontWeight: _filterWalletName != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. Date Range
                  const Text('Rentang Tanggal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: _dateRange,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: primaryColor,
                                onPrimary: Colors.white,
                                surface: isDark ? const Color(0xFF1E293B) : Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setSheetState(() {
                          _dateRange = picked;
                          _datePreset = 'custom';
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 8),
                              Text(
                                _dateRange != null
                                    ? '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'
                                    : 'Semua Waktu (Pilih Tanggal)',
                                style: TextStyle(
                                  color: _dateRange != null
                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  fontSize: 13,
                                  fontWeight: _dateRange != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.edit_calendar_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _formatCompactNumber(double number) {
    if (number >= 1000000) {
      return 'Rp ${(number / 1000000).toStringAsFixed(1)}jt';
    } else if (number >= 1000) {
      return 'Rp ${(number / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp ${number.toStringAsFixed(0)}';
  }
}