import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'note_deadline_channel',
        'Note Deadline Reminders',
        channelDescription: 'Nhắc hạn ghi chú và công việc học tập',
        importance: Importance.max,
        priority: Priority.high,
      );

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'note_deadline_channel',
        'Note Deadline Reminders',
        description: 'Nhắc hạn ghi chú và công việc học tập',
        importance: Importance.max,
      ),
    );
  }

  static Future<bool> ensurePermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final enabled = await androidPlugin?.areNotificationsEnabled();
    if (enabled == true) return true;

    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<bool> scheduleDeadlineNotifications({
    required String noteId,
    required String title,
    required DateTime deadline,
    required int minutesBefore,
    bool recurringWeekly = false,
  }) async {
    final allowed = await ensurePermission();
    if (!allowed) {
      return false;
    }

    await cancelReminder(noteId);

    final now = DateTime.now();
    final beforeTime = deadline.subtract(Duration(minutes: minutesBefore));
    var scheduledAny = false;

    if (minutesBefore > 0 && beforeTime.isAfter(now)) {
      await _plugin.zonedSchedule(
        _beforeNotificationId(noteId),
        'Nhắc trước deadline',
        '$title sắp đến hạn lúc ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}',
        tz.TZDateTime.from(beforeTime, tz.local),
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: noteId,
        matchDateTimeComponents: recurringWeekly
            ? DateTimeComponents.dayOfWeekAndTime
            : null,
      );
      scheduledAny = true;
    }

    if (deadline.isAfter(now)) {
      await _plugin.zonedSchedule(
        _deadlineNotificationId(noteId),
        'Đến hạn ghi chú',
        '$title đã đến thời điểm deadline.',
        tz.TZDateTime.from(deadline, tz.local),
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: noteId,
        matchDateTimeComponents: recurringWeekly
            ? DateTimeComponents.dayOfWeekAndTime
            : null,
      );
      scheduledAny = true;
    }

    return scheduledAny;
  }

  static Future<void> cancelReminder(String noteId) async {
    await _plugin.cancel(_beforeNotificationId(noteId));
    await _plugin.cancel(_deadlineNotificationId(noteId));
  }

  static Future<void> showTestNotification() async {
    await _plugin.show(
      999001,
      'Test thông báo',
      'Nếu bạn thấy thông báo này, quyền notification đã hoạt động.',
      const NotificationDetails(android: _androidDetails),
    );
  }

  static int _baseNotificationId(String noteId) {
    return (noteId.hashCode & 0x7fffffff) * 10;
  }

  static int _beforeNotificationId(String noteId) {
    return _baseNotificationId(noteId) + 1;
  }

  static int _deadlineNotificationId(String noteId) {
    return _baseNotificationId(noteId) + 2;
  }
}
