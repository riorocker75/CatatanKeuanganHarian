import 'package:flutter/material.dart';

class AppConstants {
  static const List<String> defaultExpenseCategories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Kesehatan',
    'Pendidikan',
    'Lainnya',
  ];

  static const List<String> defaultIncomeCategories = [
    'Gaji',
    'Bonus',
    'Investasi',
    'Penjualan',
    'Ngojol',
    'Lainnya',
  ];

  static const Map<String, IconData> categoryIcons = {
    'Makanan': Icons.restaurant,
    'Transportasi': Icons.directions_car,
    'Belanja': Icons.shopping_bag,
    'Tagihan': Icons.receipt_long,
    'Hiburan': Icons.movie,
    'Kesehatan': Icons.local_hospital,
    'Pendidikan': Icons.school,
    'Gaji': Icons.work,
    'Bonus': Icons.card_giftcard,
    'Investasi': Icons.trending_up,
    'Penjualan': Icons.storefront,
    'Ngojol': Icons.two_wheeler,
    'Lainnya': Icons.category,
  };

  static const List<IconData> selectableIcons = [
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_bag,
    Icons.receipt_long,
    Icons.movie,
    Icons.local_hospital,
    Icons.school,
    Icons.work,
    Icons.card_giftcard,
    Icons.trending_up,
    Icons.home,
    Icons.phone_android,
    Icons.computer,
    Icons.fitness_center,
    Icons.storefront,
    Icons.two_wheeler,
    Icons.local_cafe,
    Icons.pets,
    Icons.flight,
    Icons.build,
    Icons.category,
  ];

  static IconData getCategoryIcon(String category) {
    return categoryIcons[category] ?? Icons.category;
  }

  static IconData getIconByCodePoint(int? codePoint, {String? fallbackCategory}) {
    if (codePoint != null) {
      for (final icon in selectableIcons) {
        if (icon.codePoint == codePoint) {
          return icon;
        }
      }
    }
    if (fallbackCategory != null) {
      return getCategoryIcon(fallbackCategory);
    }
    return Icons.category;
  }
}
