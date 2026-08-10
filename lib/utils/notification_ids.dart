/// 로컬 알림 ID 공간 — 계통별로 겹치지 않게 나눈 단일 기준.
///
/// flutter_local_notifications 의 알림 ID는 앱 전체에서 하나의 평면 공간이다.
/// 계통마다 제 마음대로 ID를 만들면 서로를 덮어쓰고, `cancelAll()` 을 부르면
/// 남의 알림까지 전부 지워진다. 실제로 생일 알림을 재예약할 때마다 일정·스포츠·
/// 브리핑 알림이 통째로 사라지고 있었다.
///
/// 규칙:
///  - 각 계통은 상위 4비트로 구분되는 자기 대역만 쓴다.
///  - 취소는 [NotificationIds.isInRange] 로 자기 대역만 골라서 한다.
///  - `cancelAll()` 은 어떤 계통에서도 쓰지 않는다.
library;

abstract final class NotificationIds {
  NotificationIds._();

  /// 대역 안에서 쓸 수 있는 비트.
  static const int mask = 0x0FFFFFFF;

  static const int sportsBase = 0x10000000;
  static const int eventBase = 0x20000000;
  static const int briefingBase = 0x30000000;

  /// 생일 당일 알림.
  static const int birthdayBase = 0x40000000;

  /// 생일 D-N 사전 알림 — 당일 알림과 같은 생일이라도 ID가 달라야 한다.
  static const int birthdayAheadBase = 0x50000000;

  /// 공유 캘린더 알림.
  static const int themeShareBase = 0x60000000;

  /// [base] 대역 안의 ID인가.
  static bool isInRange(int id, int base) => id >= base && id <= base + mask;

  /// 임의 문자열 키 → [base] 대역의 안정적인 ID.
  static int forKey(int base, String key) {
    var h = 0;
    for (final code in key.codeUnits) {
      h = (h * 31 + code) & 0x7FFFFFFF;
    }
    return base + (h & mask);
  }
}
