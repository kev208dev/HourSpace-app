import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../core/calendar/calendar_item.dart';
import '../core/calendar/calendar_repository.dart';
import '../core/calendar/period_times.dart';
import '../core/utils/date_utils.dart' as du;
import '../i18n/dates.dart' as i18nd;
import '../i18n/strings.dart' as i18n;
import '../models/todo_item.dart';
import '../providers/academic_schedule_provider.dart';
import '../providers/color_preset_provider.dart';
import '../providers/todos_provider.dart';
import '../providers/user_type_provider.dart';

/// Android/iOS 위젯이 함께 읽는 페이로드를 쓴다.
///
/// 계약(`surlap.widget.v2`)은 origin/main 의 네이티브 위젯이 기대하는 그대로다 —
/// `small`/`medium` 오브젝트, `appearance` 테마, 평탄화 키(ddayTitle,
/// mediumEvents, nextClass 등), 그리고 구버전 위젯을 위한 legacy 최상위 필드.
/// 네이티브를 건드리지 않고도 그대로 동작해야 하므로 키 이름은 바꾸지 않는다.
///
/// **데이터 출처만 다르다.** 예전에는 위젯이 로컬 일정 + 반복 + 학사 + 생일 +
/// 공유 + 스포츠를 자기가 다시 병합하고 필터를 자기가 적용했다. 그 결과 앱과
/// 위젯이 서로 다른 걸 보여줬고, 교시 시각도 앱은 08:40, 위젯은 09:00 이었다.
/// 이제 [calendarDayProvider] 하나만 읽는다.
class WidgetBridge {
  // 기존 iOS App Group / 위젯 ext 타깃 이름 유지(pbxproj 등록값과 일치 필수).
  static const appGroupId = 'group.com.kev208dev.Surlap';
  static const iosWidgetName = 'SurlapWidget';
  static const androidWidgetName = 'SurlapWidgetProvider';
  static const dataKey = 'hs_widget';

  static const schemaVersion = 2;
  static const _maxAllDay = 6;
  static const _maxTimed = 8;
  static const _maxTodos = 6;
  static const _mediumEventLimit = 3;

  // 위젯 교시 세그먼트 주얼톤 (iOS/Android 공용 팔레트).
  static const _jewelPalette = <String>[
    '#3A3A78',
    '#2F4E7A',
    '#1F5A5A',
    '#243A6E',
    '#3E2E72',
    '#5A2E62',
    '#5A2E4E',
  ];

  static bool _inited = false;

  static Future<void> _ensureInit() async {
    if (_inited) return;
    await HomeWidget.setAppGroupId(appGroupId);
    _inited = true;
  }

  static Future<void> sync(WidgetRef ref) async {
    await _ensureInit();
    try {
      final payload = _build(ref);
      await HomeWidget.saveWidgetData<String>(dataKey, jsonEncode(payload));
      await _saveFlatKeys(payload);
      await HomeWidget.updateWidget(
        iOSName: iosWidgetName,
        androidName: androidWidgetName,
      );
    } catch (_) {
      // 위젯 동기화 실패가 앱 동작을 막아서는 안 된다.
    }
  }

