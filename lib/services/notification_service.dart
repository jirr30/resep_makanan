import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// Must be top-level for FCM background handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by FCM on Android.
  // No additional handling needed here for now.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─── Channel IDs ───────────────────────────────────────────────────────────
  static const _timerChannel      = 'timer_channel';
  static const _mealChannel       = 'meal_planner_channel';
  static const _socialChannel     = 'social_channel';

  // ─── Notification ID ranges ────────────────────────────────────────────────
  // 0        — timer done
  // 1000-1999 — meal planner (day 0-6 × 3 meals)
  // 2000+    — social (like, comment, follow)

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    // FCM permission (Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ─── FCM Token ─────────────────────────────────────────────────────────────

  Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  // Listen to foreground FCM messages and show local notification
  void listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showSocialNotification(
          notification.title ?? 'ResepKu',
          notification.body ?? '',
        );
      }
    });
  }

  // ─── Timer Done ────────────────────────────────────────────────────────────

  Future<void> showTimerDone(String recipeName) async {
    await init();
    await _plugin.show(
      0,
      'Timer Selesai!',
      'Waktu memasak "$recipeName" sudah habis.',
      _buildDetails(
        channelId: _timerChannel,
        channelName: 'Timer Memasak',
        channelDesc: 'Notifikasi timer selesai memasak',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  // ─── Meal Planner Notifications ────────────────────────────────────────────

  static const _mealHours = {
    'Sarapan':     7,
    'Makan Siang': 12,
    'Makan Malam': 18,
  };

  /// Schedule reminder 30 minutes before each meal in the plan.
  /// [dayPlans] = list of {date: 'yyyy-MM-dd', mealType: string, title: string}
  Future<void> scheduleMealReminders(
      List<Map<String, dynamic>> dayPlans) async {
    await init();
    await cancelMealReminders();

    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < dayPlans.length; i++) {
      final plan      = dayPlans[i];
      final dateStr   = plan['date'] as String;
      final mealType  = plan['mealType'] as String;
      final title     = plan['title'] as String;
      final hour      = _mealHours[mealType] ?? 12;

      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final year  = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day   = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;

      final scheduled = tz.TZDateTime(
        tz.local, year, month, day, hour, 0,
      ).subtract(const Duration(minutes: 30));

      if (scheduled.isBefore(now)) continue; // skip past times

      await _plugin.zonedSchedule(
        1000 + i,
        'Waktunya $mealType!',
        'Segera siapkan: $title 🍳',
        scheduled,
        _buildDetails(
          channelId: _mealChannel,
          channelName: 'Meal Planner',
          channelDesc: 'Pengingat jadwal makan harian',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelMealReminders() async {
    for (int i = 1000; i < 2000; i++) {
      await _plugin.cancel(i);
    }
  }

  // ─── Social Notifications ──────────────────────────────────────────────────

  Future<void> showSocialNotification(String title, String body) async {
    await init();
    final id = 2000 + DateTime.now().millisecondsSinceEpoch % 1000;
    await _plugin.show(
      id,
      title,
      body,
      _buildDetails(
        channelId: _socialChannel,
        channelName: 'Aktivitas Komunitas',
        channelDesc: 'Like, komentar, dan follower baru',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  // ─── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async => _plugin.cancelAll();

  // ─── Helper ────────────────────────────────────────────────────────────────

  NotificationDetails _buildDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
    required Importance importance,
    required Priority priority,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: channelDesc,
        importance: importance,
        priority: priority,
        playSound: true,
      ),
    );
  }
}
