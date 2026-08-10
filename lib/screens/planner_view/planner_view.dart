import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../models/event_item.dart';
import '../../models/calendar_theme.dart';
import '../../providers/events_provider.dart';
import '../../providers/holidays_provider.dart';
import '../../providers/themes_provider.dart';
import '../../providers/view_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../providers/settings_provider.dart';
import '../../supabase/neis_service.dart'
    show NeisSchool, academicVisibleForGrade;
import '../timetable_view/timetable_view.dart'
    show timetableSubjectsForDate, getDisplaySubjectName;
import '../../widgets/arrow_pinch.dart';
import '../../widgets/header_collapse.dart';
import '../month_view/multiday_span.dart' show eventColorFor;
import '../../providers/academic_schedule_provider.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/sports_provider.dart';
import '../../providers/shared_theme_events_provider.dart';
import '../../providers/recurring_events_provider.dart';
import '../../modals/add_edit_event_modal.dart';
import '../../modals/event_detail_sheet.dart';
import '../search_view.dart';

/// 주간(시간그리드) 뷰 — 한 화면 3일 + 가로로 연속(하루씩) 이동.
/// 시간축(좌측 라벨) 고정, 날짜 헤더는 컬럼과 함께 가로 스크롤. 세로/가로 독립.
class PlannerView extends ConsumerStatefulWidget {
  const PlannerView({super.key});

  @override
  ConsumerState<PlannerView> createState() => _PlannerViewState();
}

const int _kCenter = 100000; // 무한 가로 리스트의 '오늘' 인덱스
const int _daysPerScreen = 3;
const double _timeColW = 54;
const double _baseRowH = 56;
const double _headerH = 42;
const double _allDayBandH = 24;
const double _bottomPad = 120;

class _PlannerViewState extends ConsumerState<PlannerView> {
  final _vCtrl = ScrollController(); // 세로(시간) 본문
  final _vLabelCtrl = ScrollController(); // 세로 시간 라벨(본문 따라감)
  ScrollController? _hCtrl; // 가로(날짜) 본문
  ScrollController? _hHeaderCtrl; // 가로 날짜 헤더(본문 따라감)
  double _dayW = 0;
  // 좌측 첫 보이는 컬럼 인덱스(제목용) — ValueNotifier라 스크롤 시 그리드 리빌드 X.
  final _leadVN = ValueNotifier<int>(_kCenter);

  double _zoom = 1.0;
  double _zoomStart = 1.0; // 핀치 시작 시점의 줌
  double get _rowH => _baseRowH * _zoom;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // 가로 인덱스 기준점(_kCenter) = 오늘. 진입 시엔 대상 날짜를 3일 중 '가운데'로.
  late final DateTime _anchor = _today;

  DateTime _dateFor(int i) => _anchor.add(Duration(days: i - _kCenter));

  // 진입 대상 날짜 — 캘린더에서 선택한 날짜(항상 값이 있다).
  DateTime get _targetDate {
    try {
      final d = du.fromDateKey(ref.read(viewProvider).selectedDay);
      return DateTime(d.year, d.month, d.day);
    } catch (_) {
      return _today;
    }
  }

  // 대상 날짜가 가운데(3일 중)로 오게 하는 좌측(leftmost) 인덱스.
  int _centerLeadIndex(DateTime target) =>
      _kCenter + target.difference(_anchor).inDays - 1;

