import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

enum BusinessDayRule {
  none,               // Tepat tanggal kalender biasa
  previousWorkingDay, // Dimajukan ke hari kerja sebelumnya jika akhir pekan/libur nasional (Direkomendasikan untuk Gaji)
  nextWorkingDay,     // Diundur ke hari kerja berikutnya jika akhir pekan/libur nasional
}

extension BusinessDayRuleExtension on BusinessDayRule {
  String get label {
    switch (this) {
      case BusinessDayRule.previousWorkingDay:
        return 'Maju ke Hari Kerja Sebelumnya (Gaji/Payroll)';
      case BusinessDayRule.nextWorkingDay:
        return 'Mundur ke Hari Kerja Berikutnya';
      case BusinessDayRule.none:
        return 'Tepat Tanggal Kalender Biasa';
    }
  }

  String get shortLabel {
    switch (this) {
      case BusinessDayRule.previousWorkingDay:
        return 'Maju jika Libur';
      case BusinessDayRule.nextWorkingDay:
        return 'Mundur jika Libur';
      case BusinessDayRule.none:
        return 'Tepat Tanggal';
    }
  }
}

class HolidayService {
  static final HolidayService _instance = HolidayService._internal();
  factory HolidayService() => _instance;
  HolidayService._internal();

  // Set of formatted dates: "YYYY-MM-DD"
  final Map<int, Set<String>> _holidayCacheByYear = {};

  // Built-in fallback Indonesian National Holidays (Fixed + Common Major Religious Holidays)
  // Format: "YYYY-MM-DD"
  final Map<int, List<String>> _fallbackHolidays = {
    2025: [
      '2025-01-01', // Tahun Baru Masehi
      '2025-01-27', // Isra Mi'raj
      '2025-01-29', // Tahun Baru Imlek
      '2025-03-29', // Hari Suci Nyepi
      '2025-03-31', // Idul Fitri 1446 H
      '2025-04-01', // Idul Fitri 1446 H
      '2025-04-18', // Wafat Yesus Kristus
      '2025-04-20', // Hari Paskah
      '2025-05-01', // Hari Buruh Internasional
      '2025-05-12', // Hari Raya Waisak
      '2025-05-29', // Kenaikan Yesus Kristus
      '2025-06-01', // Hari Lahir Pancasila
      '2025-06-07', // Idul Adha 1446 H
      '2025-06-27', // Tahun Baru Islam 1447 H
      '2025-08-17', // Hari Kemerdekaan RI
      '2025-09-05', // Maulid Nabi Muhammad SAW
      '2025-12-25', // Hari Raya Natal
    ],
    2026: [
      '2026-01-01', // Tahun Baru Masehi
      '2026-01-16', // Isra Mi'raj
      '2026-02-17', // Tahun Baru Imlek
      '2026-03-19', // Hari Suci Nyepi
      '2026-03-20', // Idul Fitri
      '2026-03-21', // Idul Fitri
      '2026-04-03', // Wafat Yesus Kristus
      '2026-05-01', // Hari Buruh Internasional
      '2026-05-14', // Kenaikan Yesus Kristus
      '2026-05-31', // Hari Raya Waisak
      '2026-06-01', // Hari Lahir Pancasila
      '2026-05-27', // Idul Adha
      '2026-06-16', // Tahun Baru Islam
      '2026-08-17', // Hari Kemerdekaan RI
      '2026-08-25', // Maulid Nabi Muhammad SAW
      '2026-12-25', // Hari Raya Natal
    ],
    2027: [
      '2027-01-01', // Tahun Baru Masehi
      '2027-02-06', // Tahun Baru Imlek
      '2027-03-09', // Idul Fitri
      '2027-03-10', // Idul Fitri
      '2027-03-26', // Wafat Yesus Kristus
      '2027-05-01', // Hari Buruh Internasional
      '2027-05-06', // Kenaikan Yesus Kristus
      '2027-05-20', // Hari Raya Waisak
      '2027-06-01', // Hari Lahir Pancasila
      '2027-08-17', // Hari Kemerdekaan RI
      '2027-12-25', // Hari Raya Natal
    ],
  };

