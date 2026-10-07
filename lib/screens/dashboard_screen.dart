import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/wallet_model.dart';
import '../services/auth_service.dart';
import '../services/transaction_service.dart';
import '../services/budget_service.dart';
import '../services/wallet_service.dart';
import '../services/recurring_service.dart';
import '../widgets/transaction_card.dart';
import '../widgets/balance_swipe_card.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/chart_widget.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../widgets/voice_input_modal.dart';
import 'auth/login_screen.dart';
import 'add_transaction_screen.dart';
import 'monthly_report_screen.dart';
import 'transaction_history_screen.dart';
import 'transaction_detail_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';
import 'search_screen.dart';
import 'transfer_screen.dart';
import 'recurring_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  final BudgetService _budgetService = BudgetService();
  final WalletService _walletService = WalletService();
  final RecurringService _recurringService = RecurringService();
  final OcrService _ocrService = OcrService();
  int _selectedIndex = 0;
  bool _isScanning = false;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _processRecurring();
  }

  void _processRecurring() {
    final user = _authService.currentUser;
    if (user != null) {
      _recurringService.processRecurringTransactions(user.uid);
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return 'Selamat Pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return const LoginScreen();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF10B981);

    final screens = [
      _buildHomeScreen(user.uid, isDark, primaryColor),
      const MonthlyReportScreen(),
      const TransactionHistoryScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If on tab 1 (Laporan) or tab 2 (Riwayat), switch back to tab 0 (Beranda) first
        if (_selectedIndex != 0) {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = 0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Tekan sekali lagi untuk keluar dari aplikasi',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: const Color(0xFF1E293B),
            ),
          );
          return;
        }

        // Second back press within 2 seconds: close the app cleanly
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: screens[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              setState(() => _selectedIndex = index);
            },
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            indicatorColor: primaryColor.withValues(alpha: 0.18),
            elevation: 0,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: isDark ? Colors.white60 : Colors.grey.shade600),
                selectedIcon: const Icon(Icons.dashboard_rounded, color: primaryColor),
                label: 'Beranda',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: isDark ? Colors.white60 : Colors.grey.shade600),
                selectedIcon: const Icon(Icons.bar_chart_rounded, color: primaryColor),
                label: 'Laporan',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_rounded, color: isDark ? Colors.white60 : Colors.grey.shade600),
                selectedIcon: const Icon(Icons.history_toggle_off_rounded, color: primaryColor),
                label: 'Riwayat',
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
            );
          },
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildHomeScreen(String userId, bool isDark, Color primaryColor) {
    final user = _authService.currentUser;
    final userName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@')[0] ?? 'User');

    final initialLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () async {
        _processRecurring();
        setState(() {});
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Header Modern Bar
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Profile Greeting & Avatar
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initialLetter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getTimeGreeting()} 👋',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Top Action Buttons
                    Row(
                      children: [
                        _buildHeaderIconButton(
                          icon: _isScanning ? Icons.hourglass_top_rounded : Icons.document_scanner_rounded,
                          tooltip: 'Scan Struk / Nota',
                          iconColor: const Color(0xFF10B981),
                          isDark: isDark,
                          onTap: _isScanning ? () {} : _showScanReceiptSheet,
                        ),
                        const SizedBox(width: 6),
                        _buildHeaderIconButton(
                          icon: Icons.mic_rounded,
                          tooltip: 'Catat Suara',
                          iconColor: const Color(0xFF3B82F6),
                          isDark: isDark,
                          onTap: () => VoiceInputModal.show(context),
                        ),
                        const SizedBox(width: 6),
                        _buildHeaderIconButton(
                          icon: Icons.search_rounded,
                          tooltip: 'Cari Transaksi',
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SearchScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildHeaderIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Pengaturan',
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Hero Total Balance & Quick Actions
          SliverToBoxAdapter(
            child: StreamBuilder<List<WalletModel>>(
              stream: _walletService.getUserWallets(userId),
              builder: (context, walletSnapshot) {
                final wallets = walletSnapshot.data ?? [];
                final totalBalance = wallets.fold(0.0, (sum, w) => sum + w.balance);

                return StreamBuilder<List<TransactionModel>>(
                  stream: _transactionService.getTodayTransactions(userId),
                  builder: (context, txSnapshot) {
                    double todayIncome = 0;
                    double todayExpense = 0;

                    if (txSnapshot.hasData) {
                      for (var t in txSnapshot.data!) {
                        if (t.type == TransactionType.income) {
                          todayIncome += t.amount;
                        } else {
                          todayExpense += t.amount;
                        }
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: BalanceSwipeCard(
                        todayIncome: todayIncome,
                        todayExpense: todayExpense,
                        totalWalletBalance: totalBalance,
                        walletCount: wallets.length,
                        onTapWallet: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WalletScreen()),
                          );
                        },
                        onTapIncome: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionDetailScreen(
                                title: 'Pemasukan Hari Ini',
                                color: Color(0xFF10B981),
                                icon: Icons.arrow_downward_rounded,
                                filterType: TransactionType.income,
                              ),
                            ),
                          );
                        },
                        onTapExpense: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionDetailScreen(
                                title: 'Pengeluaran Hari Ini',
                                color: Color(0xFFEF4444),
                                icon: Icons.arrow_upward_rounded,
                                filterType: TransactionType.expense,
                              ),
                            ),
                          );
                        },
                        onTapTransfer: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TransferScreen()),
                          );
                        },
                        onTapRecurring: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RecurringScreen()),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Budget Progress Card
          SliverToBoxAdapter(
            child: StreamBuilder<List<BudgetModel>>(
              stream: _budgetService.getUserBudgets(userId),
              builder: (context, budgetSnapshot) {
                if (!budgetSnapshot.hasData || budgetSnapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }

                final budgets = budgetSnapshot.data!;
                final activeBudget = budgets.first;

                return FutureBuilder<double>(
                  future: _budgetService.getCurrentSpending(
                    userId,
                    activeBudget.period,
                    category: activeBudget.category,
                  ),
                  builder: (context, spendingSnapshot) {
                    final spending = spendingSnapshot.data ?? 0.0;
                    final progress = activeBudget.amount > 0
                        ? (spending / activeBudget.amount).clamp(0.0, 1.0)
                        : 0.0;

                    return BudgetProgressCard(
                      budget: activeBudget,
                      currentSpending: spending,
                      progress: progress,
                    );
                  },
                );
              },
            ),
          ),

          // Tren Mingguan Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tren Pengeluaran 7 Hari',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedIndex = 1);
                        },
                        child: Text(
                          'Lihat Laporan →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<TransactionModel>>(
                    stream: _transactionService.getLast7DaysTransactions(userId),
                    builder: (context, snapshot) {
                      final transactions = snapshot.data ?? [];
                      return ChartWidget(
                        transactions: transactions,
                        isWeekly: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Header Transaksi Hari Ini
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaksi Hari Ini',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(DateTime.now()),
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Transactions List Hari Ini
          StreamBuilder<List<TransactionModel>>(
            stream: _transactionService.getTodayTransactions(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF10B981)),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }

              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.receipt_long_rounded, size: 36, color: primaryColor),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada transaksi hari ini',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tekan tombol + di bawah untuk mencatat pengeluaran atau pemasukan baru',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final transaction = transactions[index];
                    return TransactionCard(
                      transaction: transaction,
                      onDelete: () async {
                        await _transactionService.deleteTransaction(transaction);
                        if (mounted) {
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
                  childCount: transactions.length,
                ),
              );
            },
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(
              prefilledTitle: parsed.merchantName,
              prefilledAmount: parsed.totalAmount,
              prefilledCategory: parsed.suggestedCategory,
              prefilledType: TransactionType.expense,
            ),
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

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 18,
          color: iconColor ?? (isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }
}