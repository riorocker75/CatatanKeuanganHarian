import 'package:flutter/material.dart';
import '../models/budget_model.dart';

class BudgetProgressCard extends StatelessWidget {
  final BudgetModel? budget;
  final double currentSpending;
  final double progress;

  const BudgetProgressCard({
    super.key,
    this.budget,
    required this.currentSpending,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    if (budget == null) return const SizedBox.shrink();

    final isExceeded = progress >= 1.0;
    final isWarning = progress >= 0.8;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExceeded ? Colors.red.shade50 : (isWarning ? Colors.orange.shade50 : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExceeded ? Colors.red.shade200 : (isWarning ? Colors.orange.shade200 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget ${budget!.period == BudgetPeriod.daily ? 'Harian' : 'Bulanan'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (isExceeded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'TERLAMPAUI',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isExceeded ? Colors.red : (isWarning ? Colors.orange : Colors.green),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rp ${currentSpending.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isExceeded ? Colors.red : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Rp ${budget!.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          if (isExceeded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ Anda telah melebihi batas budget!',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}