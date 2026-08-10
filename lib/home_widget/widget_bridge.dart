import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../core/calendar/calendar_item.dart';
import '../core/calendar/calendar_repository.dart';
import '../core/calendar/period_times.dart';
import '../core/utils/date_utils.dart' as du;
import '../i18n/strings.dart' as i18n;
import '../i18n/dates.dart' as i18nd;
import '../models/todo_item.dart';
import '../providers/todos_provider.dart';
import '../providers/user_type_provider.dart';

class WidgetBridge {
  // 기존 iOS App Group / 위젯 ext 타깃 이름 유지(pbxproj 등록값과 일치 필수).
  // 새 이름으로 바꾸려면 Xcode 에서 타깃·entitlements 도 함께 갱신해야 위젯이 살아남.
  static const appGroupId = 'group.com.kev208dev.Surlap';
  static const iosWidgetName = 'SurlapWidget';
  static const androidWidgetName = 'SurlapWidgetProvider';
  static const dataKey = 'hs_widget';

  static const _maxAllDay = 6;
  static const _maxTimed = 8;
  static const _maxTodos = 6;

  // 위젯 교시 세그먼트 주얼톤 (없을 때 폴백 — iOS/Android 양쪽 동일 팔레트).
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
      // Surlap Now/Next 카드를 위한 평탄화 키들도 함께 저장 — 위젯 네이티브가
      // 한 JSON 파싱 없이도 빠르게 읽을 수 있게(Android Glance/iOS UserDefaults 공용).
      await _saveFlatKeys(payload);
      await HomeWidget.updateWidget(
        iOSName: iosWidgetName,
        androidName: androidWidgetName,
      );
    } catch (_) {
      // 위젯 동기화 실패는 앱 동작에 영향 없도록 무시.
    }
  }

  static Future<void> _saveFlatKeys(Map<String, dynamic> p) async {
    await HomeWidget.saveWidgetData<String>('today', p['dateLabel'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>('schoolClass', p['schoolClass'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>('periods', jsonEncode(p['periods'] ?? const []));
    await HomeWidget.saveWidgetData<int>('currentIndex', (p['currentIndex'] as int?) ?? -1);
    await HomeWidget.saveWidgetData<double>('progress', (p['progress'] as num?)?.toDouble() ?? 0.0);
    await HomeWidget.saveWidgetData<int>('minutesRemaining', (p['minutesRemaining'] as int?) ?? 0);
    await HomeWidget.saveWidgetData<String>('nowName', p['nowName'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>('nowStart', p['nowStart'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>('nowEnd', p['nowEnd'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>('nextName', p['nextName'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>('nextStart', p['nextStart'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>('accent', '#A98BFF');
    await HomeWidget.saveWidgetData<String>('theme', p['dark'] == true ? 'dark' : 'light');
  }

  static Map<String, dynamic> _build(WidgetRef ref) {
    final now = DateTime.now();
    final today = du.todayKey();
    final nowHM = _hm(now.hour, now.minute);

    // 앱 화면과 완전히 같은 통합 계층을 쓴다. 예전에는 위젯이 소스를 따로
    // 병합하고 교시 시각도 자체 규칙(1교시 09:00)을 써서, 같은 수업이 앱에선
    // 08:40, 위젯에선 09:00 으로 보이는 불일치가 있었다.
    final dayItems = ref.read(calendarDayProvider(today));

    final allDay =
        dayItems.where((i) => i.allDay).toList(growable: false);
    final timed = dayItems
        .where((i) =>
            !i.allDay && i.source != CalendarSource.schoolTimetable)
        .toList(growable: false);

    int nextIndex = -1;
    for (var i = 0; i < timed.length; i++) {
      if ((timed[i].startHhmm ?? '').compareTo(nowHM) >= 0) {
        nextIndex = i;
        break;
      }
    }

    final todos = ref
        .read(todosProvider)
        .where((t) => t.dateKey == today)
        .toList()
      ..sort(_byPriority);

    // ── 오늘 교시 추출(Now/Next 카드) ─────────────────────────────
    final classes = dayItems
        .where((i) => i.source == CalendarSource.schoolTimetable)
        .toList(growable: false);
    final periods = <Map<String, dynamic>>[];
    int currentPeriod = -1;
    int minutesRemaining = 0;
    double progress = 0;
    String nowName = '', nowStart = '', nowEnd = '';
    String nextName = '', nextStart = '';

    for (var idx = 0; idx < classes.length; idx++) {
      final c = classes[idx];
      final start = c.startAt;
      final end = c.endAt ?? start.add(const Duration(minutes: kPeriodMinutes));
      periods.add({
        'name': c.title,
        'start': c.startHhmm ?? '',
        'end': c.endHhmm ?? '',
        'color': _jewelPalette[idx % _jewelPalette.length],
      });
      if (c.isOngoingAt(now) && currentPeriod < 0) {
        currentPeriod = periods.length - 1;
        nowName = c.title;
        nowStart = c.startHhmm ?? '';
        nowEnd = c.endHhmm ?? '';
        minutesRemaining = end.difference(now).inMinutes;
        final totalSec = end.difference(start).inSeconds;
        progress = totalSec == 0
            ? 0
            : (now.difference(start).inSeconds / totalSec).clamp(0.0, 1.0);
      } else if (nextName.isEmpty &&
          (currentPeriod >= 0 || now.isBefore(start))) {
        nextName = c.title;
        nextStart = c.startHhmm ?? '';
      }
    }
    // 진행 중 교시가 없으면 nowName 은 비워두되, 가장 가까운 미래 = next.
    // next 도 비어 있으면 마지막 교시까지 끝났다는 뜻.

    final userType = ref.read(userTypeProvider);
    final classLabel =
        userType?.usesMeal == true ? i18n.tr('오늘 시간표') : i18n.tr('오늘');

    return {
      'date': today,
      'lang': i18n.currentLang.name,
      'dateLabel': _label(now),
      'schoolClass': classLabel,
      'weekday': now.weekday,
      'nowHM': nowHM,
      'nextIndex': nextIndex,
      'todoCount': todos.length,
      'todoDone': todos.where((t) => t.done).length,
      'eventCount': allDay.length + timed.length,
      'allDay': allDay
          .take(_maxAllDay)
          .map((i) => {
                'title': i.title,
                'color': _color(i),
                'emoji': _emoji(i),
              })
          .toList(),
      'timed': timed
          .take(_maxTimed)
          .map((i) => {
                'title': i.title,
                'time': i.startHhmm ?? '',
                'end': i.endHhmm ?? '',
                'color': _color(i),
                'emoji': _emoji(i),
                'sport': i.source == CalendarSource.sports,
              })
          .toList(),
      'todos': todos
          .take(_maxTodos)
          .map((t) =>
              {'title': t.title, 'done': t.done, 'priority': t.priority})
          .toList(),
      // ── Surlap Now/Next 카드 ─────────────────────────────────
      'periods': periods,
      'currentIndex': currentPeriod,
      'progress': progress,
      'minutesRemaining': minutesRemaining,
      'nowName': nowName,
      'nowStart': nowStart,
      'nowEnd': nowEnd,
      'nextName': nextName,
      'nextStart': nextStart,
      'dark': false,
    };
  }

  /// 색은 통합 계층이 이미 해석해 둔 값을 쓴다(테마 색·스포츠 구독 색 포함).
  static String _color(CalendarItem i) =>
      i.color == null ? '#8B7FF5' : _hex(i.color!.toARGB32());

  static String _emoji(CalendarItem i) => switch (i.source) {
        CalendarSource.sports =>
          (i.metadata['emoji'] as String?) ?? '🏆',
        CalendarSource.birthday => '🎂',
        CalendarSource.schoolAcademic => '📚',
        CalendarSource.schoolTimetable => '🏫',
        CalendarSource.holiday => '🎌',
        _ => '',
      };

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String _hm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  static int _byPriority(TodoItem a, TodoItem b) {
    int rank(TodoItem t) => t.hasPriority ? t.priority : 99;
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
  }

  static String _label(DateTime d) =>
      '${i18nd.monthDay(d)} (${i18nd.weekdayShort(d.weekday)})';
}
