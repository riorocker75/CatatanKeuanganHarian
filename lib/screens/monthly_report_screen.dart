import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/monthly_summary_model.dart';
import '../services/transaction_service.dart';
import 'dart:math';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final TransactionService _transactionService = TransactionService();
  DateTime _selectedMonth = DateTime.now();

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Silakan login'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Bulanan'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ===== BAGIAN 1: LIST RINGKASAN SEMUA BULAN =====
            _buildAllMonthsSummary(user.uid),

            const Divider(height: 32),

            // ===== BAGIAN 2: DETAIL BULAN YANG DIPILIH =====
            _buildSelectedMonthDetail(user.uid),
          ],
        ),
      ),
    );
  }

  /// Widget 1: Ringkasan semua bulan (grouping)
  Widget _buildAllMonthsSummary(String userId) {
    return StreamBuilder<List<MonthlySummaryModel>>(
      stream: _transactionService.getMonthlySummaries(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final summaries = snapshot.data ?? [];

        if (summaries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('Belum ada transaksi')),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ringkasan per Bulan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${summaries.length} bulan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // List bulan-bulan
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: summaries.length,
              itemBuilder: (context, index) {
                final summary = summaries[index];
                final isSelected = summary.year == _selectedMonth.year &&
                    summary.month == _selectedMonth.month;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMonth = DateTime(summary.year, summary.month);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.green.shade300
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.green.shade100
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.calendar_month,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      summary.periodLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isSelected
                                            ? Colors.green.shade800
                                            : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${summary.transactionCount} transaksi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: summary.balance >= 0
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${summary.balance >= 0 ? '+' : ''}${_formatCurrency(summary.balance)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: summary.balance >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Progress bar income vs expense
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: summary.totalIncome > 0
                                ? summary.totalExpense / summary.totalIncome
                                : 0,
                            backgroundColor: Colors.green.shade100,
                            valueColor: AlwaysStoppedAnimation(
                              summary.totalExpense > summary.totalIncome
                                  ? Colors.red.shade400
                                  : Colors.orange.shade400,
                            ),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniStat(
                              'Pemasukan',
                              summary.totalIncome,
                              Colors.green,
                            ),
                            _buildMiniStat(
                              'Pengeluaran',
                              summary.totalExpense,
                              Colors.red,
                            ),
                            _buildMiniStat(
                              'Tabungan',
                              summary.savingsRate,
                              Colors.blue,
                              isPercentage: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Widget 2: Detail bulan yang dipilih dan digrouping
  Widget _buildSelectedMonthDetail(String userId) {
  return StreamBuilder<List<TransactionModel>>(
    stream: _transactionService.getTransactionsByMonth(
      userId,
      _selectedMonth.year,
      _selectedMonth.month,
    ),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final transactions = snapshot.data ?? [];

      // ===== GROUPING PER KATEGORI =====
      double totalIncome = 0;
      double totalExpense = 0;
      Map<String, double> categoryExpenses = {};
      Map<String, double> categoryIncomes = {};
      Map<String, int> categoryExpenseCounts = {}; // jumlah transaksi per kategori
      Map<String, int> categoryIncomeCounts = {};

      for (var t in transactions) {
        if (t.type == TransactionType.income) {
          totalIncome += t.amount;
          categoryIncomes[t.category] = (categoryIncomes[t.category] ?? 0) + t.amount;
          categoryIncomeCounts[t.category] = (categoryIncomeCounts[t.category] ?? 0) + 1;
        } else {
          totalExpense += t.amount;
          categoryExpenses[t.category] = (categoryExpenses[t.category] ?? 0) + t.amount;
          categoryExpenseCounts[t.category] = (categoryExpenseCounts[t.category] ?? 0) + 1;
        }
      }

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth,
                  ),
                  Column(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${transactions.length} transaksi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Pemasukan',
                    totalIncome,
                    Colors.green,
                    Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Pengeluaran',
                    totalExpense,
                    Colors.red,
                    Icons.arrow_upward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              'Saldo Bulanan',
              totalIncome - totalExpense,
              totalIncome >= totalExpense ? Colors.blue : Colors.orange,
              Icons.account_balance,
              isFullWidth: true,
            ),
            const SizedBox(height: 32),

            // ===== PENGELUARAN PER KATEGORI (GROUPING) =====
            if (categoryExpenses.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pengeluaran per Kategori',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${categoryExpenses.length} kategori',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Pie Chart
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: _buildPieSections(categoryExpenses),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLegend(categoryExpenses),
              const SizedBox(height: 24),

              // ===== LIST GROUPING PENGELUARAN =====
              ...categoryExpenses.entries.map((entry) {
                final category = entry.key;
                final amount = entry.value;
                final count = categoryExpenseCounts[category] ?? 0;
                final percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;

                return _buildCategoryGroupItem(
                  category: category,
                  amount: amount,
                  count: count,
                  percentage: percentage.toDouble(),
                  totalAmount: totalExpense,
                  color: Colors.red,
                );
              }),
            ],

            const SizedBox(height: 24),

            // ===== PEMASUKAN PER KATEGORI (GROUPING) =====
            if (categoryIncomes.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pemasukan per Kategori',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${categoryIncomes.length} kategori',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...categoryIncomes.entries.map((entry) {
                final category = entry.key;
                final amount = entry.value;
                final count = categoryIncomeCounts[category] ?? 0;
                final percentage = totalIncome > 0 ? ((amount / totalIncome) * 100).toDouble() : 0.0;

                return _buildCategoryGroupItem(
                  category: category,
                  amount: amount,
                  count: count,
                  percentage: percentage,
                  totalAmount: totalIncome,
                  color: Colors.green,
                );
              }),
            ],
          ],
        ),
      );
    },
  );
}

/// Widget grouping per kategori — RAPI & INFORMATIF
Widget _buildCategoryGroupItem({
  required String category,
  required double amount,
  required int count,
  required double percentage,
  required double totalAmount,
  required Color color,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$count transaksi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalAmount > 0 ? amount / totalAmount : 0,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    ),
  );
}

