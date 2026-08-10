/// 교시 ↔ 실제 시각 변환 — 앱 전체 단일 기준.
///
/// NEIS OpenAPI는 시간표 과목만 주고 교시별 시각은 주지 않는다. 그래서 국내
/// 일반적인 일과시간을 기준값으로 쓴다: 1교시 08:40 시작, 수업 50분 + 쉬는 시간
/// 10분, 점심 12:30~13:30, 5교시는 13:30 시작.
///
/// 시간표 화면과 캘린더 데이터 계층이 각자 다른 값을 쓰면 같은 수업이 화면마다
/// 다른 시각에 그려지므로, 계산은 반드시 여기 한 곳만 쓴다.
library;

/// 하루 중 분 단위 시각 범위(0시 기준).
typedef MinuteRange = (int startMin, int endMin);

const int kPeriodMinutes = 50;
const int kBreakMinutes = 10;

/// 교시(1-base) → (시작 분, 종료 분).
MinuteRange periodTime(int period) {
  if (period <= 4) {
    final s = 8 * 60 + 40 + (period - 1) * (kPeriodMinutes + kBreakMinutes);
    return (s, s + kPeriodMinutes);
  }
  final s = 13 * 60 + 30 + (period - 5) * (kPeriodMinutes + kBreakMinutes);
  return (s, s + kPeriodMinutes);
}

/// 점심시간.
MinuteRange lunchTime() => (12 * 60 + 30, 13 * 60 + 30);

/// 분 → 'HH:MM'.
String minutesToHhmm(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// 'HH:MM' → 분. 형식이 잘못되면 null.
int? hhmmToMinutes(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}
