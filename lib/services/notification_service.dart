import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if(_initialized) return;
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showOngoing() async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'keep_alive',
      '后台常驻',
      channelDescription: '保持应用后台运行的常驻通知',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showWhen: false,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _plugin.show(1001, '应用持续运行中', '点击可返回应用', details);
  }

  Future<void> cancelOngoing() async {
    await _plugin.cancel(1001);
  }
} 