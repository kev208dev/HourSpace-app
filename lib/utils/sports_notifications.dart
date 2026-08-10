import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/sports.dart';
import 'notification_ids.dart';
import '../core/platform/platform_support.dart';

/// 스포츠 경기 시작 N분 전 로컬 알림 — flutter_local_notifications + timezone.
/// 생일 알림과 동일 패턴이되, 채널/ID 영역을 분리(겹침 방지).
class SportsNotifications {
  SportsNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static const int _idBase = NotificationIds.sportsBase;

  static Future<void> init() async {
    if (!PlatformSupport.localNotifications || _inited) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _inited = true;
  }

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'sports',
          '스포츠 경기 알림',
          channelDescription: '구독한 팀 경기 시작 전 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  static int _notifId(String eventId) =>
      NotificationIds.forKey(_idBase, eventId);

  /// 스포츠 대역만 취소 — 구독을 끄거나 경기가 사라져도 옛 알림이 남지 않는다.
  static Future<void> _cancelOwnRange() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (NotificationIds.isInRange(p.id, _idBase)) {
          await _plugin.cancel(p.id);
        }
      }
    } catch (e) {
      debugPrint('[SportsNotif] cancel range error: $e');
    }
  }

  /// 스포츠 알림 전체 재스케줄. 구독별 reminderMinutes 적용.
  static Future<void> scheduleAll(
    List<SportSubscription> subs,
    Map<String, List<SportsEvent>> eventsById,
  ) async {
    if (!PlatformSupport.localNotifications) return;
    await init();
    await _cancelOwnRange();
    final subById = {for (final s in subs) s.id: s};
    final now = tz.TZDateTime.now(tz.local);
    for (final entry in eventsById.entries) {
      final sub = subById[entry.key];
      if (sub == null || !sub.enabled || sub.reminderMinutes <= 0) continue;
      for (final ev in entry.value) {
        final start = tz.TZDateTime.from(ev.startAt.toLocal(), tz.local);
        final when = start.subtract(Duration(minutes: sub.reminderMinutes));
        if (when.isBefore(now)) continue; // 지난 경기 skip
        await _schedule(
          _notifId(ev.id),
          '${sub.emoji} ${ev.title}',
          '${sub.reminderMinutes}분 후 경기 시작',
          when,
        );
      }
    }
  }

  static Future<void> _schedule(
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
      debugPrint('[SportsNotif] schedule error: $e');
    }
  }
}
