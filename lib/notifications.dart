import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Thông báo nhắc hẹn: báo trước giờ hẹn 30 phút hoặc 1 tiếng (tùy từng khách).
class Noti {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Được gọi khi người dùng bấm vào thông báo (truyền id khách).
  static void Function(int customerId)? onTap;

  /// Id khách nếu app được mở từ thông báo khi đang tắt hẳn.
  static int? launchCustomerId;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'nhac_hen_khach',
      'Nhắc hẹn khách hàng',
      channelDescription: 'Thông báo trước giờ hẹn gọi lại / dẫn khách đi xem',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final id = int.tryParse(r.payload ?? '');
        if (id != null) onTap?.call(id);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch != null && launch.didNotificationLaunchApp) {
      launchCustomerId = int.tryParse(launch.notificationResponse?.payload ?? '');
    }
  }

  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static String _before(int minutes) =>
      minutes >= 60 ? '${minutes ~/ 60} tiếng' : '$minutes phút';

  /// Đặt (hoặc đặt lại) thông báo cho 1 khách.
  /// [fromStartup] = true khi app vừa mở: chỉ đặt lại các hẹn còn ở tương lai,
  /// không bắn thông báo ngay để tránh làm phiền.
  static Future<void> schedule(Customer c, {bool fromStartup = false}) async {
    final id = c.id;
    if (id == null) return;
    final now = DateTime.now();
    final t = c.nextCall;

    if (t == null || !t.isAfter(now) || c.status.inactive) {
      if (!fromStartup) await _plugin.cancel(id);
      return;
    }

    final remindAt = t.subtract(Duration(minutes: c.remindMinutes));
    if (fromStartup && !remindAt.isAfter(now)) return;

    await _plugin.cancel(id);

    final hour = DateFormat('HH:mm').format(t);
    final phone = c.phone.trim().isEmpty ? '' : ' - ${c.phone.trim()}';
    final body = '$hour: ${c.apptType} ${c.name}$phone';

    if (!remindAt.isAfter(now.add(const Duration(seconds: 5)))) {
      await _plugin.show(id, 'Sắp đến giờ hẹn', body, _details, payload: '$id');
      return;
    }

    final title = 'Còn ${_before(c.remindMinutes)} nữa: ${c.apptType}';
    final when = tz.TZDateTime.from(remindAt, tz.UTC);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '$id',
      );
    } catch (_) {
      // Máy không cho hẹn giờ chính xác -> dùng chế độ gần đúng.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '$id',
      );
    }
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);

  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<void> rescheduleAll(List<Customer> list) async {
    for (final c in list) {
      try {
        await schedule(c, fromStartup: true);
      } catch (_) {}
    }
  }
}
