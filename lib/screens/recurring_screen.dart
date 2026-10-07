import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../services/recurring_service.dart';
import '../services/holiday_service.dart';
import '../utils/constants.dart';
import 'add_recurring_screen.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  Future<void> _deleteRecurring(BuildContext context, RecurringService service, RecurringTransactionModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi Rutin'),
        content: Text('Hapus transaksi rutin "${item.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await service.deleteRecurring(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi rutin dihapus'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Silakan login')));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final recurringService = RecurringService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Rutin Cerdas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Transaksi Rutin',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddRecurringScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<RecurringTransactionModel>>(
        stream: recurringService.getUserRecurring(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final recurringList = snapshot.data ?? [];

          if (recurringList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada transaksi rutin',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddRecurringScreen()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Transaksi Rutin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recurringList.length,
            itemBuilder: (context, index) {
              final item = recurringList[index];
              final isExpense = item.type == TransactionType.expense;
              final effectiveDate = item.getEffectiveNextDate();
              final rawDate = item.getRawNextDate();
              final hasAdjustment = item.businessDayRule != BusinessDayRule.none && rawDate.day != effectiveDate.day;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Slidable(
                  key: ValueKey(item.id),
                  endActionPane: ActionPane(
                    motion: const BehindMotion(),
                    extentRatio: 0.24,
                    children: [
                      CustomSlidableAction(
                        onPressed: (_) {
                          HapticFeedback.mediumImpact();
                          _deleteRecurring(context, recurringService, item);
                        },
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35), width: 1.2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 17),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Hapus',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: item.isActive
                          ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Icon, Title, Wallet & Switch + Swipe Hint
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isExpense
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                    : const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                AppConstants.getCategoryIcon(item.category),
                                color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      decoration: item.isActive ? null : TextDecoration.lineThrough,
                                      color: item.isActive
                                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                          : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        item.category,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                      if (item.walletName != null) ...[
                                        const SizedBox(width: 6),
                                        Text('•', style: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                                        const SizedBox(width: 6),
                                        Text(
                                          item.walletName!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8B5CF6),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.swipe_left_rounded,
                                  size: 13,
                                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 4),
                                Switch(
                                  value: item.isActive,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (value) async {
                                    HapticFeedback.selectionClick();
                                    await recurringService.updateRecurring(
                                      item.copyWith(isActive: value),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                    const SizedBox(height: 12),

                    // Row 2: Frequency Badge, Execution Time Badge, Rule Badge, & Amount
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getFrequencyLabel(item),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.teal.shade900.withOpacity(0.3) : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.teal.shade600),
                              const SizedBox(width: 4),
                              Text(
                                item.formattedExecutionTime,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.businessDayRule != BusinessDayRule.none)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_available, size: 12, color: Colors.amber.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  item.businessDayRule.shortLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Amount & Effective Date info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jadwal berikutnya:',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${_formatDate(effectiveDate)} pk ${item.formattedExecutionTime}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: hasAdjustment ? Colors.amber.shade700 : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                              if (hasAdjustment)
                                Text(
                                  '(Disesuaikan dari tgl ${rawDate.day} karena akhir pekan/libur)',
                                  style: TextStyle(fontSize: 10, color: Colors.amber.shade700, fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${isExpense ? '-' : '+'} Rp ${item.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: isExpense ? Colors.red.shade500 : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ),
);
}

  String _getFrequencyLabel(RecurringTransactionModel item) {
    switch (item.frequency) {
      case RecurringFrequency.daily:
        return 'Setiap Hari';
      case RecurringFrequency.weekly:
        return 'Setiap Minggu';
      case RecurringFrequency.monthly:
        final d = item.targetDayOfMonth ?? item.startDate.day;
        return 'Setiap tgl $d';
      case RecurringFrequency.yearly:
        return 'Setiap Tahun';
    }
  }

  String _formatDate(DateTime date) {
    final dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dayNames[date.weekday - 1]}, ${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }
}