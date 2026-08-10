import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../models/event_item.dart';
import '../../models/calendar_theme.dart';
import '../../models/record_template.dart';
import '../../supabase/neis_service.dart';
import '../../providers/view_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/themes_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/extras_provider.dart';
import '../../providers/day_widget_provider.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/template_ranges_provider.dart';
import '../../providers/record_templates_provider.dart';
import '../../providers/sports_provider.dart';
import '../../providers/shared_theme_events_provider.dart';
import '../../widgets/header_collapse.dart';
import '../../modals/day_action_sheet.dart';
import 'day_cell.dart';

/// 연속 보기 — 세로로 끝없이 이어지는 주(週) 단위 캘린더.
/// 주 행 높이에 맞춰 마그네틱 스냅(커스텀 ScrollPhysics)되며, 위로 스크롤한
/// 맨 위 주의 달이 상단 월 네비와 동기화된다.
class ContinuousWeekView extends ConsumerStatefulWidget {
  const ContinuousWeekView({super.key});

  @override
  ConsumerState<ContinuousWeekView> createState() =>
      _ContinuousWeekViewState();
}

class _ContinuousWeekViewState extends ConsumerState<ContinuousWeekView> {
  static const double _rowH = 96.0;
  static const int _centerIndex = 5000;

  late final ScrollController _ctrl;
  late final DateTime _anchorWeekStart; // _centerIndex 주의 시작일
  late final int _weekStartDow;
  bool _programmatic = false;

