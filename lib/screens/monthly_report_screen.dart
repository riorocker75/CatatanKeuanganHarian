import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/monthly_summary_model.dart';
import '../services/transaction_service.dart';
import '../services/export_service.dart';
import '../utils/constants.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final TransactionService _transactionService = TransactionService();
  final ExportService _exportService = ExportService();
  DateTime _selectedMonth = DateTime.now();
  bool _isExporting = false;

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  Future<void> _exportCurrentMonth(List<TransactionModel> transactions) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada transaksi di bulan ini untuk diekspor')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
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
              Text(
                'Export Laporan - $monthLabel',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 22),
                ),
                title: const Text('Export ke Dokumen PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Simpan tabel rekap dan ringkasan ke PDF', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _isExporting = true);
                  try {
                    await _exportService.exportToPDF(
                      transactions,
                      title: 'Laporan Keuangan - $monthLabel',
                    );
                    if (mounted) {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ PDF berhasil dibuat'), backgroundColor: Color(0xFF10B981)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal export PDF: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isExporting = false);
                  }
                },
              ),
              const Divider(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: const Text('Export ke File CSV / Excel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Data mentah transaksi untuk dianalisis di Excel', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _isExporting = true);
                  try {
                    await _exportService.exportToCSV(
                      transactions,
                      title: 'Transaksi - $monthLabel',
                    );
                    if (mounted) {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ CSV berhasil dibuat'), backgroundColor: Color(0xFF10B981)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal export CSV: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isExporting = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Silakan login'));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Laporan Bulanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Month Detail Section
            _buildSelectedMonthDetail(user.uid, isDark),

            const SizedBox(height: 12),

            // All Months Summary Section
            _buildAllMonthsSummary(user.uid, isDark),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// Detail bulan yang dipilih
  Widget _buildSelectedMonthDetail(String userId, bool isDark) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService.getTransactionsByMonth(
        userId,
        _selectedMonth.year,
        _selectedMonth.month,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
          );
        }

        final transactions = snapshot.data ?? [];

        double totalIncome = 0;
        double totalExpense = 0;
        Map<String, double> categoryExpenses = {};
        Map<String, double> categoryIncomes = {};
        Map<String, int> categoryExpenseCounts = {};
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

        final netBalance = totalIncome - totalExpense;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interactive Month Navigator Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 26),
                      onPressed: _previousMonth,
                    ),
                    Column(
                      children: [
                        Text(
                          DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${transactions.length} Transaksi Tercatat',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 26),
                          onPressed: _nextMonth,
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                                  )
                                : const Icon(Icons.ios_share_rounded, size: 18, color: Color(0xFF10B981)),
                            tooltip: 'Export Laporan',
                            onPressed: _isExporting ? null : () => _exportCurrentMonth(transactions),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3 Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildFintechSummaryCard(
                      title: 'Pemasukan',
                      amount: totalIncome,
                      color: const Color(0xFF10B981),
                      icon: Icons.arrow_downward_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFintechSummaryCard(
                      title: 'Pengeluaran',
                      amount: totalExpense,
                      color: const Color(0xFFEF4444),
                      icon: Icons.arrow_upward_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFintechSummaryCard(
                title: 'Saldo Bersih Bulan Ini',
                amount: netBalance,
                color: netBalance >= 0 ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B),
                icon: Icons.account_balance_rounded,
                isFullWidth: true,
                isDark: isDark,
                subtitle: netBalance >= 0 ? 'Surplus (Tabungan Positif)' : 'Defisit (Pengeluaran Lebih Besar)',
              ),
              const SizedBox(height: 24),

              // Breakdown Pengeluaran per Kategori
              if (categoryExpenses.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pengeluaran per Kategori',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${categoryExpenses.length} Kategori',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Donut Pie Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: _buildPieSections(categoryExpenses),
                            sectionsSpace: 3,
                            centerSpaceRadius: 42,
                            centerSpaceColor: Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildLegend(categoryExpenses),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Category List Items
                ...categoryExpenses.entries.map((entry) {
                  final category = entry.key;
                  final amount = entry.value;
                  final count = categoryExpenseCounts[category] ?? 0;
                  final percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;

                  return _buildCategoryGroupItem(
                    category: category,
                    amount: amount,
                    count: count,
                    percentage: percentage,
                    totalAmount: totalExpense,
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                  );
                }),
              ],

              // Breakdown Pemasukan per Kategori
              if (categoryIncomes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pemasukan per Kategori',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${categoryIncomes.length} Kategori',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...categoryIncomes.entries.map((entry) {
                  final category = entry.key;
                  final amount = entry.value;
                  final count = categoryIncomeCounts[category] ?? 0;
                  final percentage = totalIncome > 0 ? (amount / totalIncome) * 100 : 0.0;

                  return _buildCategoryGroupItem(
                    category: category,
                    amount: amount,
                    count: count,
                    percentage: percentage,
                    totalAmount: totalIncome,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Ringkasan semua bulan (Grouping history)
  Widget _buildAllMonthsSummary(String userId, bool isDark) {
    return StreamBuilder<List<MonthlySummaryModel>>(
      stream: _transactionService.getMonthlySummaries(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final summaries = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Riwayat Tiap Bulan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${summaries.length} Bulan',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summaries.length,
                itemBuilder: (context, index) {
                  final summary = summaries[index];
                  final isSelected = summary.year == _selectedMonth.year && summary.month == _selectedMonth.month;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedMonth = DateTime(summary.year, summary.month);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFF10B981).withOpacity(0.08))
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1,
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
                                          ? const Color(0xFF10B981).withOpacity(0.2)
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade500,
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
                                          fontSize: 14,
                                          color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                      Text(
                                        '${summary.transactionCount} transaksi',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: summary.balance >= 0
                                      ? const Color(0xFF10B981).withOpacity(0.12)
                                      : const Color(0xFFEF4444).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${summary.balance >= 0 ? '+' : ''}${_formatCurrency(summary.balance)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: summary.balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: summary.totalIncome > 0
                                  ? (summary.totalExpense / summary.totalIncome).clamp(0.0, 1.0)
                                  : 0,
                              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation(
                                summary.totalExpense > summary.totalIncome
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF59E0B),
                              ),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniStat('Pemasukan', summary.totalIncome, const Color(0xFF10B981)),
                              _buildMiniStat('Pengeluaran', summary.totalExpense, const Color(0xFFEF4444)),
                              _buildMiniStat('Tabungan', summary.savingsRate, const Color(0xFF3B82F6), isPercentage: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFintechSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isDark,
    bool isFullWidth = false,
    String? subtitle,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryGroupItem({
    required String category,
    required double amount,
    required int count,
    required double percentage,
    required double totalAmount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppConstants.getCategoryIcon(category),
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '$count transaksi',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
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
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalAmount > 0 ? (amount / totalAmount).clamp(0.0, 1.0) : 0,
              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, Color color, {bool isPercentage = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          isPercentage ? '${value.toStringAsFixed(1)}%' : _formatCurrency(value),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    final s = amount.abs().toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    final sign = amount < 0 ? '-' : '';
    return '${sign}Rp $buffer';
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    double total = data.values.fold(0, (a, b) => a + b);
    int index = 0;

    return data.entries.map((entry) {
      final percentage = total > 0 ? (entry.value / total) * 100 : 0;
      final color = colors[index % colors.length];
      index++;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: percentage >= 8 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 46,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, double> data) {
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: data.keys.toList().asMap().entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors[entry.key % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              entry.value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        );
      }).toList(),
    );
  }
}