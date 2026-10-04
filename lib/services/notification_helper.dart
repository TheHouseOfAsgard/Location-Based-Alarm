import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Call in every isolate that shows notifications. Create channels once, in main().
  static Future<void> init({bool createChannels = false}) async {
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));

    if (createChannels) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        trackingChannelId,
        'Location tracking',
        description: 'Ongoing notification while tracking is active',
        importance: Importance.low,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        alarmChannelId,
        'Location alarm',
        description: 'Fires when you reach your destination',
        importance: Importance.max,
        playSound: false, // sound is handled by AlarmService
        enableVibration: false,
      ));
    }
  }

  /// Full-screen intent so the alarm UI appears over the lock screen.
  static Future<void> showAlarm(String body) => _plugin.show(
        alarmNotificationId,
        'You have arrived!',
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            alarmChannelId,
            'Location alarm',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            playSound: false,
            enableVibration: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: false,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      );

  static Future<void> cancelAlarm() => _plugin.cancel(alarmNotificationId);
}
