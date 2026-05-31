class MonthlySummaryModel {
  final int year;
  final int month;
  final double totalIncome;
  final double totalExpense;
  final int transactionCount;

  const MonthlySummaryModel({
    required this.year,
    required this.month,
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.transactionCount = 0,
  });

  double get balance => totalIncome - totalExpense;
  double get savingsRate => totalIncome > 0 ? (balance / totalIncome) * 100 : 0;

  String get monthName {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month];
  }

  String get periodLabel => '$monthName $year';
}