  String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Inisialisasi dan load cache untuk tahun tertentu
  Future<void> loadHolidaysForYear(int year) async {
    if (_holidayCacheByYear.containsKey(year) && _holidayCacheByYear[year]!.isNotEmpty) {
      return;
    }

    final set = <String>{};

    // 1. Tambahkan fallback bawaan terlebih dahulu
    if (_fallbackHolidays.containsKey(year)) {
      set.addAll(_fallbackHolidays[year]!);
    } else {
      set.add('$year-01-01');
      set.add('$year-05-01');
      set.add('$year-06-01');
      set.add('$year-08-17');
      set.add('$year-12-25');
    }

    // 2. Coba load dari SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('id_holidays_$year');
      if (cachedJson != null) {
        final List<dynamic> list = jsonDecode(cachedJson);
        for (var item in list) {
          if (item is String) set.add(item);
        }
      }
    } catch (_) {}

    _holidayCacheByYear[year] = set;

    // 3. Fetch dari API secara asynchronous di background
    _fetchFromApiInBackground(year);
  }

  void _fetchFromApiInBackground(int year) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      final uri = Uri.parse('https://dayoffapi.vercel.app/api?year=$year');
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> data = jsonDecode(responseBody);

        final Set<String> fetchedSet = {};
        for (var item in data) {
          if (item['is_holiday'] == true || item['is_cuti'] == true || item['tanggal'] != null) {
            final tanggal = item['tanggal'] as String?;
            if (tanggal != null && tanggal.isNotEmpty) {
              fetchedSet.add(tanggal);
            }
          }
        }

        if (fetchedSet.isNotEmpty) {
          _holidayCacheByYear[year]?.addAll(fetchedSet);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('id_holidays_$year', jsonEncode(_holidayCacheByYear[year]!.toList()));
        }
      }
      client.close();
    } catch (_) {
      // Ignored - fallback sudah terpasang
    }
  }

  /// Cek apakah hari Sabtu atau Minggu
  bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Cek apakah tanggal tersebut adalah Hari Libur Nasional Indonesia
  bool isNationalHoliday(DateTime date) {
    final year = date.year;
    final set = _holidayCacheByYear[year];
    if (set == null) {
      final fallback = _fallbackHolidays[year] ?? [
        '$year-01-01',
        '$year-05-01',
        '$year-06-01',
        '$year-08-17',
        '$year-12-25',
      ];
      return fallback.contains(_formatDateKey(date));
    }
    return set.contains(_formatDateKey(date));
  }

  /// Cek apakah hari kerja aktif (Bukan weekend & Bukan Libur Nasional)
  bool isWorkingDay(DateTime date) {
    return !isWeekend(date) && !isNationalHoliday(date);
  }

  /// Cari hari kerja sebelumnya jika jatuh pada hari libur / weekend (Cocok untuk Gaji)
  DateTime getPreviousWorkingDay(DateTime date) {
    DateTime current = DateTime(date.year, date.month, date.day);
    while (!isWorkingDay(current)) {
      current = current.subtract(const Duration(days: 1));
    }
    return current;
  }

  /// Cari hari kerja berikutnya jika jatuh pada hari libur / weekend
  DateTime getNextWorkingDay(DateTime date) {
    DateTime current = DateTime(date.year, date.month, date.day);
    while (!isWorkingDay(current)) {
      current = current.add(const Duration(days: 1));
    }
    return current;
  }

  /// Hitung tanggal efektif yang disesuaikan dengan aturan hari kerja
  DateTime getAdjustedDate(DateTime date, BusinessDayRule rule) {
    switch (rule) {
      case BusinessDayRule.previousWorkingDay:
        return getPreviousWorkingDay(date);
      case BusinessDayRule.nextWorkingDay:
        return getNextWorkingDay(date);
      case BusinessDayRule.none:
        return DateTime(date.year, date.month, date.day);
    }
  }
}
