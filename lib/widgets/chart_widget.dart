import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class ChartWidget extends StatelessWidget {
  final List<TransactionModel> transactions;
  final bool isWeekly;

  const ChartWidget({
    super.key,
    required this.transactions,
    this.isWeekly = true,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'Tidak ada data',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: isWeekly ? _buildWeeklyChart() : _buildMonthlyChart(),
    );
  }

  Widget _buildWeeklyChart() {
    final now = DateTime.now();
    final weekDays = List.generate(7, (i) {
      return now.subtract(Duration(days: 6 - i));
    });

    final spots = weekDays.asMap().entries.map((entry) {
      final i = entry.key;
      final day = entry.value;
      final dayTransactions = transactions.where((t) =>
          t.date.year == day.year &&
          t.date.month == day.month &&
          t.date.day == day.day &&
          t.type == TransactionType.expense);

      final total = dayTransactions.fold(0.0, (sum, t) => sum + t.amount);
      return FlSpot(i.toDouble(), total);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final roundedMaxY = ((maxY / 10000).ceil() * 10000).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: roundedMaxY > 0 ? roundedMaxY / 4 : 10000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
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
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= weekDays.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('E', 'id_ID').format(weekDays[index]).substring(0, 3),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCompactNumber(value),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: roundedMaxY > 0 ? roundedMaxY : 10000,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green.shade600,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.green.shade600,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.shade100.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final barGroups = List.generate(daysInMonth, (index) {
      final day = index + 1;
      final dayTransactions = transactions.where((t) =>
          t.date.year == now.year &&
          t.date.month == now.month &&
          t.date.day == day &&
          t.type == TransactionType.expense);

      final total = dayTransactions.fold(0.0, (sum, t) => sum + t.amount);

      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: total,
            color: Colors.green.shade600,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    final maxY = barGroups
        .map((g) => g.barRods.first.toY)
        .reduce((a, b) => a > b ? a : b);
    final roundedMaxY = ((maxY / 10000).ceil() * 10000).toDouble();

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: roundedMaxY > 0 ? roundedMaxY / 4 : 10000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
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
              getTitlesWidget: (value, meta) {
                if (value % 5 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCompactNumber(value),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        maxY: roundedMaxY > 0 ? roundedMaxY : 10000,
      ),
    );
  }

  String _formatCompactNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}k';
    }
    return number.toStringAsFixed(0);
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
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.yellow.shade600,
      Colors.green.shade400,
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.pink.shade400,
      Colors.teal.shade400,
    ];

    final total = categoryData.values.fold(0.0, (a, b) => a + b);
    int colorIndex = 0;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: categoryData.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total) * 100 : 0;
                final color = colors[colorIndex % colors.length];
                colorIndex++;

                return PieChartSectionData(
                  color: color,
                  value: entry.value,
                  title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  badgeWidget: percentage >= 5
                      ? Icon(
                          _getCategoryIcon(entry.key),
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                  badgePositionPercentageOffset: 0.8,
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              centerSpaceColor: Colors.grey.shade50,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: categoryData.keys.toList().asMap().entries.map((entry) {
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
                const SizedBox(width: 6),
                Text(
                  entry.value,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    final icons = {
      'Makanan': Icons.restaurant,
      'Transportasi': Icons.directions_car,
      'Belanja': Icons.shopping_bag,
      'Hiburan': Icons.movie,
      'Kesehatan': Icons.local_hospital,
      'Pendidikan': Icons.school,
      'Gaji': Icons.work,
      'Investasi': Icons.trending_up,
      'Lainnya': Icons.category,
    };
    return icons[category] ?? Icons.category;
  }
}