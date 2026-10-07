import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/voice_nlp_service.dart';
import '../services/category_service.dart';
import '../services/wallet_service.dart';
import '../services/transaction_service.dart';
import '../screens/add_transaction_screen.dart';

class VoiceInputModal extends StatefulWidget {
  const VoiceInputModal({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceInputModal(),
    );
  }

  @override
  State<VoiceInputModal> createState() => _VoiceInputModalState();
}

class _VoiceInputModalState extends State<VoiceInputModal> with SingleTickerProviderStateMixin {
  final VoiceNlpService _voiceService = VoiceNlpService();
  final CategoryService _categoryService = CategoryService();
  final WalletService _walletService = WalletService();
  final TransactionService _transactionService = TransactionService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _spokenText = '';
  ParsedVoiceData? _parsedData;
  bool _isListening = false;
  bool _isSaving = false;
  String _statusMessage = 'Mendengarkan suara Anda...';

  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];
  List<WalletModel> _wallets = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadContextDataAndStart();
  }

  Future<void> _loadContextDataAndStart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _expenseCategories = await _categoryService.getAllCategories(user.uid, 'expense');
      _incomeCategories = await _categoryService.getAllCategories(user.uid, 'income');
      _wallets = await _walletService.getUserWallets(user.uid).first;
    }
    _startRecording();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isListening = true;
      _statusMessage = 'Katakan contoh: "Beli nasi padang 25 ribu pakai GoPay"';
      _spokenText = '';
      _parsedData = null;
    });

    final success = await _voiceService.initialize();
    if (!success) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusMessage = 'Mikrofon tidak dapat diakses. Pastikan izin telah diberikan.';
        });
      }
      return;
    }

    await _voiceService.startListening(
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _spokenText = text;
          _parsedData = _voiceService.parseVoiceText(
            text,
            expenseCategories: _expenseCategories,
            incomeCategories: _incomeCategories,
            userWallets: _wallets,
          );
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
  }

  Future<void> _stopRecording() async {
    await _voiceService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _saveDirectly() async {
    if (_parsedData == null || _parsedData!.amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal belum terdeteksi. Silakan coba lagi atau edit di form.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final transaction = TransactionModel(
        id: '',
        userId: user.uid,
        title: _parsedData!.title,
        amount: _parsedData!.amount,
        type: _parsedData!.type,
        category: _parsedData!.category,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        walletId: _parsedData!.walletId,
      );

      await _transactionService.addTransaction(transaction);
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Transaksi "${_parsedData!.title}" berhasil dicatat'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openInForm() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          prefilledTitle: _parsedData?.title,
          prefilledAmount: _parsedData?.amount,
          prefilledType: _parsedData?.type,
          prefilledCategory: _parsedData?.category,
          prefilledWalletId: _parsedData?.walletId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceService.stopListening();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mic_rounded, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Catat Lewat Suara',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Microphone Button with Pulse Animation
          GestureDetector(
            onTap: () {
              if (_isListening) {
                _stopRecording();
              } else {
                _startRecording();
              }
            },
            child: ScaleTransition(
              scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isListening
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [Colors.grey.shade700, Colors.grey.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? primaryColor : Colors.black).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Status / Transcription Text
          Text(
            _isListening ? 'Mendengarkan...' : 'Ketuk mikrofon untuk mulai bicara',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isListening ? primaryColor : (isDark ? Colors.white54 : Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Text(
              _spokenText.isNotEmpty ? '"$_spokenText"' : _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontStyle: _spokenText.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                color: _spokenText.isNotEmpty
                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                    : (isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Parsed Transaction Live Preview Card
          if (_parsedData != null && _parsedData!.amount > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _parsedData!.type == TransactionType.income
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444).withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (_parsedData!.type == TransactionType.income
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))
                                  .withOpacity(0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _parsedData!.type == TransactionType.income
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: _parsedData!.type == TransactionType.income
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _parsedData!.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _parsedData!.type == TransactionType.income
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatRupiah(_parsedData!.amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _parsedData!.type == TransactionType.income
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Judul:', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                            Text(_parsedData!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kategori:', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                            Text(_parsedData!.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (_parsedData!.walletName != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dompet:', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                              Text(_parsedData!.walletName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openInForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Edit di Form',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveDirectly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Simpan Langsung',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
