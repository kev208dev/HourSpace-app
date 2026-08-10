import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'birthday_notifications.dart' show BirthdayNotifications;
import 'notification_ids.dart';

/// 매일 동일 시각 1회 — "오늘의 브리핑" 푸시.
/// ID 영역: 단일 고정 ID(0x30000000)로 항상 덮어쓰기/취소 가능.
class BriefingNotifications {
  BriefingNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const int _id = NotificationIds.briefingBase;

  static Future<void> _ensureInited() => BirthdayNotifications.init();

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'briefing',
          '오늘의 브리핑',
          channelDescription: '매일 아침 일정/할일/급식 요약 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// [enabled] false면 취소만.
  /// [hour] 0..23, [minute] 0..59 — 매일 같은 시각.
  /// [body] 본문 — 호출자가 일정/할일/급식 요약을 미리 만들어 전달.
  ///   다음 firing 전 데이터가 바뀌면 reschedule() 재호출 권장.
  static Future<void> scheduleDaily({
    required bool enabled,
    required int hour,
    int minute = 0,
    String title = '☀️ 오늘의 브리핑',
    String body = '오늘 일정을 확인해 보세요',
  }) async {
    await _ensureInited();
    await _plugin.cancel(_id);
    if (!enabled) return;
    final next = _nextInstance(hour, minute);
    try {
      await _plugin.zonedSchedule(
        _id,
        title,
        body,
        next,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
      );
    } catch (e) {
      debugPrint('[Briefing] schedule error: $e');
    }
  }

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (!d.isAfter(now)) d = d.add(const Duration(days: 1));
    return d;
  }
}
