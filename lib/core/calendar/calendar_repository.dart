/// 캘린더 데이터 단일 진입점.
///
/// 이 파일 이전에는 월간·주간·일간·오늘·검색·위젯이 각자 로컬 일정 + 반복 +
/// 학사일정 + 생일 + 공휴일 + 공유 + 스포츠를 따로 병합했고, 필터를 적용하는
/// 화면과 하지 않는 화면이 섞여 있었다(캘린더를 꺼도 검색·연간 뷰에는 계속
/// 보이는 버그). 이제 병합과 필터는 여기서만 한다.
///
/// **읽기 전용 계층이다.** 쓰기는 기존 경로(`eventsProvider` 등)를 그대로 쓴다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/calendar_theme.dart';
import '../../models/event_item.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/color_preset_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/holidays_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../providers/recurring_events_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shared_theme_events_provider.dart';
import '../../providers/sports_provider.dart';
import '../../providers/themes_provider.dart';
import '../../supabase/neis_service.dart' show NeisSchool, academicVisibleForGrade;
import '../theme/category_colors.dart';
import '../utils/date_utils.dart' as du;
import 'calendar_item.dart';
import 'period_times.dart';

// ─────────────────────────────────────────────────────────────────────
// 색 해석
// ─────────────────────────────────────────────────────────────────────

/// 캘린더 id → 색. 테마 목록에 없는 sentinel id는 고정색으로 떨어진다.
Color? _resolveColor(
  String? calendarId,
  List<CalendarTheme> themes,
  Brightness brightness,
) {
  if (calendarId == null) return null;
  for (final t in themes) {
    if (t.id == calendarId) return t.colorValue;
  }
  return switch (calendarId) {
    academicThemeId => CategoryColors.sky.of(brightness),
    birthdayThemeId => CategoryColors.rose.of(brightness),
    holidayThemeId => CategoryColors.coral.of(brightness),
    _ => null,
  };
}

// ─────────────────────────────────────────────────────────────────────
// 소스별 수집 (필터 적용 전)
// ─────────────────────────────────────────────────────────────────────

