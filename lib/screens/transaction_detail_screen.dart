import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/filter_type.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_card.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String title;
  final Color color;
  final IconData icon;
  final TransactionType? filterType; // null = semua (saldo)

  const TransactionDetailScreen({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    this.filterType,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final TransactionService _transactionService = TransactionService();
  FilterType _selectedFilter = FilterType.daily;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Silakan login')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Total Amount
                StreamBuilder<List<TransactionModel>>(
                  stream: _getFilteredTransactions(user.uid),
                  builder: (context, snapshot) {
                    final transactions = snapshot.data ?? [];
                    final total = transactions.fold(0.0, (sum, t) => sum + t.amount);

                    return Column(
                      children: [
                        Icon(widget.icon, size: 40, color: widget.color),
                        const SizedBox(height: 8),
                        Text(
                          'Total ${widget.title}',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(total),
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${transactions.length} transaksi',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Filter Buttons
                Row(
                  children: [
                    Expanded(child: _buildFilterChip(FilterType.daily)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFilterChip(FilterType.weekly)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFilterChip(FilterType.monthly)),
                  ],
                ),
              ],
            ),
          ),

          // Date Range Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.date_range, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${_formatDate(_selectedFilter.getStartDate())} - ${_formatDate(_selectedFilter.getEndDate().subtract(const Duration(days: 1)))}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: _getFilteredTransactions(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada transaksi ${_selectedFilter.label.toLowerCase()} ini',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(FilterType filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? widget.color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? widget.color : Colors.grey.shade300,
          ),
        ),
        child: Text(
          filter.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Stream<List<TransactionModel>> _getFilteredTransactions(String userId) {
    final startDate = _selectedFilter.getStartDate();
    final endDate = _selectedFilter.getEndDate();

    return _transactionService.getTransactionsByDateRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      type: widget.filterType,
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }
}