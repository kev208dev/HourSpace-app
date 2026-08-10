import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/utils/date_utils.dart' as du;
import '../models/event_item.dart';
import 'birthday_notifications.dart' show BirthdayNotifications;
import 'notification_ids.dart';

/// 일반 일정 로컬 알림.
/// ID 영역: 0x20000000..0x2FFFFFFF (생일 0x40000000, 스포츠 0x10000000과 분리).
class EventNotifications {
  EventNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const int _idBase = NotificationIds.eventBase;

  static Future<void> _ensureInited() => BirthdayNotifications.init();

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'events',
          '일정 알림',
          channelDescription: '시작 시각 전 일정 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// 모든 일정 알림 취소 후, 미래 시간 일정만 재스케줄.
  /// [enabled] false면 전부 취소만.
  /// [leadMinutes] 시작 N분 전 알림 (0이면 정각).
  static Future<void> scheduleAll(
    Map<String, List<EventItem>> events, {
    required bool enabled,
    required int leadMinutes,
  }) async {
    await _ensureInited();
    await _cancelRange();
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    int count = 0;
    for (final entry in events.entries) {
      final dateKey = entry.key;
      DateTime date;
      try {
        date = du.fromDateKey(dateKey);
      } catch (_) {
        continue;
      }
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (!e.hasTime || e.isTimetable) continue;
        final parts = e.tm!.split(':');
        if (parts.length < 2) continue;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;
        final start = tz.TZDateTime(
            tz.local, date.year, date.month, date.day, h, m);
        final fire = start.subtract(Duration(minutes: leadMinutes));
        if (!fire.isAfter(now)) continue;
        final id = _idFor(dateKey, i, e);
        final body = leadMinutes <= 0
            ? '지금 시작'
            : '$leadMinutes분 후 시작 ($h:${m.toString().padLeft(2, '0')})';
        await _safeSchedule(id, '📅 ${e.t}', body, fire);
        count++;
        // OS 한도 보호 — 최대 60개.
        if (count >= 60) return;
      }
    }
  }

  static Future<void> _cancelRange() async {
    // 안전한 광범위 취소 — 실제 사용 중인 ID만 알 수 없으므로 0..mask 범위 idempotent cancel.
    // 비용 최적화: 마지막 스케줄 ID를 기억하지 않으므로 pending만 조회해 처리.
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (NotificationIds.isInRange(p.id, _idBase)) {
          await _plugin.cancel(p.id);
        }
      }
    } catch (e) {
      debugPrint('[EventNotif] cancel range error: $e');
    }
  }

  static int _idFor(String dateKey, int index, EventItem e) =>
      NotificationIds.forKey(_idBase, '${e.id ?? '$dateKey#$index'}|${e.tm}');

  static Future<void> _safeSchedule(
      int id, String title, String body, tz.TZDateTime when) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[EventNotif] schedule error: $e');
    }
  }
}