/// 필터를 적용하지 않은 날짜별 캘린더 항목.
///
/// 시간표(`schoolTimetable`)는 날짜별로 계산 비용이 있어 여기 포함하지 않는다.
/// [calendarDayProvider]가 하루 단위로 덧붙인다.
final rawCalendarItemsByDateProvider =
    Provider<Map<String, List<CalendarItem>>>((ref) {
  final events = ref.watch(eventsProvider);
  final recurring = ref.watch(recurringEventsByDateProvider);
  final shared = ref.watch(sharedThemeEventsByDateProvider);
  final sports = ref.watch(sportsEventsByDateProvider);
  final academic = ref.watch(academicScheduleProvider);
  final birthdays = ref.watch(birthdaysProvider);
  final themes = ref.watch(themesProvider);
  final brightness = ref.watch(calendarBrightnessProvider);
  final grade = NeisSchool.load()?.grade;

  final out = <String, List<CalendarItem>>{};
  void put(String dateKey, CalendarItem item) =>
      (out[dateKey] ??= <CalendarItem>[]).add(item);

  Color? colorOf(String? id) => _resolveColor(id, themes, brightness);

  // ── 1. 내 일정 (편집 가능) ──────────────────────────────────────
  events.forEach((dateKey, list) {
    if (dateKey.startsWith('__')) return;
    final DateTime day;
    try {
      day = du.fromDateKey(dateKey);
    } catch (_) {
      return;
    }
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      // 시간표 항목(tt)은 시간표 화면 전용 — 캘린더에는 시간표 소스로 따로 온다.
      if (e.isTimetable) continue;
      put(
        dateKey,
        CalendarItem.fromEvent(
          e,
          day: day,
          source: CalendarSource.local,
          id: 'local:$dateKey#$i',
          sourceId: dateKey,
          color: colorOf(e.themeIds.isEmpty ? null : e.themeIds.first),
          localIndex: i,
        ),
      );
    }
  });

  // ── 2. 반복 일정 전개분 (앵커는 위에서 이미 들어옴) ──────────────
  recurring.forEach((dateKey, list) {
    final DateTime day;
    try {
      day = du.fromDateKey(dateKey);
    } catch (_) {
      return;
    }
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      put(
        dateKey,
        CalendarItem.fromEvent(
          e,
          day: day,
          source: CalendarSource.local,
          id: 'recur:$dateKey#$i',
          sourceId: dateKey,
          color: colorOf(e.themeIds.isEmpty ? null : e.themeIds.first),
          metadata: const {'recurringOccurrence': true},
        ).copyWith(editable: false),
      );
    }
  });

  // ── 3. 구독 중인 공유 캘린더 (읽기 전용) ────────────────────────
  shared.forEach((dateKey, list) {
    final DateTime day;
    try {
      day = du.fromDateKey(dateKey);
    } catch (_) {
      return;
    }
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final themeId = e.themeIds.isEmpty ? null : e.themeIds.first;
      put(
        dateKey,
        CalendarItem.fromEvent(
          e,
          day: day,
          source: CalendarSource.shared,
          id: 'shared:$dateKey#$i',
          sourceId: themeId,
          color: colorOf(themeId),
        ),
      );
    }
  });

  // ── 4. 스포츠 구독 (읽기 전용) ──────────────────────────────────
  sports.forEach((dateKey, list) {
    final DateTime day;
    try {
      day = du.fromDateKey(dateKey);
    } catch (_) {
      return;
    }
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      put(
        dateKey,
        CalendarItem.fromEvent(
          e,
          day: day,
          source: CalendarSource.sports,
          id: 'sports:$dateKey#$i',
          sourceId: e.themeIds.isEmpty ? null : e.themeIds.first,
          color: e.sportColor == null ? null : Color(e.sportColor!),
          metadata: {
            if (e.sportEmoji != null) 'emoji': e.sportEmoji,
            if (e.sportLogo != null) 'logo': e.sportLogo,
          },
        ),
      );
    }
  });

  // ── 5. NEIS 학사일정 (읽기 전용) ────────────────────────────────
  // 다른 학년 항목 제외 + 같은 날 공휴일과 이름이 겹치면 공휴일로 통합.
  academic.forEach((dateKey, names) {
    final DateTime day;
    try {
      day = du.fromDateKey(dateKey);
    } catch (_) {
      return;
    }
    final visible = dedupAcademicWithHolidays(
        day, names.where((n) => academicVisibleForGrade(n, grade)));
    for (var i = 0; i < visible.length; i++) {
      put(
        dateKey,
        CalendarItem(
          id: 'academic:$dateKey#$i',
          title: visible[i],
          startAt: day,
          allDay: true,
          source: CalendarSource.schoolAcademic,
          calendarId: academicThemeId,
          color: colorOf(academicThemeId),
        ),
      );
    }
  });

  // ── 6. 생일 · 공휴일 ────────────────────────────────────────────
  // 생일은 연도 없이 월/일만 가지므로, 실제로 항목이 놓일 날짜 집합을
  // 다른 소스가 만들어 둔 날짜 + 올해/내년 범위로 한정한다. 전 구간을
  // 미리 펼치면 비용이 크므로 하루 조회에서 채우고, 여기서는 이미 알려진
  // 날짜에 대해서만 붙인다(월간 그리드는 [calendarRangeProvider]를 쓴다).
  final knownDates = out.keys.toList();
  for (final dateKey in knownDates) {
    final DateTime day;
    try {
      day = du.fromDateKey(dateKey);
    } catch (_) {
      continue;
    }
    for (final item in _birthdayAndHolidayItems(
        day, birthdays, colorOf(birthdayThemeId), colorOf(holidayThemeId))) {
      put(dateKey, item);
    }
  }

  for (final list in out.values) {
    list.sort(compareCalendarItems);
  }
  return out;
});

/// 그 날의 생일·공휴일 항목.
List<CalendarItem> _birthdayAndHolidayItems(
  DateTime day,
  List<Birthday> birthdays,
  Color? birthdayColor,
  Color? holidayColor,
) {
  final dateKey = du.toDateKey(day);
  final out = <CalendarItem>[];
  for (final b in birthdays) {
    if (b.month != day.month || b.day != day.day) continue;
    out.add(CalendarItem(
      id: 'birthday:${b.id}@$dateKey',
      title: b.name,
      startAt: day,
      allDay: true,
      source: CalendarSource.birthday,
      sourceId: b.id,
      calendarId: birthdayThemeId,
      color: birthdayColor,
      metadata: {if (b.year != null) 'birthYear': b.year},
    ));
  }
  for (final h in holidayEventsForDate(day)) {
    out.add(CalendarItem(
      id: 'holiday:$dateKey:${h.t}',
      title: h.t,
      startAt: day,
      allDay: true,
      source: CalendarSource.holiday,
      calendarId: holidayThemeId,
      color: holidayColor,
    ));
  }
  return out;
}

