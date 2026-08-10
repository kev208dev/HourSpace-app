import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/platform/platform_support.dart';

/// 공유 테마 변경 수신 시 즉시 로컬 알림. 생일 알림과 동일 플러그인.
enum ShareChangeKind { added, updated, removed }

class ThemeShareNotifications {
  ThemeShareNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;
  static int _seq = 0x20000000; // 공유 테마 알림 id 영역

  static Future<void> init() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    if (!PlatformSupport.localNotifications) return;
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _inited = true;
  }

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'theme_share',
          '공유 캘린더 알림',
          channelDescription: '구독한 공유 캘린더의 일정 변경 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// 변경 종류별 문구로 알림 발송.
  static Future<void> notify(String themeName, ShareChangeKind kind) async {
    await init();
    final (title, body) = switch (kind) {
      ShareChangeKind.added => ('📅 "$themeName"', '새 일정이 추가됐어요'),
      ShareChangeKind.removed => ('📅 "$themeName"', '일정이 삭제됐어요'),
      ShareChangeKind.updated => ('📅 "$themeName"', '일정이 변경됐어요'),
    };
    try {
      await _plugin.show(_seq++, title, body, _details);
    } catch (e) {
      debugPrint('[ThemeShareNotif] show error: $e');
    }
  }
}