  @override
  void initState() {
    super.initState();
    final v = ref.read(viewProvider);
    _weekStartDow = ref.read(settingsProvider).weekStartDow;
    _anchorWeekStart =
        _weekStart(DateTime(v.viewYear, v.viewMonth, 1), _weekStartDow);
    _ctrl = ScrollController(initialScrollOffset: _centerIndex * _rowH);
    _ctrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  int _offsetInWeek(DateTime d, int wsd) => (d.weekday % 7 - wsd + 7) % 7;
  DateTime _weekStart(DateTime d, int wsd) =>
      DateTime(d.year, d.month, d.day - _offsetInWeek(d, wsd));

  DateTime _weekStartForIndex(int i) =>
      _anchorWeekStart.add(Duration(days: (i - _centerIndex) * 7));

  int _indexForDate(DateTime d) {
    final ws = _weekStart(d, _weekStartDow);
    final days = ws.difference(_anchorWeekStart).inDays;
    return _centerIndex + (days / 7).round();
  }

  // 맨 위 주의 "중간(목요일쯤)" 날짜 기준으로 달을 정해 네비와 동기화.
  void _onScroll() {
    if (_programmatic || !_ctrl.hasClients) return;
    final topIndex = (_ctrl.offset / _rowH).round();
    final mid = _weekStartForIndex(topIndex).add(const Duration(days: 3));
    final cur = ref.read(viewProvider);
    if (cur.viewYear != mid.year || cur.viewMonth != mid.month) {
      // 스크롤 위치 정착이 레이아웃/빌드 단계에서 발생하면, 여기서 viewProvider를
      // 바꾸는 순간 형제 위젯(AppHeader 등)의 RenderFlex가 레이아웃 도중 변형돼
      // "A RenderFlex was mutated…" 크래시. 그 단계면 다음 프레임으로 미룬다.
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(viewProvider.notifier).setYearMonth(mid.year, mid.month);
          }
        });
      } else {
        ref.read(viewProvider.notifier).setYearMonth(mid.year, mid.month);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;

    // 외부(월 네비/오늘 버튼)에서 달이 바뀌면 해당 달 1일이 든 주로 스냅.
    ref.listen<ViewState>(viewProvider, (prev, next) {
      if (prev == null) return;
      if (prev.viewYear == next.viewYear &&
          prev.viewMonth == next.viewMonth) {
        return;
      }
      if (!_ctrl.hasClients) return;
      final topIndex = (_ctrl.offset / _rowH).round();
      final curMid =
          _weekStartForIndex(topIndex).add(const Duration(days: 3));
      // 이미 그 달을 보고 있으면(=스크롤로 인한 변경) 다시 움직이지 않는다.
      if (curMid.year == next.viewYear && curMid.month == next.viewMonth) {
        return;
      }
      final target = _indexForDate(DateTime(next.viewYear, next.viewMonth, 1));
      _programmatic = true;
      _ctrl
          .animateTo(
            target * _rowH,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .whenComplete(() => _programmatic = false);
    });

    final headers = du.weekdayHeaders(_weekStartDow);

    return CollapseOnScroll(
      child: Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: sh.border, width: 0.5)),
      ),
      child: Column(
        children: [
          // 요일 헤더
          Container(
            color: sh.card2,
            child: Row(
              children: headers.asMap().entries.map((e) {
                final dow = (_weekStartDow + e.key) % 7;
                final isSun = dow == DateTime.sunday % 7;
                final isSat = dow == DateTime.saturday;
                return Expanded(
                  child: Container(
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: sh.border, width: 0.5),
                        bottom: BorderSide(color: sh.border, width: 0.5),
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSun
                            ? sh.danger
                            : isSat
                                ? sh.sat
                                : sh.inkSoft,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _ctrl,
              // 자유 스크롤 — 주 단위 강제 스냅 제거(스냅 위치 어긋남 해결).
              physics: const AlwaysScrollableScrollPhysics(),
              itemExtent: _rowH,
              itemBuilder: (context, index) {
                final ws = _weekStartForIndex(index);
                return _WeekRow(weekStart: ws);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _WeekRow extends ConsumerWidget {
  final DateTime weekStart;
  const _WeekRow({required this.weekStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final themes = ref.watch(themesProvider);
    final hiddenThemes = ref.watch(filterProvider);
    final circles = ref.watch(circlesProvider);
    final academic = ref.watch(academicScheduleProvider);
    final widgetValues = ref.watch(widgetValuesProvider);
    final dayTemplates = ref.watch(dayTemplatesProvider);
    final templateRanges = ref.watch(templateRangesProvider);
    final templatesById = ref.watch(recordTemplatesByIdProvider);
    final birthdays = ref.watch(birthdaysProvider);
    final sportsByDate = ref.watch(sportsEventsByDateProvider);
    final sharedByDate = ref.watch(sharedThemeEventsByDateProvider);
    final sh = context.sh;

    // 월 경계 구분선 색 — 부드러운 계단선은 아래 CustomPaint로 그린다.
    final edgeColor = sh.accent.withValues(alpha: 0.6);

    final weekDates = List.generate(
        7, (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i));
    final keys = weekDates.map(du.toDateKey).toList();

    bool visible(EventItem item) {
      if (hiddenThemes.isEmpty) return true;
      final ids = item.themeIds;
      if (ids.isEmpty) return !hiddenThemes.contains('__none__');
      return ids.every((id) => !hiddenThemes.contains(id));
    }

    // 내 학년 — 다른 학년 학사일정 숨김용.
    final grade = NeisSchool.load()?.grade;
    // 칸별 일정(필터 + 생일/학사 병합).
    final colEvents = <List<EventItem>>[
      for (int i = 0; i < 7; i++)
        <EventItem>[
          ...(events[keys[i]] ?? []).where(visible),
          if (!hiddenThemes.contains(birthdayThemeId))
            ...birthdays
                .where((b) =>
                    b.month == weekDates[i].month && b.day == weekDates[i].day)
                .map((b) =>
                    EventItem(t: b.name, th: birthdayThemeId, birthday: true)),
          if (!hiddenThemes.contains(academicThemeId))
            ...(academic[keys[i]] ?? const [])
                .where((n) => academicVisibleForGrade(n, grade))
                .map((n) =>
                    EventItem(t: n, th: academicThemeId, academic: true)),
          ...(sportsByDate[keys[i]] ?? const <EventItem>[])
              .where((e) => !hiddenThemes.contains(e.themeIds.first)),
          ...(sharedByDate[keys[i]] ?? const <EventItem>[]).where((e) =>
              e.themeIds.isNotEmpty &&
              !hiddenThemes.contains(e.themeIds.first)),
        ],
    ];

    // 같은 이름이 연속된 날에 있으면 하나의 긴 막대로 병합.
    final present = <String, List<bool>>{};
    final firstOf = <String, EventItem>{};
    for (int i = 0; i < 7; i++) {
      for (final e in colEvents[i]) {
        (present[e.t] ??= List.filled(7, false))[i] = true;
        firstOf.putIfAbsent(e.t, () => e);
      }
    }
    final spans = <_DaySpan>[];
    present.forEach((title, arr) {
      int i = 0;
      while (i < 7) {
        if (!arr[i]) { i++; continue; }
        int j = i;
        while (j + 1 < 7 && arr[j + 1]) {
          j++;
        }
        if (j > i) {
          spans.add(_DaySpan(
            title: title,
            start: i,
            end: j,
            color: _eventColor(firstOf[title]!, themes, sh),
          ));
        }
        i = j + 1;
      }
    });
    // 슬롯 배정(겹치는 막대는 다른 줄로).
    spans.sort((a, b) => a.start.compareTo(b.start));
    final slotEnds = <int>[];
    for (final s in spans) {
      int slot = 0;
      while (slot < slotEnds.length && slotEnds[slot] >= s.start) {
        slot++;
      }
      if (slot == slotEnds.length) {
        slotEnds.add(s.end);
      } else {
        slotEnds[slot] = s.end;
      }
      s.slot = slot;
    }
    const barH = 16.0;
    final reserve = slotEnds.length * barH;
    // 막대로 표시된 (칸,제목)은 셀 내부에서 중복 표시하지 않는다.
    final spanned = <String>{};
    for (final s in spans) {
      for (int c = s.start; c <= s.end; c++) {
        spanned.add('$c|${s.title}');
      }
    }

    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(7, (i) {
        final date = weekDates[i];
        final key = keys[i];
        final cellEvents = colEvents[i]
            .where((e) => !spanned.contains('$i|${e.t}'))
            .toList();

        final applicable = dayTemplates
            .where((t) => t.enabled && t.scope.appliesTo(key))
            .toList();
        final badges = recordBadgesForDate(
            key, templateRanges, widgetValues[key], templatesById);

        Widget cell = DayCell(
          date: date,
          viewMonth: date, // 연속 보기에선 흐리게 처리하지 않음
          events: cellEvents,
          themes: themes,
          sh: sh,
          showPast: true,
          hasCircle: circles.contains(key),
          applicableTemplates: applicable,
          dateWidgetValues: widgetValues[key] ?? {},
          recordBadges: badges,
          topReserve: reserve,
          // 탭: 그 주(주간 뷰)로 이동. 꾹누름: 위젯/일정 추가 메뉴.
          onTap: () => ref.read(viewProvider.notifier).openThreeDay(key),
          onLongPress: () => _handleDayTap(context, ref, date),
          onDoubleTap: () =>
              ref.read(circlesProvider.notifier).toggle(key),
        );

        // 매월 1일 셀에 월 라벨 오버레이 (달 경계 표시)
        if (date.day == 1) {
          cell = Stack(
            children: [
              Positioned.fill(child: cell),
              Positioned(
                top: 1,
                left: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: sh.accentBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('${date.month}월',
                      style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: sh.accentInk)),
                ),
              ),
            ],
          );
        }

        return Expanded(child: cell);
      }),
    );

    // 멀티데이 막대를 셀 위에 오버레이 + 월 경계 계단선.
    return CustomPaint(
      foregroundPainter:
          _MonthEdgePainter(weekStart: weekStart, color: edgeColor),
      child: LayoutBuilder(builder: (ctx, c) {
        final colW = c.maxWidth / 7;
        const top = 36.0; // 날짜 숫자 아래(=이벤트 영역 시작)
        return Stack(
          children: [
            row,
            ...spans.map((s) => Positioned(
                  top: top + s.slot * barH,
                  left: s.start * colW + 1.5,
                  width: (s.end - s.start + 1) * colW - 3,
                  height: barH - 2,
                  child: _SpanBar(span: s, sh: sh),
                )),
          ],
        );
      }),
    );
  }

  void _handleDayTap(BuildContext context, WidgetRef ref, DateTime date) {
    showDayActionSheet(context, du.toDateKey(date), date);
  }
}

/// 월 경계 계단선 — 직각 대신 둥근 코너로 부드럽게 잇는다.
/// 윗칸(7일 전)이 지난달인 셀(=day<=7) 상단에 수평선을,
/// 1일 셀(주의 첫 칸 제외) 왼쪽에 세로선을 두고, 꺾이는 지점을 곡선으로 연결.
class _MonthEdgePainter extends CustomPainter {
  final DateTime weekStart;
  final Color color;
  const _MonthEdgePainter({required this.weekStart, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final colW = size.width / 7;
    int minTop = -1, maxTop = -1, vertCol = -1;
    for (int i = 0; i < 7; i++) {
      final d = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      if (d.day <= 7) {
        if (minTop < 0) minTop = i;
        maxTop = i;
        if (d.day == 1 && i > 0) vertCol = i;
      }
    }
    if (minTop < 0) return; // 이 주엔 월 경계 없음

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    const y = 1.0;
    const r = 9.0; // 코너 반경
    final xRight = (maxTop + 1) * colW;
    final path = Path();

    if (vertCol > 0) {
      // 수평(오른쪽→코너) → 둥근 코너 → 수직(아래)
      final xc = vertCol * colW;
      path.moveTo(xRight, y);
      path.lineTo(xc + r, y);
      path.quadraticBezierTo(xc, y, xc, y + r);
      path.lineTo(xc, size.height);
    } else {
      // 세로 없이 수평만(연속 주)
      path.moveTo(minTop * colW, y);
      path.lineTo(xRight, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MonthEdgePainter old) =>
      old.weekStart != weekStart || old.color != color;
}

// 여러 날 이어지는 같은 이름 일정의 가로 막대.
class _DaySpan {
  final String title;
  final int start;
  final int end;
  final Color color;
  int slot = 0;
  _DaySpan({
    required this.title,
    required this.start,
    required this.end,
    required this.color,
  });
}

Color _eventColor(
    EventItem e, List<CalendarTheme> themes, SurlapColors sh) {
  if (e.birthday) return sh.birthdayColor;
  if (e.academic) return sh.academicColor;
  final ids = e.themeIds;
  if (ids.isNotEmpty) {
    try {
      return themes.firstWhere((t) => ids.contains(t.id)).colorValue;
    } catch (_) {}
  }
  return sh.accent;
}

class _SpanBar extends StatelessWidget {
  final _DaySpan span;
  final SurlapColors sh;
  const _SpanBar({required this.span, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: span.color.withValues(alpha: sh.dark ? 0.30 : 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border(left: BorderSide(color: span.color, width: 3)),
      ),
      child: Text(
        span.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: sh.dark ? sh.ink : span.color,
        ),
      ),
    );
  }
}
