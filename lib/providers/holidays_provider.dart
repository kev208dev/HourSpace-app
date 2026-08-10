import '../core/constants/korean_holidays.dart';
import '../models/calendar_theme.dart';
import '../models/event_item.dart';

/// 공휴일 이벤트는 기본 테마 'holidays'(빨강)에 붙인다 — 색·필터칩이 자동 적용.
const holidayThemeId = 'holidays';
const holidayCalendarTheme = CalendarTheme(
  id: holidayThemeId,
  name: '공휴일',
  color: '#d33333',
);

bool isSystemCalendarTheme(String id) => id == holidayThemeId;

List<CalendarTheme> userCalendarThemes(Iterable<CalendarTheme> themes) =>
    themes.where((theme) => !isSystemCalendarTheme(theme.id)).toList();

/// Restores the fixed system calendar and drops any editable legacy copy.
List<CalendarTheme> withSystemCalendarThemes(Iterable<CalendarTheme> themes) =>
    [holidayCalendarTheme, ...userCalendarThemes(themes)];

/// 그 날 공휴일 이름들(중복 제거용).
Set<String> holidayNamesForDate(DateTime d) {
  final n = holidayName(d);
  return n == null ? const {} : {n};
}

/// 그 날 공휴일을 종일 이벤트로(없으면 빈 리스트).
List<EventItem> holidayEventsForDate(DateTime d) {
  final n = holidayName(d);
  if (n == null) return const [];
  return [EventItem(t: n, th: holidayThemeId)];
}

/// 학사일정 이름 목록에서 같은 날 공휴일과 이름이 겹치는 항목 제거(공휴일로 통합).
/// 예: 학사일정 '어린이날' + 공휴일 '어린이날' → 공휴일만 남김.
List<String> dedupAcademicWithHolidays(DateTime d, Iterable<String> academic) {
  final hol = holidayNamesForDate(d);
  if (hol.isEmpty) return academic.toList();
  return academic.where((n) => !hol.contains(n.trim())).toList();
}
