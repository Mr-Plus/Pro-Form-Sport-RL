import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings: initSettings);

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'rowing_reminders',
              'Rappels d\'entraînement Rameur',
              description:
                  'Notifications réelles pour vos séances et programmes de rameur',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidPlugin.requestNotificationsPermission();
        }
      } else if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Notification setup error: $e');
    }

    _isInitialized = true;
  }

  /// Demande explicitement l'autorisation de notifications à l'utilisateur
  Future<bool> requestPermission() async {
    await initialize();
    try {
      if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final res = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return res ?? false;
      } else if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final res = await androidPlugin?.requestNotificationsPermission();
        return res ?? false;
      }
    } catch (_) {}
    return false;
  }

  /// Envoie immédiatement une vraie notification (iOS et Android)
  Future<void> sendInstantNotification({
    required String title,
    required String body,
    int id = 100,
  }) async {
    await initialize();
    await requestPermission();

    const androidDetails = AndroidNotificationDetails(
      'rowing_reminders',
      'Rappels d\'entraînement Rameur',
      channelDescription:
          'Notifications réelles pour vos séances et programmes de rameur',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Programme un rappel d'entraînement à une date/heure précise (iOS et Android)
  Future<void> scheduleSessionReminder({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (scheduledDate.isBefore(DateTime.now())) return;

    try {
      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
      const androidDetails = AndroidNotificationDetails(
        'rowing_reminders',
        'Rappels d\'entraînement Rameur',
        channelDescription:
            'Notifications réelles pour vos séances et programmes de rameur',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDateTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
