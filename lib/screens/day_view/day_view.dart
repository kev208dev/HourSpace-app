import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../providers/events_provider.dart';
import '../../providers/themes_provider.dart';
import '../../providers/view_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../providers/settings_provider.dart';
import '../../supabase/neis_service.dart'
    show NeisSchool, academicVisibleForGrade;
import '../timetable_view/timetable_view.dart'
    show timetableSubjectsForDate, getDisplaySubjectName;
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../providers/holidays_provider.dart';
import '../../widgets/header_collapse.dart';
import '../../providers/todos_provider.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/sports_provider.dart';
import '../../providers/shared_theme_events_provider.dart';
import '../../providers/recurring_events_provider.dart';
import '../../core/utils/todo_style.dart';
import '../../models/event_item.dart';
import '../../models/todo_item.dart';
import '../../models/calendar_theme.dart';
import '../../modals/add_edit_event_modal.dart';
import '../../modals/add_todo_modal.dart';
import '../../modals/event_detail_sheet.dart';
import '../../widgets/app_toast.dart';

/// 일별 뷰 — 주간 뷰의 하루를 확대한 형태.
/// 왼쪽에 시간대(0~23시) 축을 두고, 시간 일정은 해당 시각에 블록으로 배치한다.
class DayView extends ConsumerStatefulWidget {
  final String dateKey;
  const DayView({super.key, required this.dateKey});

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  static const _timeColW = 44.0;
  static const _baseRowH = 48.0;
  double _zoom = 1.0; // 확대/축소 — 두 손가락 핀치(주간 뷰와 동일).
  double _zoomStart = 1.0;
  double get _rowH => _baseRowH * _zoom;

  late final ScrollController _scroll;
  Timer? _tick;
  DateTime _now = DateTime.now();

  String _shiftDay(String key, int delta) =>
      du.toDateKey(du.fromDateKey(key).add(Duration(days: delta)));

