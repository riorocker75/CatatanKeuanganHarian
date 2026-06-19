import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
// import '../models/budget_model.dart';
import '../models/wallet_model.dart';
import '../services/auth_service.dart';
import '../services/transaction_service.dart';
// import '../services/budget_service.dart';
import '../services/wallet_service.dart';
import '../widgets/transaction_card.dart';
// import '../widgets/summary_card.dart'; // tidak dipakai lagi, digantikan BalanceSwipeCard
import '../widgets/balance_swipe_card.dart';
// import '../widgets/budget_progress_card.dart';
import '../widgets/chart_widget.dart';
import 'auth/login_screen.dart';
import 'add_transaction_screen.dart';
import 'monthly_report_screen.dart';
import 'transaction_history_screen.dart';
import 'transaction_detail_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  // final BudgetService _budgetService = BudgetService();
  final WalletService _walletService = WalletService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return const LoginScreen();

    final screens = [
      _buildHomeScreen(user.uid),
      const MonthlyReportScreen(),
      const TransactionHistoryScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Bulanan'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildHomeScreen(String userId) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Trigger rebuild untuk refresh data
      },
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${_authService.currentUser?.email?.split('@')[0] ?? 'User'}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dashboard Keuangan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await _authService.logout(context);
                          if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Kartu gabungan: Saldo Hari Ini (+ pemasukan/pengeluaran inline)
          // -> geser ke kanan -> Total Saldo Dompet.
          // Wallet diambil sekali (FutureBuilder), transaksi hari ini real-time (StreamBuilder).
          SliverToBoxAdapter(
            child: FutureBuilder<List<WalletModel>>(
              future: _walletService.getUserWallets(userId).first,
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                        // tambahan code untuk gesture 
                         onTapIncome: () {
                            // Navigasi langsung ke detail pemasukan
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TransactionDetailScreen(
                                  title: 'Pemasukan',
                                  color: Colors.green,
                                  icon: Icons.trending_up,
                                  filterType: TransactionType.income,
                                ),
                              ),
                            );
                          },
                          onTapExpense: () {
                            // Navigasi langsung ke detail pengeluaran
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TransactionDetailScreen(
                                  title: 'Pengeluaran',
                                  color: Colors.red,
                                  icon: Icons.trending_down,
                                  filterType: TransactionType.expense,
                                ),
                              ),
                            );
                          },
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Budget Progress - FutureBuilder
          // SliverToBoxAdapter(
          //   child: FutureBuilder<BudgetModel?>(
          //     future: _budgetService.getBudget(userId, BudgetPeriod.daily),
          //     builder: (context, budgetSnapshot) {
          //       if (budgetSnapshot.hasError || !budgetSnapshot.hasData || budgetSnapshot.data == null) {
          //         return const SizedBox.shrink();
          //       }

          //       final budget = budgetSnapshot.data!;
                
          //       return FutureBuilder<double>(
          //         future: _budgetService.getCurrentSpending(userId, BudgetPeriod.daily),
          //         builder: (context, spendingSnapshot) {
          //           if (spendingSnapshot.hasError) return const SizedBox.shrink();
                    
          //           final spending = spendingSnapshot.data ?? 0;
          //           final progress = budget.amount > 0 
          //               ? (spending / budget.amount).clamp(0.0, 1.0) 
          //               : 0.0;

          //           return BudgetProgressCard(
          //             budget: budget,
          //             currentSpending: spending,
          //             progress: progress,
          //           );
          //         },
          //       );
          //     },
          //   ),
          // ),

          // Chart Widget
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tren Mingguan',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedIndex = 1);
                        },
                        child: const Text('Lihat Detail'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<TransactionModel>>(
                    stream: _transactionService.getTodayTransactions(userId),
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

          // Today's Transactions Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaksi Hari Ini',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    DateFormat('EEEE, dd MMM', 'id_ID').format(DateTime.now()),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Transactions List - Optimasi dengan ListView.builder
          StreamBuilder<List<TransactionModel>>(
            stream: _transactionService.getTodayTransactions(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada transaksi hari ini',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverToBoxAdapter(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return TransactionCard(
                      transaction: transaction,
                      onDelete: () async {
                        await _transactionService.deleteTransaction(transaction);
                        if (mounted) {
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
                ),
              );
            },
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}