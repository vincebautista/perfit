import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    await AwesomeNotifications().initialize('resource://drawable/perfit_logo', [
      NotificationChannel(
        channelKey: 'default_channel',
        channelName: 'Default',
        channelDescription: 'Default channel for notifications',
        importance: NotificationImportance.High,
      ),
      NotificationChannel(
        channelKey: 'immediate_test_channel',
        channelName: 'Immediate Test',
        channelDescription: 'Channel for immediate test notifications',
        importance: NotificationImportance.High,
      ),
    ]);

    _isInitialized = true;
  }

  static Future<void> scheduleNotification({
    int id = 1,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'default_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(
        date: scheduledDate,
        allowWhileIdle: true,
        repeats: true,
      ),
    );

    print("Scheduled notification for local tz: $scheduledDate");
  }

  static Future<void> showImmediateTestNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1000,
        channelKey: 'immediate_test_channel',
        title: 'Immediate Test',
        body: 'This should appear immediately (test).',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  static Future<void> cancelAll() async {
    await AwesomeNotifications().cancelAll();
  }
}
