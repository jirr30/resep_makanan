import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showTimerDone(String recipeName) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'timer_channel',
        'Timer Memasak',
        channelDescription: 'Notifikasi timer selesai memasak',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
    );
    await _plugin.show(
      0,
      'Timer Selesai!',
      'Waktu memasak "$recipeName" sudah habis.',
      details,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
