import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';

class TransferHistoryScreen extends StatefulWidget {
  const TransferHistoryScreen({super.key});

  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  final TransferService _transferService = TransferService();
  bool _isDeleting = false;

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteTransfer(TransferModel transfer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Riwayat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hapus riwayat ${transfer.isWithdraw ? 'withdraw' : 'transfer'} ini?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saldo akan dikembalikan ke kondisi sebelum ${transfer.isWithdraw ? 'withdraw' : 'transfer'}.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Jumlah: ${transfer.formattedAmount}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus & Kembalikan Saldo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      await _transferService.deleteTransferWithRollback(transfer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Riwayat dihapus & saldo dikembalikan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Silakan login')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transfer & Withdraw'),
      ),
      body: StreamBuilder<List<TransferModel>>(
        stream: _transferService.getUserTransfers(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transfers = snapshot.data ?? [];

          if (transfers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat transfer',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transfers.length,
            itemBuilder: (context, index) {
              final transfer = transfers[index];
              final isWithdraw = transfer.isWithdraw;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== HEADER: Tipe, Tanggal, Tombol Hapus =====
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isWithdraw
                                  ? Colors.orange.shade50
                                  : Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isWithdraw
                                      ? Icons.arrow_upward
                                      : Icons.swap_horiz,
                                  size: 14,
                                  color: isWithdraw
                                      ? Colors.orange.shade700
                                      : Colors.purple.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isWithdraw ? 'WITHDRAW' : 'TRANSFER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isWithdraw
                                        ? Colors.orange.shade700
                                        : Colors.purple.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _formatDate(transfer.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ===== TOMBOL HAPUS (PUSH) =====
                              Material(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: _isDeleting
                                      ? null
                                      : () => _deleteTransfer(transfer),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: _isDeleting
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.red.shade400,
                                            ),
                                          )
                                        : Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red.shade600,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ===== DETAIL TRANSFER =====
                      if (!isWithdraw) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildWalletInfo(
                                label: 'Dari',
                                name: transfer.fromWalletName,
                                isSource: true,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.grey.shade400,
                            ),
                            Expanded(
                              child: _buildWalletInfo(
                                label: 'Ke',
                                name: transfer.toWalletName,
                                isSource: false,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildWalletInfo(
                                label: 'Dari Wallet',
                                name: transfer.fromWalletName,
                                isSource: true,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.grey.shade400,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tujuan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    transfer.toWalletName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      const Divider(height: 24),

                      // ===== JUMLAH & CATATAN =====
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jumlah',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                transfer.formattedAmount,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isWithdraw
                                      ? Colors.red.shade600
                                      : Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                          if (transfer.note != null) ...[
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  transfer.note!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWalletInfo({
    required String label,
    required String name,
    required bool isSource,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSource
                ? Colors.red.shade600
                : Colors.green.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}