/// 그 날의 시간표 수업(읽기 전용).
///
/// NEIS 캐시는 이번 주만 보관하므로 이번 주 밖의 날짜는 직접 입력한 주간
/// 시간표(`timetableWeekly`)만 반영된다. 교시 → 시각 변환은
/// [periodTime] 한 곳만 쓴다.
List<CalendarItem> _timetableItemsForDate(
  DateTime day,
  NeisData neis,
  Map<int, Map<int, String>> weekly,
  Color? color,
) {
  final di = day.weekday - 1; // 0=월
  final today = DateTime.now();
  final thisMonday = today.subtract(Duration(days: today.weekday - 1));
  final inCachedWeek = !day.isBefore(
          DateTime(thisMonday.year, thisMonday.month, thisMonday.day)) &&
      day.isBefore(DateTime(
          thisMonday.year, thisMonday.month, thisMonday.day + 7));

  final maxPeriod = maxPeriodOf(neis.timetable);

  // 교시 → 과목. NEIS 캐시는 교시로 키가 잡혀 있다.
  final subjects = <int, String>{};
  // 수업 시간대가 아닌 칸에 직접 적어 넣은 항목(등교 전·방과 후) — 행 키가 곧 시각.
  final freeSlots = <int, String>{};

  if (inCachedWeek) {
    (neis.timetable[di] ?? const <int, String>{}).forEach((period, name) {
      if (name.trim().isNotEmpty) subjects[period] = name.trim();
    });
  }
  // 직접 입력한 주간 시간표가 NEIS보다 우선(사용자가 명시적으로 고친 값).
  // 이 맵은 교시가 아니라 격자 행 키로 저장돼 있으므로 변환이 필요하다.
  (weekly[di] ?? const <int, String>{}).forEach((rowHour, name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final period = periodForRowHour(rowHour, maxPeriod);
    if (period == null) {
      freeSlots[rowHour] = trimmed;
    } else {
      subjects[period] = trimmed;
    }
  });

  final dateKey = du.toDateKey(day);
  final base = DateTime(day.year, day.month, day.day);
  final out = <CalendarItem>[];
  subjects.forEach((period, name) {
    final (startMin, endMin) = periodTime(period);
    out.add(CalendarItem(
      id: 'timetable:$dateKey#$period',
      title: name,
      startAt: base.add(Duration(minutes: startMin)),
      endAt: base.add(Duration(minutes: endMin)),
      source: CalendarSource.schoolTimetable,
      calendarId: timetableCalendarId,
      color: color,
      metadata: {'period': period},
    ));
  });
  freeSlots.forEach((hour, name) {
    out.add(CalendarItem(
      id: 'timetable:$dateKey@$hour',
      title: name,
      startAt: base.add(Duration(hours: hour)),
      endAt: base.add(Duration(hours: hour + 1)),
      source: CalendarSource.schoolTimetable,
      calendarId: timetableCalendarId,
      color: color,
      metadata: {'freeSlotHour': hour},
    ));
  });
  out.sort(compareCalendarItems);
  return out;
}

/// 시간표 캘린더의 필터 id — 학사일정(`__academic__`)과 별도로 켜고 끈다.
const timetableCalendarId = '__timetable__';

/// 캘린더 색 해석에 쓰는 밝기 — 현재 컬러 프리셋에서 파생.
final calendarBrightnessProvider = Provider<Brightness>((ref) =>
    ref.watch(colorPresetProvider).dark ? Brightness.dark : Brightness.light);

// ─────────────────────────────────────────────────────────────────────
// 공개 조회 API
// ─────────────────────────────────────────────────────────────────────

/// 숨긴 캘린더를 걸러낸 날짜별 항목(시간표 제외).
///
/// **모든 캘린더 화면은 이것 또는 [calendarDayProvider]만 쓴다.**
/// 캘린더를 OFF 하면 여기서 한 번 걸러지므로 모든 화면에서 동시에 사라진다.
final calendarItemsByDateProvider =
    Provider<Map<String, List<CalendarItem>>>((ref) {
  final raw = ref.watch(rawCalendarItemsByDateProvider);
  final hidden = ref.watch(filterProvider);
  if (hidden.isEmpty) return raw;

  final out = <String, List<CalendarItem>>{};
  raw.forEach((dateKey, list) {
    final kept = list.where((i) => !_isHidden(i, hidden)).toList();
    if (kept.isNotEmpty) out[dateKey] = kept;
  });
  return out;
});