  @override
  void initState() {
    super.initState();
    _vCtrl.addListener(_syncLabel);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToNow(animate: false));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hCtrl == null) {
      final w = MediaQuery.of(context).size.width;
      _dayW = (w - _timeColW) / _daysPerScreen;
      // 대상 날짜가 3일 중 가운데로 오게 좌측 컬럼을 맞춘다.
      final lead = _centerLeadIndex(_targetDate);
      _leadVN.value = lead;
      final init = lead * _dayW;
      _hCtrl = ScrollController(initialScrollOffset: init)
        ..addListener(_syncHeader);
      _hHeaderCtrl = ScrollController(initialScrollOffset: init);
    }
  }

  void _syncLabel() {
    if (!_vLabelCtrl.hasClients || !_vCtrl.hasClients) return;
    final o = _vCtrl.offset.clamp(
        _vLabelCtrl.position.minScrollExtent,
        _vLabelCtrl.position.maxScrollExtent);
    if (_vLabelCtrl.offset != o) _vLabelCtrl.jumpTo(o);
  }

  void _syncHeader() {
    final h = _hCtrl!;
    if (!_hHeaderCtrl!.hasClients || !h.hasClients) return;
    final o = h.offset.clamp(_hHeaderCtrl!.position.minScrollExtent,
        _hHeaderCtrl!.position.maxScrollExtent);
    if (_hHeaderCtrl!.offset != o) _hHeaderCtrl!.jumpTo(o);
    final lead = (h.offset / _dayW).round();
    if (lead != _leadVN.value) {
      // 스크롤 정착이 레이아웃/빌드 단계에서 일어나면, 여기서 _leadVN을 바꾸는 순간
      // 헤더 제목(Row=RenderFlex)이 레이아웃 도중 리빌드돼 "RenderFlex was mutated"
      // 크래시가 날 수 있다. 그 단계면 다음 프레임으로 미룬다.
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _leadVN.value = lead;
        });
      } else {
        _leadVN.value = lead;
      }
    }
  }

  void _scrollToNow({bool animate = true}) {
    if (!_vCtrl.hasClients) return;
    final now = DateTime.now();
    final target = ((now.hour - 1).clamp(0, 23) * _rowH).clamp(
        _vCtrl.position.minScrollExtent, _vCtrl.position.maxScrollExtent);
    if (animate) {
      _vCtrl.animateTo(target,
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else {
      _vCtrl.jumpTo(target);
    }
  }

  void _shiftDays(int delta) {
    final h = _hCtrl;
    if (h == null || !h.hasClients) return;
    h.animateTo((_leadVN.value + delta) * _dayW,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  void _goToday() {
    // 오늘을 3일 중 가운데로.
    final lead = _centerLeadIndex(_today);
    _hCtrl?.animateTo(lead * _dayW,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToNow(animate: true));
  }

  @override
  void dispose() {
    _vCtrl.removeListener(_syncLabel);
    _vCtrl.dispose();
    _vLabelCtrl.dispose();
    _hCtrl?.dispose();
    _hHeaderCtrl?.dispose();
    _leadVN.dispose();
    super.dispose();
  }

  // ── 데이터 ──
  late Map<String, List<EventItem>> _events; // 머지 포함
  late List<CalendarTheme> _themes;
  late Map<String, List<String>> _academic;
  late List<dynamic> _birthdaysRaw;
  late bool _academicHidden, _birthdayHidden, _holidayHidden;
  late int? _grade;

  List<EventItem> _allDayFor(DateTime d) {
    final key = du.toDateKey(d);
    return <EventItem>[
      ...(_events[key] ?? const [])
          .where((e) => !e.hasTime && !e.isTimetable),
      if (!_birthdayHidden)
        for (final b in _birthdaysRaw)
          if (b.month == d.month && b.day == d.day)
            EventItem(t: b.name, th: birthdayThemeId, birthday: true),
      if (!_holidayHidden) ...holidayEventsForDate(d),
      if (!_academicHidden)
        ...dedupAcademicWithHolidays(
                d,
                (_academic[key] ?? const [])
                    .where((n) => academicVisibleForGrade(n, _grade)))
            .map((n) => EventItem(t: n, th: academicThemeId, academic: true)),
    ];
  }

  List<EventItem> _timedFor(DateTime d) =>
      (_events[du.toDateKey(d)] ?? const [])
          .where((e) => e.hasTime && !e.isTimetable)
          .toList();

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final hidden = ref.watch(filterProvider);
    final events = ref.watch(eventsProvider);
    _themes = ref.watch(themesProvider);
    _academic = ref.watch(academicScheduleProvider);
    _academicHidden = hidden.contains(academicThemeId);
    _birthdaysRaw = ref.watch(birthdaysProvider);
    _birthdayHidden = hidden.contains(birthdayThemeId);
    _holidayHidden = hidden.contains(holidayThemeId);
    _grade = NeisSchool.load()?.grade;
    ref.watch(recurringProvider);
    ref.watch(neisCacheProvider);
    final showTt = ref.watch(settingsProvider).showTimetable;

    // 스포츠·구독 머지(필터 반영).
    final merged = <String, List<EventItem>>{...events};
    void mergeExtra(Map<String, List<EventItem>> src) {
      src.forEach((k, items) {
        final vis = items
            .where((e) =>
                e.themeIds.isNotEmpty && !hidden.contains(e.themeIds.first))
            .toList();
        if (vis.isNotEmpty) {
          merged[k] = [...(merged[k] ?? const []), ...vis];
        }
      });
    }

    mergeExtra(ref.watch(sportsEventsByDateProvider));
    mergeExtra(ref.watch(sharedThemeEventsByDateProvider));
    // 반복 일정 가상 occurrence — 필터/숨김 없이 모두 표시.
    ref.watch(recurringEventsByDateProvider).forEach((k, items) {
      if (items.isEmpty) return;
      merged[k] = [...(merged[k] ?? const []), ...items];
    });
    _events = merged;

    final headerTotal = _headerH + _allDayBandH;

    return CollapseOnScroll(
      child: Column(
        children: [
          _PlannerNav(
            title: ValueListenableBuilder<int>(
              valueListenable: _leadVN,
              builder: (_, lead, _) => Text(
                _titleText(lead),
                maxLines: 1,
                style: AppType.title.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: sh.ink),
              ),
            ),
            sh: sh,
            showTimetable: showTt,
            onToggleSchedule: () => ref
                .read(settingsProvider.notifier)
                .setShowTimetable(!showTt),
            onPrev: () => _shiftDays(-_daysPerScreen),
            onNext: () => _shiftDays(_daysPerScreen),
            onToday: _goToday,
            onSearch: () => showSearchSheet(context),
          ),
          Expanded(
            child: _hCtrl == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      // 날짜 헤더(가로 스크롤, 본문 따라감)
                      SizedBox(
                        height: headerTotal,
                        child: Row(
                          children: [
                            SizedBox(
                                width: _timeColW,
                                child: ColoredBox(color: sh.bg)),
                            Expanded(
                              child: ListView.builder(
                                controller: _hHeaderCtrl,
                                scrollDirection: Axis.horizontal,
                                physics: const NeverScrollableScrollPhysics(),
                                itemExtent: _dayW,
                                itemBuilder: (_, i) =>
                                    _dayHeader(_dateFor(i), sh),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        // 두 손가락 핀치로 시간축 확대/축소(버튼 없이).
                        child: GestureDetector(
                          onScaleStart: (_) => _zoomStart = _zoom,
                          onScaleUpdate: (d) {
                            if (d.pointerCount < 2) return;
                            final z = (_zoomStart * d.scale).clamp(0.6, 2.0);
                            if (z != _zoom) setState(() => _zoom = z);
                          },
                          child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 고정 시간 라벨 열
                            SizedBox(
                              width: _timeColW,
                              child: SingleChildScrollView(
                                controller: _vLabelCtrl,
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  children: [
                                    for (int h = 0; h < 24; h++)
                                      SizedBox(
                                        height: _rowH,
                                        child: Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                right: 6, top: 2),
                                            child: Text(
                                                h == 0 ? '' : '$h:00',
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: sh.inkFaint)),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: _bottomPad),
                                  ],
                                ),
                              ),
                            ),
                            // 2D 그리드: 세로(시간) 스크롤 안에 가로(날짜) 리스트
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _vCtrl,
                                child: SizedBox(
                                  height: _rowH * 24 + _bottomPad,
                                  child: Stack(
                                    children: [
                                      ListView.builder(
                                        controller: _hCtrl,
                                        scrollDirection: Axis.horizontal,
                                        itemExtent: _dayW,
                                        physics: _DaySnapPhysics(itemW: _dayW),
                                        itemBuilder: (_, i) =>
                                            _dayColumn(_dateFor(i), showTt, sh),
                                      ),
                                      // 현재 시각선 — 한 컬럼이 아니라 보이는 모든
                                      // 날짜를 가로질러 길게(시간축 따라 세로 스크롤).
                                      _NowLineFull(rowH: _rowH, sh: sh),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _titleText(int lead) {
    final d = _dateFor(lead);
    final e = _dateFor(lead + _daysPerScreen - 1);
    if (d.month == e.month) {
      return '${i18nd.monthDay(d)}–${e.day}';
    }
    return '${i18nd.monthDay(d)} – ${i18nd.monthDay(e)}';
  }

  // ── 날짜 헤더 셀(요일/날짜 + 종일) ──
  Widget _dayHeader(DateTime d, SurlapColors sh) {
    final isToday = du.isSameDay(d, DateTime.now());
    final isSun = d.weekday == DateTime.sunday;
    final isSat = d.weekday == DateTime.saturday;
    final allDay = _allDayFor(d);
    return GestureDetector(
      onTap: () => ref.read(viewProvider.notifier).openDay(du.toDateKey(d)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? sh.accent.withValues(alpha: 0.08) : null,
          border: Border(
              right: BorderSide(
                  color: sh.ink.withValues(alpha: 0.06), width: 0.5)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: _headerH,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_dowName(d)} ',
                        style: AppType.label.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isToday
                                ? sh.accent
                                : isSun
                                    ? sh.danger
                                    : isSat
                                        ? sh.sat
                                        : sh.inkSoft)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isToday ? 7 : 0,
                          vertical: isToday ? 2 : 0),
                      decoration: isToday
                          ? BoxDecoration(
                              color: sh.accent,
                              borderRadius: BorderRadius.circular(999))
                          : null,
                      child: Text('${d.day}',
                          style: AppType.label.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isToday ? Colors.white : sh.ink)),
                    ),
                  ],
                ),
              ),
            ),
            // 종일 — 1줄 + N (다일은 각 날 칩으로).
            SizedBox(
              height: _allDayBandH,
              child: allDay.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: _allDayChip(allDay.first, d, sh),
                          ),
                          if (allDay.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text('+${allDay.length - 1}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: sh.inkSoft)),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allDayChip(EventItem e, DateTime d, SurlapColors sh) {
    final c = eventColorFor(e, _themes, sh);
    return GestureDetector(
      onTap: () => _onEventTap(e, du.toDateKey(d)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(5),
          border: Border(left: BorderSide(color: c, width: 2.5)),
        ),
        child: Text(e.t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: sh.dark ? sh.ink : c)),
      ),
    );
  }

  // ── 하루 컬럼(그리드 라인 + 시간표 + 이벤트 + now) ──
  Widget _dayColumn(DateTime d, bool showTt, SurlapColors sh) {
    final isToday = du.isSameDay(d, DateTime.now());
    final timed = _timedFor(d);
    final placed = _placeTimed(timed);
    final recurring = showTt
        ? timetableSubjectsForDate(ref, d)
        : const <int, String>{};

    return Container(
      decoration: BoxDecoration(
        color: isToday ? sh.accent.withValues(alpha: sh.dark ? 0.05 : 0.03) : null,
        border: Border(
            right:
                BorderSide(color: sh.ink.withValues(alpha: 0.06), width: 0.5)),
      ),
      child: Stack(
        children: [
          // 빈 칸 탭 → 그 날 일간 뷰(이벤트 블록 탭은 위에서 우선 처리).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref
                  .read(viewProvider.notifier)
                  .openDay(du.toDateKey(d)),
            ),
          ),
          // 그리드 가로선
          IgnorePointer(
            child: Column(
            children: [
              for (int h = 0; h < 24; h++)
                Container(
                  height: _rowH,
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: sh.ink.withValues(alpha: sh.dark ? 0.07 : 0.05),
                            width: 0.5)),
                  ),
                ),
            ],
            ),
          ),
          // 시간표 수업(읽기 전용)
          for (final entry in recurring.entries)
            Positioned(
              top: entry.key * _rowH + 2,
              left: 2,
              right: 2,
              height: _rowH - 4,
              child: _RecurringBlock(
                  name: getDisplaySubjectName(entry.value), sh: sh),
            ),
          // 이벤트 블록(겹침 분할)
          for (final p in placed)
            Positioned(
              top: p.top,
              left: p.lane * (_dayW / p.lanes) + 1,
              width: _dayW / p.lanes - 2,
              height: p.height < 18 ? 18 : p.height,
              child: _EventBlock(
                event: p.e,
                color: eventColorFor(p.e, _themes, sh),
                height: p.height < 18 ? 18 : p.height,
                sh: sh,
                onTap: () => _onEventTap(p.e, du.toDateKey(d)),
              ),
            ),
        ],
      ),
    );
  }

  void _onEventTap(EventItem e, String dateKey) {
    final raw = ref.read(eventsProvider)[dateKey] ?? const <EventItem>[];
    final idx = raw.indexOf(e);
    if (idx < 0) {
      showEventDetailSheet(context, e);
    } else {
      showAddEditEventModal(context, dateKey: dateKey, editIndex: idx);
    }
  }

  // 겹치는 timed 이벤트를 클러스터로 묶어 레인(좌우) 배정.
  List<_Placed> _placeTimed(List<EventItem> timed) {
    int toMin(String hhmm) {
      final p = hhmm.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final items = timed.map((e) {
      final s = toMin(e.tm!);
      var en = (e.te != null && e.te!.isNotEmpty) ? toMin(e.te!) : s + 30;
      if (en <= s) en = s + 30;
      return (e: e, s: s, en: en);
    }).toList()
      ..sort((a, b) => a.s.compareTo(b.s));

    final out = <_Placed>[];
    int i = 0;
    while (i < items.length) {
      // 클러스터 수집(전이적 겹침).
      int ce = items[i].en;
      int j = i + 1;
      while (j < items.length && items[j].s < ce) {
        if (items[j].en > ce) ce = items[j].en;
        j++;
      }
      final cluster = items.sublist(i, j);
      // 레인 배정(first-fit).
      final laneEnds = <int>[];
      final laneOf = <int>[];
      for (final it in cluster) {
        int lane = 0;
        while (lane < laneEnds.length && laneEnds[lane] > it.s) {
          lane++;
        }
        if (lane == laneEnds.length) {
          laneEnds.add(it.en);
        } else {
          laneEnds[lane] = it.en;
        }
        laneOf.add(lane);
      }
      final lanes = laneEnds.length;
      for (int k = 0; k < cluster.length; k++) {
        final it = cluster[k];
        out.add(_Placed(
          e: it.e,
          top: it.s * _rowH / 60,
          height: (it.en - it.s) * _rowH / 60,
          lane: laneOf[k],
          lanes: lanes,
        ));
      }
      i = j;
    }
    return out;
  }

  String _dowName(DateTime d) => i18nd.weekdayShort(d.weekday);
}

// 하루(itemW) 단위로 스냅 — 연속 스크롤이되 컬럼이 반쯤 잘려 멈추지 않게.
class _DaySnapPhysics extends ScrollPhysics {
  final double itemW;
  const _DaySnapPhysics({required this.itemW, super.parent});

  @override
  _DaySnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _DaySnapPhysics(itemW: itemW, parent: buildParent(ancestor));

  double _target(ScrollMetrics pos, double velocity, Tolerance tol) {
    double page = pos.pixels / itemW;
    if (velocity < -tol.velocity) {
      page -= 0.5;
    } else if (velocity > tol.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * itemW)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tol = toleranceFor(position);
    final target = _target(position, velocity, tol);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
          spring, position.pixels, target, velocity,
          tolerance: tol);
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _Placed {
  final EventItem e;
  final double top, height;
  final int lane, lanes;
  _Placed(
      {required this.e,
      required this.top,
      required this.height,
      required this.lane,
      required this.lanes});
}

// ── 이벤트 블록: 색 띠 + 아이콘 + 제목 + 시간 ──
class _EventBlock extends StatelessWidget {
  final EventItem event;
  final Color color;
  final double height;
  final SurlapColors sh;
  final VoidCallback onTap;
  const _EventBlock(
      {required this.event,
      required this.color,
      required this.height,
      required this.sh,
      required this.onTap});

  Widget _icon() {
    if (event.sport) {
      final emojiW = Text(event.sportEmoji ?? '🏅',
          style: const TextStyle(fontSize: 11));
      final logo = event.sportLogo;
      if (logo != null && logo.isNotEmpty) {
        return Image.network(logo,
            width: 13,
            height: 13,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => emojiW);
      }
      return emojiW;
    }
    final ic = event.academic
        ? Icons.school_rounded
        : event.birthday
            ? Icons.cake_rounded
            : Icons.event_rounded;
    return Icon(ic, size: 11, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final short = height < 38;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0.5, vertical: 0.5),
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: short ? 1 : 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: sh.dark ? 0.24 : 0.16),
          borderRadius: BorderRadius.circular(7),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        clipBehavior: Clip.hardEdge,
        child: short
            ? Row(children: [
                _icon(),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(event.t,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: sh.ink)),
                ),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _icon(),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(event.t,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: sh.ink)),
                    ),
                  ]),
                  const SizedBox(height: 1),
                  Text(
                    event.te != null && event.te!.isNotEmpty
                        ? '${event.tm}–${event.te}'
                        : '${event.tm}',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: sh.inkSoft),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RecurringBlock extends StatelessWidget {
  final String name;
  final SurlapColors sh;
  const _RecurringBlock({required this.name, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: sh.accent.withValues(alpha: sh.dark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: sh.accent.withValues(alpha: 0.22)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(name,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sh.dark ? sh.ink : sh.accentInk)),
      ),
    );
  }
}

