import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String keyReminderEnabled = 'reminder_daily_enabled';
  static const String keyReminderHour = 'reminder_daily_hour';
  static const String keyReminderMinute = 'reminder_daily_minute';

  static const int dailyReminderId = 101;
  static const int testNotificationId = 999;
  static const int countdownTestId = 998;

  bool _isInitialized = false;
  Function(String? payload)? onNotificationTapped;

  /// Inisialisasi zona waktu agar tz.local cocok dengan zona waktu HP pengguna
  void _configureLocalTimeZone() {
    try {
      tz.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;

      // Pencocokan zona waktu Indonesia utama
      if (offset.inHours == 7) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
        return;
      } else if (offset.inHours == 8) {
        tz.setLocalLocation(tz.getLocation('Asia/Makassar'));
        return;
      } else if (offset.inHours == 9) {
        tz.setLocalLocation(tz.getLocation('Asia/Jayapura'));
        return;
      }

      // Pencocokan umum berdasarkan offset millisecond
      for (var location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offset.inMilliseconds) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (e) {
      debugPrint('NotificationService _configureLocalTimeZone error: $e');
    }
  }

  Future<void> init({Function(String? payload)? onSelectNotification}) async {
    if (_isInitialized) return;
    try {
      onNotificationTapped = onSelectNotification;

      // 1. Inisialisasi dan sinkronisasi zona waktu HP
      _configureLocalTimeZone();

      // 2. Android and iOS initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (onNotificationTapped != null) {
            onNotificationTapped!(response.payload);
          }
        },
      );

      // 3. Create default Android Notification Channel
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'daily_reminder_channel',
            'Pengingat Catat Transaksi',
            description:
                'Notifikasi pengingat harian untuk mencatat pemasukan dan pengeluaran.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  Future<bool> requestPermissions() async {
    try {
      await _ensureInitialized();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final notifGranted =
            await androidImplementation.requestNotificationsPermission();

        // Minta izin exact alarm jika didukung (Android 12/13/14+)
        try {
          await androidImplementation.requestExactAlarmsPermission();
        } catch (_) {}

        return notifGranted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('requestPermissions error: $e');
      return true;
    }
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder_channel',
        'Pengingat Catat Transaksi',
        channelDescription:
            'Notifikasi pengingat harian untuk mencatat pemasukan dan pengeluaran.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Memunculkan notifikasi instan seketika (untuk tes & preview)
  Future<bool> showInstantNotification({
    String title = 'Catat Keuangan Hari Ini 📝',
    String body =
        'Adakah transaksi yang mau dicatat hari ini? Yuk catat agar pengeluaran tetap terkontrol!',
    String payload = 'add_transaction',
  }) async {
    try {
      await _ensureInitialized();
      await _notificationsPlugin.show(
        testNotificationId,
        title,
        body,
        _notificationDetails(),
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('showInstantNotification error: $e');
      return false;
    }
  }

  /// Menjadwalkan notifikasi hitung mundur (misal 10 detik lagi)
  /// Sangat cocok untuk menguji apakah notifikasi tetap bunyi saat aplikasi ditutup
  Future<bool> scheduleTestCountdownNotification({
    int seconds = 10,
    String title = 'Pengingat Terjadwal Aktif! ⏰',
    String body =
        'Notifikasi ini tetap muncul meskipun aplikasi telah ditutup! Yuk catat transaksimu.',
    String payload = 'add_transaction',
  }) async {
    try {
      await _ensureInitialized();
      _configureLocalTimeZone();

      final scheduledDate =
          tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

      try {
        await _notificationsPlugin.zonedSchedule(
          countdownTestId,
          title,
          body,
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (e) {
        await _notificationsPlugin.zonedSchedule(
          countdownTestId,
          title,
          body,
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      }
      return true;
    } catch (e) {
      debugPrint('scheduleTestCountdownNotification error: $e');
      return false;
    }
  }

  /// Menjadwalkan pengingat harian pada jam dan menit tertentu
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Catat Keuangan Hari Ini 📝',
    String body =
        'Adakah transaksi yang mau dicatat hari ini? Yuk catat agar pengeluaran tetap terkontrol!',
    String payload = 'add_transaction',
  }) async {
    try {
      await _ensureInitialized();
      _configureLocalTimeZone();

      // Batalkan jadwal lama secara aman
      await cancelDailyReminder();

      // Hitung waktu berikutnya di zona waktu lokal
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Bila jam tersebut sudah lewat untuk hari ini, jadwalkan untuk besok pada jam yang sama
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Coba jadwalkan dengan exact alarm, jika OS melarang fallback ke inexact
      try {
        await _notificationsPlugin.zonedSchedule(
          dailyReminderId,
          title,
          body,
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } catch (scheduleErr) {
        debugPrint('Exact alarm failed, falling back to inexact: $scheduleErr');
        await _notificationsPlugin.zonedSchedule(
          dailyReminderId,
          title,
          body,
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      }

      // Simpan pengaturan ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyReminderEnabled, true);
      await prefs.setInt(keyReminderHour, hour);
      await prefs.setInt(keyReminderMinute, minute);
      return true;
    } catch (e) {
      debugPrint('NotificationService scheduleDailyReminder error: $e');
      return false;
    }
  }

  /// Membatalkan pengingat harian
  Future<void> cancelDailyReminder() async {
    try {
      await _ensureInitialized();
      await _notificationsPlugin.cancel(dailyReminderId);
    } catch (e) {
      debugPrint('NotificationService cancelDailyReminder error: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyReminderEnabled, false);
    } catch (e) {
      debugPrint('SharedPreferences error: $e');
    }
  }

  /// Cek apakah pengingat aktif di SharedPreferences
  Future<bool> isReminderEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyReminderEnabled) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Ambil waktu pengingat yang tersimpan (default 20:00)
  Future<TimeOfDay> getReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hour = prefs.getInt(keyReminderHour) ?? 20;
      final minute = prefs.getInt(keyReminderMinute) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 20, minute: 0);
    }
  }
}