bool _isHidden(CalendarItem item, Set<String> hidden) =>
    item.calendarId != null && hidden.contains(item.calendarId);

/// 하루 전체 — 시간표 포함, 필터 적용, 정렬 완료.
final calendarDayProvider =
    Provider.family<List<CalendarItem>, String>((ref, dateKey) {
  final DateTime day;
  try {
    day = du.fromDateKey(dateKey);
  } catch (_) {
    return const [];
  }
  final hidden = ref.watch(filterProvider);
  final themes = ref.watch(themesProvider);
  final brightness = ref.watch(calendarBrightnessProvider);

  final base =
      List<CalendarItem>.from(ref.watch(calendarItemsByDateProvider)[dateKey] ??
          const <CalendarItem>[]);

  // 생일·공휴일은 다른 소스가 없는 날짜에도 떠야 한다 — 여기서 보강한다.
  if (!base.any((i) =>
      i.source == CalendarSource.birthday ||
      i.source == CalendarSource.holiday)) {
    base.addAll(_birthdayAndHolidayItems(
      day,
      ref.watch(birthdaysProvider),
      _resolveColor(birthdayThemeId, themes, brightness),
      _resolveColor(holidayThemeId, themes, brightness),
    ).where((i) => !_isHidden(i, hidden)));
  }

  if (ref.watch(settingsProvider).showTimetable &&
      !hidden.contains(timetableCalendarId)) {
    base.addAll(_timetableItemsForDate(
      day,
      ref.watch(neisCacheProvider),
      ref.watch(recurringProvider),
      _resolveColor(timetableCalendarId, themes, brightness),
    ));
  }

  base.sort(compareCalendarItems);
  return base;
});

/// 기간 조회 — [start]~[end] (양 끝 포함). 월간 그리드·검색·위젯용.
List<CalendarItem> calendarItemsInRange(
  WidgetRef ref,
  DateTime start,
  DateTime end, {
  bool includeTimetable = false,
}) {
  final byDate = ref.watch(calendarItemsByDateProvider);
  final out = <CalendarItem>[];
  var cursor = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!cursor.isAfter(last)) {
    final key = du.toDateKey(cursor);
    out.addAll(includeTimetable
        ? ref.watch(calendarDayProvider(key))
        : (byDate[key] ?? const <CalendarItem>[]));
    cursor = cursor.add(const Duration(days: 1));
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────
// 파생 조회
// ─────────────────────────────────────────────────────────────────────

/// 지금 진행 중인 항목(가장 먼저 시작한 것). 없으면 null.
final nowItemProvider = Provider<CalendarItem?>((ref) {
  final now = DateTime.now();
  final items = ref.watch(calendarDayProvider(du.toDateKey(now)));
  for (final i in items) {
    if (i.isOngoingAt(now)) return i;
  }
  return null;
});

/// 오늘 남은 일정(시작 시각이 지금 이후), 시간 순.
final upcomingTodayProvider = Provider<List<CalendarItem>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(calendarDayProvider(du.toDateKey(now)))
      .where((i) => !i.allDay && i.startAt.isAfter(now))
      .toList();
});

/// [candidate]와 시간이 겹치는 기존 항목들.
///
/// 로컬 일정만 보던 기존 충돌 검사를 학교 시간표·학사일정·공유까지 넓힌다
/// (스포츠·생일·공휴일은 정보성이라 제외 — [CalendarSourceX.blocksTime]).
List<CalendarItem> conflictsFor(
  WidgetRef ref,
  CalendarItem candidate, {
  String? ignoreId,
}) {
  if (candidate.allDay) return const [];
  return ref
      .watch(calendarDayProvider(candidate.dateKey))
      .where((i) =>
          i.id != ignoreId &&
          i.id != candidate.id &&
          i.source.blocksTime &&
          i.overlaps(candidate))
      .toList();
}

/// [EventItem]을 충돌 검사용 [CalendarItem]으로 감싼다(저장 전 후보).
CalendarItem candidateFromEvent(EventItem e, String dateKey) =>
    CalendarItem.fromEvent(
      e,
      day: du.fromDateKey(dateKey),
      source: CalendarSource.local,
      id: 'candidate',
      sourceId: dateKey,
    );
