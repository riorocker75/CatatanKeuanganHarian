import 'package:flutter/material.dart';

/// Card gabungan saldo hari ini (+ pemasukan/pengeluaran inline)
/// dan saldo dompet, bisa digeser ke kanan untuk pindah halaman.
///
/// Halaman 1: Saldo Hari Ini  -> ringkasan pemasukan & pengeluaran hari ini
/// Halaman 2: Total Saldo Dompet -> jumlah semua dompet + jumlah dompet aktif
class BalanceSwipeCard extends StatefulWidget {
  final double todayIncome;
  final double todayExpense;
  final double totalWalletBalance;
  final int walletCount;
  final VoidCallback? onTapWallet;
  final VoidCallback? onTapIncome;
  final VoidCallback? onTapExpense;

  const BalanceSwipeCard({
    super.key,
    required this.todayIncome,
    required this.todayExpense,
    required this.totalWalletBalance,
    required this.walletCount,
    this.onTapWallet,
    this.onTapIncome,
    this.onTapExpense,
  });

  @override
  State<BalanceSwipeCard> createState() => _BalanceSwipeCardState();
}

class _BalanceSwipeCardState extends State<BalanceSwipeCard> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _rupiah(double value) {
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
    final saldoHariIni = widget.todayIncome - widget.todayExpense;
    final saldoColor = saldoHariIni < 0 ? Colors.red.shade300 : Colors.green.shade300;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 210,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SaldoHariIniCard(
                  saldo: _rupiah(saldoHariIni),
                  saldoColor: saldoColor,
                  pemasukan: _rupiah(widget.todayIncome),
                  pengeluaran: _rupiah(widget.todayExpense),
                  onTapIncome: widget.onTapIncome,
                  onTapExpense: widget.onTapExpense,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SaldoDompetCard(
                  saldo: _rupiah(widget.totalWalletBalance),
                  walletCount: widget.walletCount,
                  onTap: widget.onTapWallet,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? Colors.purple.shade400 : const Color(0xFFD8D8E5),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          _index == 0 ? 'Geser ke kanan untuk lihat saldo dompet' : 'Geser ke kiri untuk kembali',
          style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0AE)),
        ),
      ],
    );
  }
}

/// Halaman 1: saldo hari ini + ringkasan pemasukan & pengeluaran dalam satu card.
class _SaldoHariIniCard extends StatelessWidget {
  final String saldo;
  final Color saldoColor;
  final String pemasukan;
  final String pengeluaran;
  final VoidCallback? onTapIncome;
  final VoidCallback? onTapExpense;

  const _SaldoHariIniCard({
    required this.saldo,
    required this.saldoColor,
    required this.pemasukan,
    required this.pengeluaran,
    this.onTapIncome,
    this.onTapExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Saldo Hari Ini',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                saldo,
                style: TextStyle(
                  color: saldoColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white.withOpacity(0.18)),
              const SizedBox(height: 14),
              Row(
                children: [
                  // Pemasukan - pakai _TappableMiniStat untuk feedback visual
                  Expanded(
                    child: _TappableMiniStat(
                      icon: Icons.trending_up,
                      label: 'Pemasukan',
                      amount: pemasukan,
                      onTap: onTapIncome,
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.white.withOpacity(0.18)),
                  // Pengeluaran - pakai _TappableMiniStat untuk feedback visual
                  Expanded(
                    child: _TappableMiniStat(
                      icon: Icons.trending_down,
                      label: 'Pengeluaran',
                      amount: pengeluaran,
                      alignEnd: true,
                      onTap: onTapExpense,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget mini stat yang bisa di-tap dengan visual feedback (opacity change)
class _TappableMiniStat extends StatefulWidget {
  final IconData icon;
  final String label;
  final String amount;
  final bool alignEnd;
  final VoidCallback? onTap;

  const _TappableMiniStat({
    required this.icon,
    required this.label,
    required this.amount,
    this.alignEnd = false,
    this.onTap,
  });

  @override
  State<_TappableMiniStat> createState() => _TappableMiniStatState();
}

class _TappableMiniStatState extends State<_TappableMiniStat> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final iconBg = Colors.white.withOpacity(0.18);

    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.alignEnd) ...[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(widget.icon, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          widget.label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        if (widget.alignEnd) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(widget.icon, color: Colors.white, size: 12),
          ),
        ],
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _isPressed ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: widget.alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            labelRow,
            const SizedBox(height: 6),
            Text(
              widget.amount,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Halaman 2: total saldo dompet, muncul saat di-swipe ke kanan.
class _SaldoDompetCard extends StatelessWidget {
  final String saldo;
  final int walletCount;
  final VoidCallback? onTap;

  const _SaldoDompetCard({required this.saldo, required this.walletCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.account_balance, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Total Saldo Dompet',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (onTap != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Lihat Detail',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  saldo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$walletCount dompet aktif',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}