  static Future<void> _saveFlatKeys(Map<String, dynamic> payload) async {
    final medium = payload['medium'] as Map<String, dynamic>;
    final nextClass = medium['nextClass'] as Map<String, dynamic>;
    final small = payload['small'] as Map<String, dynamic>;

    // 기존 Now/Next 위젯이 그대로 읽는 키.
    await HomeWidget.saveWidgetData<String>(
        'today', payload['dateLabel'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(
        'schoolClass', payload['schoolClass'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(
        'periods', jsonEncode(payload['periods'] ?? const []));
    await HomeWidget.saveWidgetData<int>(
        'currentIndex', payload['currentIndex'] as int? ?? -1);
    await HomeWidget.saveWidgetData<double>(
        'progress', (payload['progress'] as num?)?.toDouble() ?? 0);
    await HomeWidget.saveWidgetData<int>(
        'minutesRemaining', payload['minutesRemaining'] as int? ?? 0);
    for (final key in const [
      'nowName',
      'nowStart',
      'nowEnd',
      'nextName',
      'nextStart',
    ]) {
      await HomeWidget.saveWidgetData<String>(
          key, payload[key] as String? ?? '');
    }

    // v2 평탄화 미러 — 네이티브 점진 마이그레이션·디버깅용.
    await HomeWidget.saveWidgetData<int>('widgetSchemaVersion', schemaVersion);
    await HomeWidget.saveWidgetData<String>(
        'theme', payload['theme'] as String? ?? 'light');
    await HomeWidget.saveWidgetData<String>('accent',
        (payload['appearance'] as Map<String, dynamic>)['accent'] as String);
    await HomeWidget.saveWidgetData<String>(
        'ddayTitle', small['title'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(
        'ddayLabel', small['label'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(
        'mediumEvents', jsonEncode(medium['events'] ?? const []));
    await HomeWidget.saveWidgetData<String>('nextClass', jsonEncode(nextClass));
  }

  static Map<String, dynamic> _build(WidgetRef ref) {
    final now = DateTime.now();
    final today = du.toDateKey(now);
    final nowHM = _hm(now.hour, now.minute);
    final preset = ref.read(colorPresetProvider);

    // 통합 계층 한 번만 읽는다 — 필터도 여기서 이미 적용됐다.
    final dayItems = ref.read(calendarDayProvider(today));

    // 시간표 수업은 아래 교시 슬롯으로 따로 다룬다.
    final entries = dayItems
        .where((i) => i.source != CalendarSource.schoolTimetable)
        .toList(growable: false);
    final classSlots = dayItems
        .where((i) => i.source == CalendarSource.schoolTimetable)
        .toList(growable: false);

    final allDay = entries.where((i) => i.allDay).toList(growable: false);
    final timed = entries.where((i) => !i.allDay).toList(growable: false);
    final nextTimedIndex =
        timed.indexWhere((i) => (i.startHhmm ?? '').compareTo(nowHM) >= 0);

    final todos =
        ref.read(todosProvider).where((t) => t.dateKey == today).toList()
          ..sort(_byPriority);

    final classState = _classState(now, classSlots);
    final nextClass =
        classSlots.where((slot) => slot.startAt.isAfter(now)).firstOrNull;

    final dday = _nearestAcademic(now, ref.read(academicScheduleProvider));
    final userType = ref.read(userTypeProvider);
    final classLabel =
        userType?.usesMeal == true ? i18n.tr('오늘 시간표') : i18n.tr('오늘');

    return {
      'schemaVersion': schemaVersion,
      'contract': 'surlap.widget.v2',
      'generatedAt': now.toUtc().toIso8601String(),
      'date': today,
      'lang': i18n.currentLang.name,
      'theme': preset.dark ? 'dark' : 'light',
      'appearance': {
        'dark': preset.dark,
        'accent': _hexColor(preset.accent),
        'background': _hexColor(preset.app),
        'surface': _hexColor(preset.card),
        'text': _hexColor(preset.ink),
        'textSoft': _hexColor(preset.inkSoft),
        'hairline': _hexColor(preset.hairline, includeAlpha: true),
      },
      'small': _smallPayload(dday),
      'medium': {
        'date': today,
        'dateLabel': _label(now),
        'events':
            entries.take(_mediumEventLimit).map(_eventPayload).toList(),
        'eventCount': entries.length,
        'nextClass': _nextClassPayload(nextClass),
      },

      // Legacy hs_widget 계약. 네이티브가 전부 migrate 되기 전에는 지우지 않는다.
      'dateLabel': _label(now),
      'schoolClass': classLabel,
      'weekday': now.weekday,
      'nowHM': nowHM,
      'nextIndex': nextTimedIndex,
      'todoCount': todos.length,
      'todoDone': todos.where((t) => t.done).length,
      'eventCount': entries.length,
      'allDay': allDay
          .take(_maxAllDay)
          .map((i) => {
                'title': i.title,
                'color': _itemColor(i),
                'emoji': _emoji(i),
              })
          .toList(),
      'timed': timed
          .take(_maxTimed)
          .map((i) => {
                'title': i.title,
                'time': i.startHhmm ?? '',
                'end': i.endHhmm ?? '',
                'color': _itemColor(i),
                'emoji': _emoji(i),
                'sport': i.source == CalendarSource.sports,
              })
          .toList(),
      'todos': todos
          .take(_maxTodos)
          .map((t) =>
              {'title': t.title, 'done': t.done, 'priority': t.priority})
          .toList(),
      'periods': [
        for (var i = 0; i < classSlots.length; i++)
          _legacyPeriodJson(classSlots[i], i),
      ],
      'currentIndex': classState.currentIndex,
      'progress': classState.progress,
      'minutesRemaining': classState.minutesRemaining,
      'nowName': classState.current?.title ?? '',
      'nowStart': classState.current?.startHhmm ?? '',
      'nowEnd': classState.current?.endHhmm ?? '',
      'nextName': classState.next?.title ?? '',
      'nextStart': classState.next?.startHhmm ?? '',
      'dark': preset.dark,
    };
  }

  static Map<String, dynamic> _smallPayload(_AcademicDday? dday) => {
        'kind': 'academicDday',
        'available': dday != null,
        'title': dday?.title ?? '',
        'date': dday?.dateKey ?? '',
        'daysAway': dday?.daysAway ?? -1,
        'label': dday == null
            ? ''
            : dday.daysAway == 0
                ? 'D-DAY'
                : 'D-${dday.daysAway}',
      };

  static Map<String, dynamic> _eventPayload(CalendarItem i) => {
        'id': i.id,
        'title': i.title,
        'kind': _kind(i.source),
        'allDay': i.allDay,
        'start': i.startHhmm ?? '',
        'end': i.endHhmm ?? '',
        'timeLabel': i.allDay ? i18n.tr('종일') : (i.startHhmm ?? ''),
        'color': _itemColor(i),
      };

  static Map<String, dynamic> _nextClassPayload(CalendarItem? slot) => {
        'available': slot != null,
        'title': slot?.title ?? '',
        'period': (slot?.metadata['period'] as int?) ?? -1,
        'start': slot?.startHhmm ?? '',
        'end': slot?.endHhmm ?? '',
        // 통합 계층이 NEIS·직접 입력을 이미 합쳐 주므로 출처는 한 값으로 둔다.
        'source': slot == null ? '' : 'timetable',
      };

  static Map<String, dynamic> _legacyPeriodJson(CalendarItem slot, int index) {
    final period = (slot.metadata['period'] as int?) ?? (index + 1);
    return {
      'name': slot.title,
      'start': slot.startHhmm ?? '',
      'end': slot.endHhmm ?? '',
      'color': _jewelPalette[(period - 1).abs() % _jewelPalette.length],
    };
  }

  static _AcademicDday? _nearestAcademic(
    DateTime now,
    Map<String, List<String>> schedule,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    _AcademicDday? nearest;
    schedule.forEach((dateKey, names) {
      if (names.isEmpty) return;
      final date = DateTime.tryParse(dateKey);
      if (date == null) return;
      final daysAway =
          DateTime(date.year, date.month, date.day).difference(today).inDays;
      if (daysAway < 0) return;
      for (final rawName in names) {
        final name = rawName.trim();
        if (name.isEmpty) continue;
        final candidate = _AcademicDday(dateKey, name, daysAway);
        if (nearest == null ||
            candidate.daysAway < nearest!.daysAway ||
            (candidate.daysAway == nearest!.daysAway &&
                candidate.title.compareTo(nearest!.title) < 0)) {
          nearest = candidate;
        }
      }
    });
    return nearest;
  }

  static _ClassState _classState(DateTime now, List<CalendarItem> slots) {
    var currentIndex = -1;
    CalendarItem? current;
    CalendarItem? next;
    var progress = 0.0;
    var minutesRemaining = 0;
    for (var index = 0; index < slots.length; index++) {
      final slot = slots[index];
      final end =
          slot.endAt ?? slot.startAt.add(const Duration(minutes: kPeriodMinutes));
      if (slot.isOngoingAt(now)) {
        currentIndex = index;
        current = slot;
        final total = end.difference(slot.startAt).inSeconds;
        progress = total == 0
            ? 0
            : (now.difference(slot.startAt).inSeconds / total).clamp(0, 1);
        minutesRemaining = end.difference(now).inMinutes;
      } else if (next == null && slot.startAt.isAfter(now)) {
        next = slot;
      }
    }
    return _ClassState(
      currentIndex: currentIndex,
      current: current,
      next: next,
      progress: progress,
      minutesRemaining: minutesRemaining,
    );
  }

  static String _kind(CalendarSource source) => switch (source) {
        CalendarSource.local => 'event',
        CalendarSource.shared => 'shared',
        CalendarSource.sports => 'sport',
        CalendarSource.birthday => 'birthday',
        CalendarSource.schoolAcademic => 'academic',
        CalendarSource.schoolTimetable => 'class',
        CalendarSource.holiday => 'holiday',
      };

  /// 색은 통합 계층이 이미 해석해 둔 값을 쓴다(테마 색·스포츠 구독 색 포함).
  static String _itemColor(CalendarItem i) =>
      i.color == null ? '#8B7FF5' : _hex(i.color!.toARGB32());

  static String _emoji(CalendarItem i) => switch (i.source) {
        CalendarSource.sports => (i.metadata['emoji'] as String?) ?? '🏆',
        CalendarSource.birthday => '🎂',
        CalendarSource.schoolAcademic => '🎓',
        CalendarSource.schoolTimetable => '🏫',
        CalendarSource.holiday => '🎌',
        _ => '',
      };

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static String _hexColor(Color color, {bool includeAlpha = false}) {
    final value = color.toARGB32();
    final rgb = (value & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    if (!includeAlpha) return '#${rgb.toUpperCase()}';
    final alpha = ((value >> 24) & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#${alpha.toUpperCase()}${rgb.toUpperCase()}';
  }

  static String _hm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static int _byPriority(TodoItem a, TodoItem b) {
    int rank(TodoItem t) => t.hasPriority ? t.priority : 99;
    final priority = rank(a).compareTo(rank(b));
    return priority != 0
        ? priority
        : (a.createdAt ?? '').compareTo(b.createdAt ?? '');
  }

  static String _label(DateTime date) =>
      '${i18nd.monthDay(date)} (${i18nd.weekdayShort(date.weekday)})';
}

class _AcademicDday {
  final String dateKey;
  final String title;
  final int daysAway;

  const _AcademicDday(this.dateKey, this.title, this.daysAway);
}

class _ClassState {
  final int currentIndex;
  final CalendarItem? current;
  final CalendarItem? next;
  final double progress;
  final int minutesRemaining;

  const _ClassState({
    required this.currentIndex,
    required this.current,
    required this.next,
    required this.progress,
    required this.minutesRemaining,
  });
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
