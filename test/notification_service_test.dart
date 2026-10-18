import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:keuangan_harian/services/notification_service.dart';

void main() {
  group('NotificationService Configuration Tests', () {
    test('Notification constants and channel IDs are configured properly', () {
      expect(NotificationService.dailyReminderId, 101);
      expect(NotificationService.testNotificationId, 999);
      expect(NotificationService.keyReminderEnabled, 'reminder_daily_enabled');
      expect(NotificationService.keyReminderHour, 'reminder_daily_hour');
      expect(NotificationService.keyReminderMinute, 'reminder_daily_minute');
    });

    test('Perhitungan waktu penjadwalan harian', () {
      final now = DateTime(2026, 10, 18, 14, 30); // 14:30

      // Waktu lebih lambat di hari yang sama (misal 20:00) -> harus di hari yang sama
      final targetTimeToday = DateTime(now.year, now.month, now.day, 20, 0);
      expect(targetTimeToday.isAfter(now), true);

      // Waktu yang sudah lewat di hari ini (misal 08:00) -> harus ditambahkan 1 hari (besok)
      var targetTimeTomorrow = DateTime(now.year, now.month, now.day, 8, 0);
      if (targetTimeTomorrow.isBefore(now)) {
        targetTimeTomorrow = targetTimeTomorrow.add(const Duration(days: 1));
      }
      expect(targetTimeTomorrow.isAfter(now), true);
      expect(targetTimeTomorrow.day, now.day + 1);
    });

    test('Format jam TimeOfDay ke string HH:mm', () {
      String formatTime(TimeOfDay time) {
        final hour = time.hour.toString().padLeft(2, '0');
        final minute = time.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      }

      expect(formatTime(const TimeOfDay(hour: 8, minute: 5)), '08:05');
      expect(formatTime(const TimeOfDay(hour: 20, minute: 0)), '20:00');
      expect(formatTime(const TimeOfDay(hour: 0, minute: 0)), '00:00');
    });

    test('Check timezone tz.local name after initializeTimeZones', () {
      tz.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;
      if (offset.inHours == 7) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } else if (offset.inHours == 8) {
        tz.setLocalLocation(tz.getLocation('Asia/Makassar'));
      } else if (offset.inHours == 9) {
        tz.setLocalLocation(tz.getLocation('Asia/Jayapura'));
      }

      final nowLocal = tz.TZDateTime.now(tz.local);
      final dtNow = DateTime.now();
      expect(nowLocal.hour, dtNow.hour);
      expect(nowLocal.minute, dtNow.minute);
      print('DEBUG: Configured tz.local: ${tz.local.name}, nowLocal hour: ${nowLocal.hour}, dtNow hour: ${dtNow.hour}');
    });
  });
}