IconData _getCategoryIcon(String category) {
  // Hash dari nama kategori → seed random yang konsisten
  final hash = category.toLowerCase().hashCode;
  final random = Random(hash);
  
  final icons = [
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_bag,
    Icons.movie,
    Icons.local_hospital,
    Icons.school,
    Icons.work,
    Icons.card_giftcard,
    Icons.trending_up,
    Icons.more_horiz,
    Icons.coffee,
    Icons.fitness_center,
    Icons.pets,
    Icons.home,
    Icons.phone_android,
    Icons.flight,
    Icons.sports_esports,
    Icons.book,
    Icons.music_note,
    Icons.photo_camera,
    Icons.brush,
    Icons.build,
    Icons.child_care,
    Icons.cleaning_services,
    Icons.devices,
    Icons.eco,
    Icons.face,
    Icons.favorite,
    Icons.flag,
    Icons.handshake,
    Icons.icecream,
    Icons.kitchen,
    Icons.landscape,
    Icons.local_cafe,
    Icons.local_dining,
    Icons.local_florist,
    Icons.local_gas_station,
    Icons.local_grocery_store,
    Icons.local_laundry_service,
    Icons.local_mall,
    Icons.local_parking,
    Icons.local_pharmacy,
    Icons.local_pizza,
    Icons.local_shipping,
    Icons.local_taxi,
    Icons.lunch_dining,
    Icons.medication,
    Icons.payments,
    Icons.redeem,
    Icons.savings,
    Icons.shopping_cart,
    Icons.spa,
    Icons.sports_bar,
    Icons.store,
    Icons.train,
    Icons.videogame_asset,
    Icons.wifi,
    Icons.wine_bar,
  ];
  
  return icons[random.nextInt(icons.length)];
}


// end per month
  Widget _buildMiniStat(String label, double value, Color color, {bool isPercentage = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          isPercentage
              ? '${value.toStringAsFixed(1)}%'
              : _formatCurrency(value),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
  
Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon, {
    bool isFullWidth = false,
  }) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    final colors = [
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.yellow.shade600,
      Colors.green.shade400,
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.pink.shade400,
    ];

    double total = data.values.fold(0, (a, b) => a + b);
    int index = 0;

    return data.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      final color = colors[index % colors.length];
      index++;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, double> data) {
    final colors = [
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.yellow.shade600,
      Colors.green.shade400,
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.pink.shade400,
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: data.keys.toList().asMap().entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[entry.key % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              entry.value,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTransactionItem(TransactionModel t, NumberFormat format) {
    final isExpense = t.type == TransactionType.expense;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: isExpense ? Colors.red : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  t.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'} ${format.format(t.amount)}',
            style: TextStyle(
              color: isExpense ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  // ... _buildSummaryCard, _buildPieSections, _buildLegend, _buildTransactionItem sama seperti sebelumnya
}