  // 좌우 스와이프 → 다음/전날 이동. (왼쪽으로 = 다음날, 오른쪽으로 = 전날)
  void _onHorizontalDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 200) return; // 약한 스와이프 무시
    final delta = v < 0 ? 1 : -1;
    ref
        .read(viewProvider.notifier)
        .openDay(_shiftDay(widget.dateKey, delta));
  }

  @override
  void initState() {
    super.initState();
    final date = du.fromDateKey(widget.dateKey);
    final now = DateTime.now();
    // 오늘이면 현재 시각 근처, 아니면 오전 7시쯤부터 보이게.
    final startHour = du.isSameDay(date, now)
        ? (now.hour - 1).clamp(0, 20)
        : 7;
    _scroll = ScrollController(initialScrollOffset: startHour * _rowH);
    // 현재 시각 라인이 오늘 보이면 1분마다 갱신.
    if (du.isSameDay(date, now)) {
      _tick = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final events = ref.watch(eventsProvider);
    final themes = ref.watch(themesProvider);
    final date = du.fromDateKey(widget.dateKey);
    final items = events[widget.dateKey] ?? [];
    final now = _now;
    final isToday = du.isSameDay(date, now);

    final filter = ref.watch(filterProvider);
    final sharedToday =
        ref.watch(sharedThemeEventsByDateProvider)[widget.dateKey] ??
            const <EventItem>[];
    bool sharedVisible(EventItem e) =>
        e.themeIds.isNotEmpty && !filter.contains(e.themeIds.first);
    final allDay = [
      ...items.where((e) => !e.hasTime && !e.isTimetable),
      // 반복 일정 (종일)
      ...(ref.watch(recurringEventsByDateProvider)[widget.dateKey] ?? const [])
          .where((e) => !e.hasTime),
      // 구독 공유 테마(종일, 읽기 전용)
      ...sharedToday.where((e) => !e.hasTime && sharedVisible(e)),
      // 생일(별도 카테고리)
      if (!filter.contains(birthdayThemeId))
        ...ref
            .watch(birthdaysProvider)
            .where((b) => b.month == date.month && b.day == date.day)
            .map((b) =>
                EventItem(t: b.name, th: birthdayThemeId, birthday: true)),
      // 공휴일(빨강 'holidays' 테마).
      if (!filter.contains(holidayThemeId)) ...holidayEventsForDate(date),
      // NEIS 학사일정(읽기 전용) — 다른 학년 항목 숨김 + 공휴일과 중복 제거.
      if (!filter.contains(academicThemeId))
        ...dedupAcademicWithHolidays(
                date,
                (ref.watch(academicScheduleProvider)[widget.dateKey] ?? const [])
                    .where((n) =>
                        academicVisibleForGrade(n, NeisSchool.load()?.grade)))
            .map((n) =>
                EventItem(t: n, th: academicThemeId, academic: true)),
    ];
    final sportsToday =
        ref.watch(sportsEventsByDateProvider)[widget.dateKey] ?? const [];
    final recurringToday =
        ref.watch(recurringEventsByDateProvider)[widget.dateKey] ?? const [];
    final timed = [
      ...items.where((e) => e.hasTime && !e.isTimetable),
      ...recurringToday.where((e) => e.hasTime),
      ...sportsToday.where((e) => !filter.contains(e.themeIds.first)),
      // 구독 공유 테마(시간 있음, 읽기 전용)
      ...sharedToday.where((e) => e.hasTime && sharedVisible(e)),
    ]..sort((a, b) => (a.tm ?? '').compareTo(b.tm ?? ''));
    final dayTodos = ref
        .watch(todosProvider)
        .where((t) => t.dateKey == widget.dateKey)
        .toList()
      ..sort((a, b) {
        int rank(TodoItem t) => t.hasPriority ? t.priority : 99;
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : (a.createdAt ?? '').compareTo(b.createdAt ?? '');
      });
    // 이 날짜의 요일에 해당하는 반복 일정(시간표 탭에서 작성).
    // NEIS·템플릿·주간반복을 합친 그 날 시간표 수업(읽기전용). 토글로 on/off.
    ref.watch(recurringProvider);
    ref.watch(neisCacheProvider);
    final showTt = ref.watch(settingsProvider).showTimetable;
    final recurringForDay =
        showTt ? timetableSubjectsForDate(ref, date) : const <int, String>{};
    // 시간/종일/할일/반복 전부 없으면 빈 날 → 마스코트 힌트.
    final dayEmpty = timed.isEmpty &&
        recurringForDay.isEmpty &&
        allDay.isEmpty &&
        dayTodos.isEmpty;

    return GestureDetector(
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: CollapseOnScroll(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1행: 디스플레이 타이틀 + 스케줄 토글 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xs),
          child: Row(
            children: [
              const SizedBox(width: 2),
              Text(
                i18nd.monthDay(date),
                style: AppType.title.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: sh.ink),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _dowName(date.weekday),
                  style: AppType.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isToday ? sh.accent : sh.inkSoft),
                ),
              ),
              const Spacer(),
              // 스케줄 표시 토글(아이콘만).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setShowTimetable(!showTt),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        showTt ? sh.accent.withValues(alpha: 0.12) : sh.card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: showTt
                            ? sh.accent.withValues(alpha: 0.4)
                            : sh.ink.withValues(alpha: 0.08)),
                  ),
                  child: Icon(
                      showTt
                          ? Icons.event_available_rounded
                          : Icons.event_busy_rounded,
                      size: 20,
                      color: showTt ? sh.accent : sh.inkSoft),
                ),
              ),
            ],
          ),
        ),
        // ── 2행: 글래스 세그먼트 (연/월/주/일) ──
        // 종일 일정
        if (allDay.isNotEmpty) _AllDayBar(items: allDay, themes: themes, sh: sh),
        // 할 일
        if (dayTodos.isNotEmpty)
          _TodoBar(
            todos: dayTodos,
            sh: sh,
            onToggle: (id) {
              final willComplete = ref
                  .read(todosProvider)
                  .any((t) => t.id == id && t.status == 1);
              ref.read(todosProvider.notifier).toggleDone(id);
              if (willComplete) {
                AppToast.success(context, tr('좋아요! 하나 끝냈어요'));
              }
            },
            onTapTodo: (t) => showAddTodoModal(context, edit: t),
          ),
        // 시간 축 + 하루 타임라인 — 두 손가락 핀치로 확대/축소.
        Expanded(
          child: GestureDetector(
            onScaleStart: (_) => _zoomStart = _zoom,
            onScaleUpdate: (d) {
              if (d.pointerCount < 2) return;
              final z = (_zoomStart * d.scale).clamp(0.6, 2.0);
              if (z != _zoom) setState(() => _zoom = z);
            },
            child: LayoutBuilder(builder: (context, constraints) {
            final dayColW = constraints.maxWidth - _timeColW;
            final timeline = SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 110),
              child: SizedBox(
                height: _rowH * 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 시간 레이블 컬럼
                    SizedBox(
                      width: _timeColW,
                      child: Column(
                        children: List.generate(24, (h) {
                          return SizedBox(
                            height: _rowH,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 6, top: 2),
                                child: Text(
                                  h == 0 ? '' : '$h:00',
                                  style: TextStyle(
                                      fontSize: 10, color: sh.inkFaint),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // 하루 컬럼 — Stack은 좌측 시각 칩이 시간 컬럼으로 넘어가도록 clipBehavior.none.
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 오늘 컬럼 옅은 accent 틴트(B2).
                          if (isToday)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  color: sh.accent
                                      .withValues(alpha: sh.dark ? 0.06 : 0.04),
                                ),
                              ),
                            ),
                          // 시간 그리드 — 라인은 8% 투명(블록이 주인공).
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                    color: sh.ink.withValues(alpha: 0.08),
                                    width: 0.5),
                              ),
                            ),
                            child: Column(
                              children: List.generate(
                                24,
                                (h) => Container(
                                  height: _rowH,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                          color: sh.ink
                                              .withValues(alpha: 0.08),
                                          width: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 반복 일정(시간표 탭에서 작성) — 해당 요일에만 표시
                          ..._recurringBlocks(recurringForDay, dayColW, sh),
                          // 시간 일정 블록
                          ..._eventBlocks(timed, dayColW, themes, sh, events),
                          // 현재 시각 선 + 좌측 시각 칩(1분 단위 갱신)
                          if (isToday)
                            _NowLine(
                                hour: now.hour,
                                minute: now.minute,
                                rowH: _rowH,
                                timeColW: _timeColW,
                                sh: sh),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (!dayEmpty) return timeline;
            // 빈 날 — 타임라인 위에 마스코트 힌트(탭 통과).
            return Stack(
              children: [
                timeline,
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available_rounded, size: 30),
                            const SizedBox(height: 10),
                            Text(tr('이 날은 아직 비어있어요'),
                                style: AppType.body.copyWith(
                                    color: sh.inkFaint,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(tr('탭해서 일정을 추가해보세요'),
                                style: AppType.label
                                    .copyWith(color: sh.inkFaint)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
          ),
        ),
      ],
      ),
      ),
    );
  }

  // 시간표 수업 블록(읽기전용) — 주간 뷰와 같은 깔끔한 카드.
  List<Widget> _recurringBlocks(
      Map<int, String> byHour, double colW, SurlapColors sh) {
    final blocks = <Widget>[];
    byHour.forEach((hour, title) {
      final name = getDisplaySubjectName(title);
      blocks.add(Positioned(
        top: hour * _rowH + 2,
        left: 4,
        right: 6,
        height: _rowH - 4,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: sh.accent.withValues(alpha: sh.dark ? 0.20 : 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sh.accent.withValues(alpha: 0.25)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sh.dark ? sh.ink : sh.accentInk),
            ),
          ),
        ),
      ));
    });
    return blocks;
  }

  List<Widget> _eventBlocks(
    List<EventItem> timed,
    double colW,
    List<CalendarTheme> themes,
    SurlapColors sh,
    Map<String, List<EventItem>> events,
  ) {
    final blocks = <Widget>[];
    for (final e in timed) {
      final parts = e.tm!.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final top = h * _rowH + m * _rowH / 60;
      double height = _rowH;
      if (e.te != null && e.te!.contains(':')) {
        final ep = e.te!.split(':');
        final eh = int.tryParse(ep[0]) ?? h;
        final em = int.tryParse(ep[1]) ?? m;
        height = ((eh - h) * 60 + (em - m)) * _rowH / 60;
      }
      final thColor = e.sport && e.sportColor != null
          ? Color(e.sportColor!)
          : e.themeIds.isNotEmpty
              ? themes
                  .firstWhere(
                    (t) => e.themeIds.contains(t.id),
                    orElse: () => const CalendarTheme(
                        id: '', name: '', color: '#6b8ec2'),
                  )
                  .colorValue
              : sh.accent;

      final idx = (events[widget.dateKey] ?? []).indexOf(e);
      // 읽기전용(스포츠·학사·생일·구독)·시간표는 드래그 비활성 — 탭만 허용.
      final draggable = idx >= 0 && !e.isTimetable && !e.sport &&
          !e.academic && !e.birthday;
      blocks.add(_TimedEventBlock(
        event: e,
        index: idx,
        dateKey: widget.dateKey,
        top: top,
        height: height.clamp(20.0, double.infinity),
        rowH: _rowH,
        color: thColor,
        sh: sh,
        draggable: draggable,
        onTapEvent: () {
          if (idx >= 0) {
            showAddEditEventModal(context,
                dateKey: widget.dateKey, editIndex: idx);
            return;
          }
          // 가상 반복 occurrence(idx<0이고 rr 있음) → anchor 찾아 편집.
          if (e.rr != null && !e.isTimetable && !e.sport &&
              !e.academic && !e.birthday) {
            final anchor = _findAnchorFor(e, events);
            if (anchor != null) {
              showAddEditEventModal(context,
                  dateKey: anchor.$1, editIndex: anchor.$2);
              return;
            }
          }
          showEventDetailSheet(context, e);
        },
        onCommitMove: (deltaMinutes) =>
            _shiftEventTime(e, idx, deltaMinutes, height),
        onCommitResize: (deltaMinutes) =>
            _resizeEvent(e, idx, deltaMinutes, height),
      ));
    }
    return blocks;
  }

  // 가상 occurrence의 원본 anchor 위치(dateKey, index) 찾기. id 우선, 없으면 동일 t+tm 매칭.
  (String, int)? _findAnchorFor(
      EventItem virtual, Map<String, List<EventItem>> events) {
    for (final entry in events.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final e = entry.value[i];
        if (e.rr == null) continue;
        final match = virtual.id != null && e.id == virtual.id;
        final fallback = virtual.id == null &&
            e.t == virtual.t &&
            e.tm == virtual.tm;
        if (match || fallback) return (entry.key, i);
      }
    }
    return null;
  }

  // 분 단위 시각 시프트(시작·종료 함께). 15분 단위로 스냅.
  void _shiftEventTime(
      EventItem e, int idx, int deltaMinutes, double height) {
    if (idx < 0 || deltaMinutes == 0) return;
    final parts = e.tm!.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    var startMin = (h * 60 + m + deltaMinutes).clamp(0, 24 * 60 - 1);
    startMin = (startMin / 15).round() * 15;
    final nh = startMin ~/ 60;
    final nm = startMin % 60;
    String fmt(int hh, int mm) =>
        '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    String? newTe = e.te;
    if (e.te != null && e.te!.contains(':')) {
      final ep = e.te!.split(':');
      final eh = int.tryParse(ep[0]) ?? h;
      final em = int.tryParse(ep[1]) ?? m;
      final durMin = (eh * 60 + em) - (h * 60 + m);
      var endMin = (startMin + durMin).clamp(startMin + 5, 24 * 60);
      newTe = fmt(endMin ~/ 60, endMin % 60);
    }
    final updated = e.copyWith(tm: fmt(nh, nm), te: newTe);
    ref.read(eventsProvider.notifier)
        .updateEvent(widget.dateKey, idx, updated);
  }

  // 종료 시각만 변경(리사이즈). 15분 스냅, 최소 15분 길이.
  void _resizeEvent(
      EventItem e, int idx, int deltaMinutes, double height) {
    if (idx < 0 || deltaMinutes == 0) return;
    final parts = e.tm!.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    int curEndMin;
    if (e.te != null && e.te!.contains(':')) {
      final ep = e.te!.split(':');
      curEndMin = (int.tryParse(ep[0]) ?? h) * 60 + (int.tryParse(ep[1]) ?? m);
    } else {
      curEndMin = h * 60 + m + 60;
    }
    var endMin = (curEndMin + deltaMinutes);
    endMin = (endMin / 15).round() * 15;
    endMin = endMin.clamp(h * 60 + m + 15, 24 * 60);
    String fmt(int hh, int mm) =>
        '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    final updated = e.copyWith(te: fmt(endMin ~/ 60, endMin % 60));
    ref.read(eventsProvider.notifier)
        .updateEvent(widget.dateKey, idx, updated);
  }

  String _dowName(int w) => i18nd.weekdayShort(w);
}

