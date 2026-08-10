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

/// 시간표 격자의 기본 마지막 교시. NEIS 데이터에 더 큰 교시가 있으면 늘어난다.
const int kDefaultMaxPeriod = 7;

/// NEIS 시간표 맵(`di → period → 과목`)에서 마지막 교시를 구한다.
int maxPeriodOf(Map<int, Map<int, String>> neisTimetable) {
  var mp = kDefaultMaxPeriod;
  for (final periodMap in neisTimetable.values) {
    for (final p in periodMap.keys) {
      if (p > mp) mp = p;
    }
  }
  return mp;
}

/// 교시 → 시간표 격자의 행 키.
///
/// `timetableWeekly`(직접 입력한 주간 시간표)는 **교시가 아니라 이 행 키**로
/// 저장된다. 1~4교시는 9~12, 점심을 건너뛰고 5교시부터는 14시부터다.
/// 이 값은 실제 수업 시각이 아니라 격자의 슬롯 번호일 뿐이므로,
/// 실제 시각이 필요하면 [periodTime]을 쓴다.
int rowHourForPeriod(int period) => period <= 4 ? 8 + period : 9 + period;

/// 행 키 → 교시. 수업 슬롯이 아니면(등교 전·방과 후 자유 시간대) null.
int? periodForRowHour(int rowHour, int maxPeriod) {
  final topPeriods = maxPeriod < 4 ? maxPeriod : 4;
  if (rowHour >= 9 && rowHour <= 8 + topPeriods) return rowHour - 8;
  if (maxPeriod >= 5 && rowHour >= 14 && rowHour <= 9 + maxPeriod) {
    return rowHour - 9;
  }
  return null;
}

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
