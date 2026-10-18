import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class ChartWidget extends StatefulWidget {
  final List<TransactionModel>? transactions;
  final List<TransactionModel>? monthlyTransactions;
  final List<TransactionModel>? weeklyTransactions;
  final bool isWeekly;

  const ChartWidget({
    super.key,
    this.transactions,
    this.monthlyTransactions,
    this.weeklyTransactions,
    this.isWeekly = false,
  });

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  late bool _isMonthlyView;

  @override
  void initState() {
    super.initState();
    _isMonthlyView = !widget.isWeekly;
  }

  String _formatRupiah(double value) {
    final s = value.abs().toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    final sign = value < 0 ? '-' : '';
    return '${sign}Rp $buffer';
  }

  String _formatCompactNumber(double number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}jt';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}k';
    }
    return number.toStringAsFixed(0);
  }

  List<TransactionModel> get _currentTransactions {
    final now = DateTime.now();
    if (_isMonthlyView) {
      if (widget.monthlyTransactions != null) {
        return widget.monthlyTransactions!;
      }
      if (widget.transactions != null) {
        return widget.transactions!
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .toList();
      }
      return [];
    } else {
      if (widget.weeklyTransactions != null) {
        return widget.weeklyTransactions!;
      }
      if (widget.transactions != null) {
        final start7DaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final endOfToday = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        return widget.transactions!
            .where((t) =>
                !t.date.isBefore(start7DaysAgo) && t.date.isBefore(endOfToday))
            .toList();
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final txList = _currentTransactions;

    final totalIncome = txList
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = txList
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final netCashflow = totalIncome - totalExpense;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Toggle and Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isMonthlyView
                        ? 'Aktualisasi ${DateFormat('MMMM yyyy', 'id_ID').format(now)}'
                        : 'Tren 7 Hari Terakhir',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              // Segmented Toggle Pills
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleItem(
                      title: 'Bulan Ini',
                      isSelected: _isMonthlyView,
                      isDark: isDark,
                      onTap: () {
                        if (!_isMonthlyView) {
                          HapticFeedback.selectionClick();
                          setState(() => _isMonthlyView = true);
                        }
                      },
                    ),
                    _buildToggleItem(
                      title: '7 Hari',
                      isSelected: !_isMonthlyView,
                      isDark: isDark,
                      onTap: () {
                        if (_isMonthlyView) {
                          HapticFeedback.selectionClick();
                          setState(() => _isMonthlyView = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Informative Summary Metrics Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCol(
                  label: 'Masuk',
                  value: _formatRupiah(totalIncome),
                  color: const Color(0xFF10B981),
                  prefix: '+',
                  isDark: isDark,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
                _buildSummaryCol(
                  label: 'Keluar',
                  value: _formatRupiah(totalExpense),
                  color: const Color(0xFFEF4444),
                  prefix: '-',
                  isDark: isDark,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
                _buildSummaryCol(
                  label: 'Arus Kas',
                  value: netCashflow < 0
                      ? '-${_formatRupiah(netCashflow.abs())}'
                      : (netCashflow > 0 ? '+${_formatRupiah(netCashflow)}' : 'Rp 0'),
                  color: netCashflow < 0
                      ? const Color(0xFFEF4444)
                      : (netCashflow > 0 ? const Color(0xFF10B981) : (isDark ? Colors.white70 : Colors.grey.shade700)),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Chart Render Area
          SizedBox(
            height: 185,
            child: txList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 34,
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Belum ada transaksi di periode ini',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : (_isMonthlyView
                    ? _buildMonthlyBarChart(txList, isDark)
                    : _buildWeeklyBarChart(txList, isDark)),
          ),

          const SizedBox(height: 10),

          // Chart Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(const Color(0xFF10B981), 'Pemasukan', isDark),
              const SizedBox(width: 16),
              _buildLegendDot(const Color(0xFFEF4444), 'Pengeluaran', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                : (isDark ? Colors.white38 : Colors.grey.shade500),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCol({
    required String label,
    required String value,
    required Color color,
    String? prefix,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyBarChart(List<TransactionModel> txList, bool isDark) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    final weeks = [
      {'start': 1, 'end': 7, 'label': 'M1'},
      {'start': 8, 'end': 14, 'label': 'M2'},
      {'start': 15, 'end': 21, 'label': 'M3'},
      {'start': 22, 'end': 28, 'label': 'M4'},
      if (daysInMonth > 28) {'start': 29, 'end': daysInMonth, 'label': 'M5'},
    ];

    final barGroups = weeks.asMap().entries.map((entry) {
      final idx = entry.key;
      final w = entry.value;
      final start = w['start'] as int;
      final end = w['end'] as int;

      final weekTx = txList.where((t) =>
          t.date.year == now.year &&
          t.date.month == now.month &&
          t.date.day >= start &&
          t.date.day <= end);

      final inc = weekTx
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);
      final exp = weekTx
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (sum, t) => sum + t.amount);

      return BarChartGroupData(
        x: idx,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: inc,
            color: const Color(0xFF10B981),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: exp,
            color: const Color(0xFFEF4444),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    }).toList();

    double maxY = 0.0;
    for (final g in barGroups) {
      for (final r in g.barRods) {
        if (r.toY > maxY) maxY = r.toY;
      }
    }
    final roundedMaxY = maxY > 0 ? ((maxY / 10000).ceil() * 10000).toDouble() * 1.25 : 50000.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isInc = rodIndex == 0;
              final label = isInc ? 'Masuk' : 'Keluar';
              final color = isInc ? const Color(0xFF10B981) : const Color(0xFFEF4444);
              String title = '';
              if (groupIndex >= 0 && groupIndex < weeks.length) {
                final w = weeks[groupIndex];
                title = 'Minggu ${groupIndex + 1} (${w['start']}-${w['end']})\n';
              }
              return BarTooltipItem(
                '$title$label: ${_formatRupiah(rod.toY)}',
                TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: roundedMaxY > 0 ? roundedMaxY / 3 : 20000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= weeks.length) return const SizedBox.shrink();
                final w = weeks[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${w['label']} (${w['start']}-${w['end']})',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _formatCompactNumber(value),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        maxY: roundedMaxY,
      ),
    );
  }

  Widget _buildWeeklyBarChart(List<TransactionModel> txList, bool isDark) {
    final now = DateTime.now();
    final weekDays = List.generate(7, (i) {
      return now.subtract(Duration(days: 6 - i));
    });

    final barGroups = weekDays.asMap().entries.map((entry) {
      final idx = entry.key;
      final day = entry.value;

      final dayTx = txList.where((t) =>
          t.date.year == day.year &&
          t.date.month == day.month &&
          t.date.day == day.day);

      final inc = dayTx
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);
      final exp = dayTx
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (sum, t) => sum + t.amount);

      return BarChartGroupData(
        x: idx,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
            toY: inc,
            color: const Color(0xFF10B981),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: exp,
            color: const Color(0xFFEF4444),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    }).toList();

    double maxY = 0.0;
    for (final g in barGroups) {
      for (final r in g.barRods) {
        if (r.toY > maxY) maxY = r.toY;
      }
    }
    final roundedMaxY = maxY > 0 ? ((maxY / 10000).ceil() * 10000).toDouble() * 1.25 : 50000.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isInc = rodIndex == 0;
              final label = isInc ? 'Masuk' : 'Keluar';
              final color = isInc ? const Color(0xFF10B981) : const Color(0xFFEF4444);
              String title = '';
              if (groupIndex >= 0 && groupIndex < weekDays.length) {
                title = '${DateFormat('E, dd MMM', 'id_ID').format(weekDays[groupIndex])}\n';
              }
              return BarTooltipItem(
                '$title$label: ${_formatRupiah(rod.toY)}',
                TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: roundedMaxY > 0 ? roundedMaxY / 3 : 20000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= weekDays.length) return const SizedBox.shrink();
                final day = weekDays[index];
                final isToday = day.day == now.day && day.month == now.month && day.year == now.year;

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    isToday ? 'Hari ini' : DateFormat('E', 'id_ID').format(day).substring(0, 3),
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white54 : Colors.grey.shade600),
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _formatCompactNumber(value),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        maxY: roundedMaxY,
      ),
    );
  }
}

class CategoryPieChart extends StatelessWidget {
  final Map<String, double> categoryData;

  const CategoryPieChart({
    super.key,
    required this.categoryData,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryData.isEmpty) {
      return const SizedBox.shrink();
    }

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

    final total = categoryData.values.fold(0.0, (a, b) => a + b);
    int colorIndex = 0;

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              sections: categoryData.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total) * 100 : 0;
                final color = colors[colorIndex % colors.length];
                colorIndex++;

                return PieChartSectionData(
                  color: color,
                  value: entry.value,
                  title: percentage >= 8 ? '${percentage.toStringAsFixed(0)}%' : '',
                  radius: 58,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              centerSpaceColor: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: categoryData.keys.toList().asMap().entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
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
        ),
      ],
    );
  }
}