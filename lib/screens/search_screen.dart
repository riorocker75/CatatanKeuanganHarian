import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_card.dart';
import 'add_transaction_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TransactionService _transactionService = TransactionService();
  
  String _searchQuery = '';
  TransactionType? _filterType;
  String? _filterCategory;
  DateTimeRange? _dateRange;

  final List<String> _categories = [
    'Makanan', 'Transportasi', 'Belanja', 'Hiburan',
    'Kesehatan', 'Pendidikan', 'Gaji', 'Investasi', 'Lainnya'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Silakan login'));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari transaksi...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.shade400),
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _transactionService.getUserTransactions(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var transactions = snapshot.data!;

          // Apply filters
          if (_searchQuery.isNotEmpty) {
            transactions = transactions.where((t) =>
              t.title.toLowerCase().contains(_searchQuery) ||
              t.description.toLowerCase().contains(_searchQuery) ||
              t.category.toLowerCase().contains(_searchQuery)
            ).toList();
          }

          if (_filterType != null) {
            transactions = transactions.where((t) => t.type == _filterType).toList();
          }

          if (_filterCategory != null) {
            transactions = transactions.where((t) => t.category == _filterCategory).toList();
          }

          if (_dateRange != null) {
            transactions = transactions.where((t) =>
              t.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              t.date.isBefore(_dateRange!.end.add(const Duration(days: 1)))
            ).toList();
          }

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Tidak ada hasil', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return TransactionCard(
                transaction: transaction,
                onDelete: () async {
                  await _transactionService.deleteTransaction(transaction);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaksi dihapus'), backgroundColor: Colors.red),
                    );
                  }
                },
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddTransactionScreen(transaction: transaction)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // Type Filter
              const Text('Tipe Transaksi', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: _filterType == null,
                    onSelected: (_) => setModalState(() => _filterType = null),
                  ),
                  ChoiceChip(
                    label: const Text('Pemasukan'),
                    selected: _filterType == TransactionType.income,
                    onSelected: (_) => setModalState(() => _filterType = TransactionType.income),
                  ),
                  ChoiceChip(
                    label: const Text('Pengeluaran'),
                    selected: _filterType == TransactionType.expense,
                    onSelected: (_) => setModalState(() => _filterType = TransactionType.expense),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Filter
              const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: _filterCategory == null,
                    onSelected: (_) => setModalState(() => _filterCategory = null),
                  ),
                  ..._categories.map((cat) => ChoiceChip(
                    label: Text(cat),
                    selected: _filterCategory == cat,
                    onSelected: (_) => setModalState(() => _filterCategory = cat),
                  )),
                ],
              ),
              const SizedBox(height: 16),

              // Date Range
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Rentang Tanggal'),
                subtitle: Text(_dateRange != null 
                  ? '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}'
                  : 'Pilih rentang tanggal'),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setModalState(() => _dateRange = picked);
                  }
                },
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: const Text('Terapkan Filter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}