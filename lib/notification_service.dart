import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Hong_Kong'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  Future<String> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notification_time') ?? '09:00';
  }

  Future<void> setNotificationTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_time', time);
  }

  Future<void> scheduleMatchNotification({
    required int id,
    required String teamName,
    required String opponent,
    required DateTime matchDate,
    required String matchTime,
    required String venue,
  }) async {
    if (!await isEnabled()) return;

    final notifTime = await getNotificationTime();
    final scheduledDate = _calculateNotificationTime(matchDate, matchTime, notifTime);

    if (scheduledDate.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'match_notifications',
      '比賽通知',
      channelDescription: '提醒即將進行的比賽',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.zonedSchedule(
      id,
      '🏀 比賽提醒：$teamName',
      'vs $opponent\n$matchTime @ $venue',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleTrainingNotification({
    required int id,
    required String teamName,
    required String title,
    required DateTime trainingDate,
    required String trainingTime,
    required String venue,
  }) async {
    if (!await isEnabled()) return;

    final notifTime = await getNotificationTime();
    final scheduledDate = _calculateNotificationTime(trainingDate, trainingTime, notifTime);

    if (scheduledDate.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'training_notifications',
      '訓練通知',
      channelDescription: '提醒即將進行的訓練',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.zonedSchedule(
      id,
      '💪 訓練提醒：$teamName',
      '$title\n$trainingTime @ $venue',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  DateTime _calculateNotificationTime(DateTime matchDate, String matchTime, String notifTime) {
    final timeParts = matchTime.split(':');
    final matchHour = int.tryParse(timeParts[0]) ?? 20;
    final matchMinute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;

    final fullMatchDateTime = DateTime(
      matchDate.year, matchDate.month, matchDate.day, matchHour, matchMinute,
    );

    if (notifTime.contains('小時前')) {
      final hours = int.tryParse(notifTime.replaceAll('小時前', '').trim()) ?? 3;
      return fullMatchDateTime.subtract(Duration(hours: hours));
    } else if (notifTime.contains('分鐘前')) {
      final minutes = int.tryParse(notifTime.replaceAll('分鐘前', '').trim()) ?? 30;
      return fullMatchDateTime.subtract(Duration(minutes: minutes));
    } else {
      // Fixed time (e.g., "09:00")
      final parts = notifTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 9;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      var scheduledTime = DateTime(matchDate.year, matchDate.month, matchDate.day, hour, minute);

      // If notification time has passed today but match is in the future, schedule for match day
      if (scheduledTime.isBefore(DateTime.now()) && fullMatchDateTime.isAfter(DateTime.now())) {
        // Keep the scheduled time on match day
        return scheduledTime;
      }

      return scheduledTime;
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
