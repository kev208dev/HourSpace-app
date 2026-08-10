/// 플랫폼별로 쓸 수 있는 네이티브 기능을 한 곳에서 판별한다.
///
/// 웹 프리뷰를 위해 추가했다. 모바일 동작은 그대로 두고, 웹에서만 조용히
/// 건너뛴다 — 각 호출부에 `kIsWeb` 을 흩뿌리면 나중에 무엇이 왜 꺼졌는지
/// 추적이 안 된다.
///
/// 여기서 false 인 기능은 **없는 척** 하는 게 아니라 **조용히 아무 일도 하지
/// 않는다.** 사용자에게 보이는 화면·정보구조는 플랫폼과 무관하게 같아야 한다.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class PlatformSupport {
  PlatformSupport._();

  /// 홈스크린 위젯(home_widget) — iOS WidgetKit / Android AppWidget 전용.
  static bool get homeWidget => !kIsWeb;

  /// 로컬 알림(flutter_local_notifications) — 웹 구현 없음.
  static bool get localNotifications => !kIsWeb;

  /// 갤러리 저장(gal) — 웹에는 갤러리 개념이 없다.
  static bool get gallerySave => !kIsWeb;

  /// 웹에서 돌고 있는가. 화면 폭 제한 등 표시 로직에만 쓴다.
  static bool get isWeb => kIsWeb;
}