// 현재 시각선 — 보이는 모든 날짜 컬럼을 가로질러 그린다(시간축 따라 세로 위치).
class _NowLineFull extends StatelessWidget {
  final double rowH;
  final SurlapColors sh;
  const _NowLineFull({required this.rowH, required this.sh});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final top = (now.hour * 60 + now.minute) * rowH / 60 - 4;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 1),
              decoration:
                  BoxDecoration(color: sh.danger, shape: BoxShape.circle)),
          Expanded(
              child: Container(
                  height: 1.5, color: sh.danger.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}

// ── 헤더(제목 + 세그먼트 + ⋮) ──
class _PlannerNav extends StatelessWidget {
  final Widget title;
  final SurlapColors sh;
  final bool showTimetable;
  final VoidCallback onToggleSchedule;
  final VoidCallback onPrev, onNext, onToday, onSearch;
  const _PlannerNav({
    required this.title,
    required this.sh,
    required this.showTimetable,
    required this.onToggleSchedule,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: sh.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1행: 디스플레이 타이틀(좌, 탭→오늘) + 화살표 핀치(우) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xs),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onToday,
                    behavior: HitTestBehavior.opaque,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: title,
                    ),
                  ),
                ),
                ArrowPinch(onPrev: onPrev, onNext: onNext),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      size: 20, color: sh.inkSoft),
                  padding: EdgeInsets.zero,
                  tooltip: tr('더보기'),
                  color: sh.card,
                  onSelected: (v) {
                    switch (v) {
                      case 'search': onSearch(); break;
                      case 'schedule': onToggleSchedule(); break;
                    }
                  },
                  itemBuilder: (_) => [
                    _item('search', Icons.search_rounded, tr('일정 검색')),
                    _item(
                        'schedule',
                        showTimetable
                            ? Icons.event_available_rounded
                            : Icons.event_busy_rounded,
                        showTimetable ? tr('스케줄 숨기기') : tr('스케줄 표시'),
                        active: showTimetable),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _item(String v, IconData ic, String label,
          {bool active = false}) =>
      PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(ic, size: 18, color: active ? sh.accent : sh.inkSoft),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: sh.ink)),
        ]),
      );

}