// ─── 할 일 바 ────────────────────────────────────────────────────
class _TodoBar extends StatelessWidget {
  final List<TodoItem> todos;
  final SurlapColors sh;
  final void Function(String id) onToggle;
  final void Function(TodoItem) onTapTodo;
  const _TodoBar(
      {required this.todos,
      required this.sh,
      required this.onToggle,
      required this.onTapTodo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: sh.border, width: Borders.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trf('할 일 ({0})', [todos.length]),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: sh.inkSoft,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          ...todos.map((t) {
            final c = todoPriorityColor(t.priority, sh);
            return InkWell(
              onTap: () => onTapTodo(t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => onToggle(t.id),
                      child: Icon(
                        todoStatusIcon(t.status),
                        size: 18,
                        color: todoStatusColor(t.status, t.priority, sh),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (t.hasPriority) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('P${t.priority}',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: c)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(
                          color: t.done ? sh.inkFaint : sh.ink,
                          decoration:
                              t.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AllDayBar extends StatelessWidget {
  final List<EventItem> items;
  final List<CalendarTheme> themes;
  final SurlapColors sh;
  const _AllDayBar(
      {required this.items, required this.themes, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        // 종일 = accent 옅은 틴트로 구분.
        color: sh.accent.withValues(alpha: sh.dark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
            color: sh.accent.withValues(alpha: 0.22), width: Borders.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('종일'),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: sh.inkSoft,
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          ...items.map((e) {
            final tinted = e.birthday || e.academic;
            final c = e.birthday ? sh.birthdayColor : sh.academicColor;
            final icon =
                e.birthday ? Icons.cake_rounded : Icons.school_rounded;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: tinted
                  ? Row(children: [
                      Icon(icon, size: 14, color: c),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(e.t,
                            style: AppType.body.copyWith(
                                color: c, fontWeight: FontWeight.w600)),
                      ),
                    ])
                  : Text(e.t, style: AppType.body.copyWith(color: sh.ink)),
            );
          }),
        ],
      ),
    );
  }
}

/// 현재 시각 라이브 인디케이터 — 도트 + 가로선 + 좌측 시각 칩.
/// 색상은 브랜드 accent(퍼플), 1분 단위 부모 setState로 갱신.
class _NowLine extends StatelessWidget {
  final int hour, minute;
  final double rowH;
  final double timeColW;
  final SurlapColors sh;
  const _NowLine(
      {required this.hour,
      required this.minute,
      required this.rowH,
      required this.timeColW,
      required this.sh});

  @override
  Widget build(BuildContext context) {
    final top = hour * rowH + minute * rowH / 60;
    final c = sh.accent;
    final timeText = '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
    return Positioned(
      top: top - 9,
      left: -timeColW,
      right: 0,
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 좌측 시각 칩 — 시간 레이블 컬럼 위에 겹쳐 그린다.
          SizedBox(
            width: timeColW,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 도트
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: sh.dark
                  ? [BoxShadow(
                      color: c.withValues(alpha: 0.5),
                      blurRadius: 6, spreadRadius: 1,
                    )]
                  : null,
            ),
          ),
          // 가로선
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: c.withValues(alpha: sh.dark ? 0.8 : 0.7),
                boxShadow: sh.dark
                    ? [BoxShadow(
                        color: c.withValues(alpha: 0.4),
                        blurRadius: 4, spreadRadius: 1,
                      )]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 시간 일정 블록 — 길게 누른 뒤 드래그 = 시각 이동, 하단 핸들 드래그 = 길이 조정.
/// 좌표 변환은 부모가 정한 `rowH`(시간당 픽셀)로 분 ↔ 픽셀을 환산한다.
class _TimedEventBlock extends StatefulWidget {
  final EventItem event;
  final int index;
  final String dateKey;
  final double top;
  final double height;
  final double rowH;
  final Color color;
  final SurlapColors sh;
  final bool draggable;
  final VoidCallback onTapEvent;
  final void Function(int deltaMinutes) onCommitMove;
  final void Function(int deltaMinutes) onCommitResize;

  const _TimedEventBlock({
    required this.event,
    required this.index,
    required this.dateKey,
    required this.top,
    required this.height,
    required this.rowH,
    required this.color,
    required this.sh,
    required this.draggable,
    required this.onTapEvent,
    required this.onCommitMove,
    required this.onCommitResize,
  });

  @override
  State<_TimedEventBlock> createState() => _TimedEventBlockState();
}

class _TimedEventBlockState extends State<_TimedEventBlock> {
  double _dragDy = 0;    // 이동(↑/↓) 누적 픽셀
  double _resizeDy = 0;  // 리사이즈(↓ 늘리기/↑ 줄이기) 누적 픽셀
  bool _moving = false;
  bool _resizing = false;

  int _pxToMin(double px) => (px / widget.rowH * 60).round();

  @override
  Widget build(BuildContext context) {
    final sh = widget.sh;
    final e = widget.event;
    final activeOpacity = (_moving || _resizing) ? 0.85 : 1.0;
    final liveHeight =
        (widget.height + _resizeDy).clamp(20.0, double.infinity);

    return Positioned(
      top: widget.top + _dragDy,
      left: 4,
      right: 6,
      height: liveHeight,
      child: Opacity(
        opacity: activeOpacity,
        child: GestureDetector(
          onTap: widget.onTapEvent,
          onLongPressStart: widget.draggable
              ? (_) => setState(() {
                    _moving = true;
                    _dragDy = 0;
                  })
              : null,
          onLongPressMoveUpdate: widget.draggable
              ? (d) => setState(() => _dragDy = d.offsetFromOrigin.dy)
              : null,
          onLongPressEnd: widget.draggable
              ? (_) {
                  final delta = _pxToMin(_dragDy);
                  setState(() {
                    _moving = false;
                    _dragDy = 0;
                  });
                  if (delta != 0) widget.onCommitMove(delta);
                }
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm, vertical: Gap.xs),
                decoration: BoxDecoration(
                  // 블록은 주인공 — 채도/대비 ↑ (그리드는 8% 라인으로 죽임).
                  color: widget.color.withValues(alpha: sh.dark ? 0.28 : 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border(left: BorderSide(color: widget.color, width: 3)),
                  boxShadow: _moving || _resizing
                      ? [BoxShadow(
                          color: widget.color.withValues(alpha: 0.45),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        )]
                      : (sh.dark
                          ? [BoxShadow(
                              color: widget.color.withValues(alpha: 0.22),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 1),
                            )]
                          // 라이트 모드: soft shadow (테두리 없이 떠 보이게)
                          : sh.shadowCard),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.sport && e.sportLogo != null && e.sportLogo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 3, top: 1),
                        child: Image.network(e.sportLogo!,
                            width: 12,
                            height: 12,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Text(e.sportEmoji ?? '🏅',
                                style: const TextStyle(fontSize: 11))),
                      ),
                    Text('${e.tm} ',
                        style: TextStyle(
                            fontSize: 10,
                            color: sh.inkSoft,
                            fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Text(
                        e.t,
                        // 본문 굵게 + ink 풀톤 → 죽인 그리드 위에서 또렷.
                        style: AppType.caption.copyWith(
                            fontWeight: FontWeight.w700, color: sh.ink),
                        maxLines: liveHeight > widget.rowH ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // 하단 리사이즈 핸들 — 드래그 가능 일정만 노출.
              if (widget.draggable)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -2,
                  height: 12,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => setState(() {
                      _resizing = true;
                      _resizeDy = 0;
                    }),
                    onVerticalDragUpdate: (d) =>
                        setState(() => _resizeDy += d.delta.dy),
                    onVerticalDragEnd: (_) {
                      final delta = _pxToMin(_resizeDy);
                      setState(() {
                        _resizing = false;
                        _resizeDy = 0;
                      });
                      if (delta != 0) widget.onCommitResize(delta);
                    },
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
