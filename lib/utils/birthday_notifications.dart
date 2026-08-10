import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../providers/birthdays_provider.dart';
import 'notification_ids.dart';

/// 생일 로컬 알림 — flutter_local_notifications + timezone.
/// 매년 반복(DateTimeComponents.dateAndTime): 당일 + N일 전 09:00.
class BirthdayNotifications {
  BirthdayNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    // 한국 대상 앱 — 로컬 타임존을 Asia/Seoul로 고정(기기 zone명 조회 패키지 없이).
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

  /// 알림 권한 요청(iOS/Android 13+). 허용 여부 반환.
  static Future<bool> requestPermission() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosOk = await ios?.requestPermissions(
        alert: true, badge: true, sound: true);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final aOk = await android?.requestNotificationsPermission();
    return iosOk ?? aOk ?? true;
  }

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'birthday',
          '생일 알림',
          channelDescription: '친구 생일 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// 전체 재스케줄. 끄면 생일 알림만 취소한다.
  static Future<void> scheduleAll(
    List<Birthday> birthdays, {
    required bool enabled,
    required int daysBefore,
  }) async {
    await init();
    // 예전에는 여기서 cancelAll() 을 불러 일정·스포츠·브리핑 알림까지 전부
    // 지웠다. 이제 생일 대역만 취소한다.
    await _cancelOwnRange();
    if (!enabled) return;
    for (final b in birthdays) {
      if (b.month < 1 || b.month > 12 || b.day < 1 || b.day > 31) continue;
      final dayOf = _nextInstance(b.month, b.day, 9, 0);
      await _schedule(
          _idFor(NotificationIds.birthdayBase, b),
          '🎂 오늘은 ${b.name}님 생일!',
          '잊지 말고 축하해 주세요.',
          dayOf);
      if (daysBefore > 0) {
        final before = dayOf.subtract(Duration(days: daysBefore));
        await _schedule(
            _idFor(NotificationIds.birthdayAheadBase, b),
            '🎂 ${b.name}님 생일 D-$daysBefore',
            '$daysBefore일 후예요.',
            before);
      }
    }
  }

  static int _idFor(int base, Birthday b) =>
      NotificationIds.forKey(base, b.id);

  /// 생일 대역(당일 + D-N)만 취소.
  static Future<void> _cancelOwnRange() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (NotificationIds.isInRange(p.id, NotificationIds.birthdayBase) ||
            NotificationIds.isInRange(
                p.id, NotificationIds.birthdayAheadBase)) {
          await _plugin.cancel(p.id);
        }
      }
    } catch (e) {
      debugPrint('[BirthdayNotif] cancel range error: $e');
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
        matchDateTimeComponents: DateTimeComponents.dateAndTime, // 매년 반복
      );
    } catch (e) {
      debugPrint('[BirthdayNotif] schedule error: $e');
    }
  }

  static tz.TZDateTime _nextInstance(int month, int day, int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(
        tz.local, now.year, month, _clampDay(now.year, month, day), h, m);
    if (d.isBefore(now)) {
      d = tz.TZDateTime(tz.local, now.year + 1, month,
          _clampDay(now.year + 1, month, day), h, m);
    }
    return d;
  }

  static int _clampDay(int y, int month, int day) {
    final last = DateTime(y, month + 1, 0).day;
    return day > last ? last : day;
  }
}
