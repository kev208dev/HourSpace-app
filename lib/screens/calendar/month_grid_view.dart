import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar/calendar_item.dart';
import '../../core/calendar/calendar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../i18n/strings.dart';
import '../../modals/day_action_sheet.dart';
import '../../providers/extras_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/view_provider.dart';
import 'calendar_screen.dart';

/// 월 보기 — 항상 6주 (핸드오프 C2).
///
/// 주 시작 요일 설정을 따르고 앞뒤 달 날짜로 6주를 채운다. 같은 제목이 연속된
/// 날짜에 걸치면 출처가 달라도 하나의 여러 날 막대로 묶고, 겹치면 레인으로 나눈다.
///
/// 상호작용(핸드오프):
///   탭       → 그 주를 펼쳐 보여주고 날짜 선택. 같은 날짜를 다시 누르면 하루 보기
///   길게     → 날짜 작업 시트
///   두 번 탭 → 동그라미 표시 토글
class MonthGridView extends ConsumerWidget {
  const MonthGridView({super.key});

  /// 한 칸에 세로로 보여줄 시간 일정 줄 수 상한.
  static const _maxLinesPerDay = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final view = ref.watch(viewProvider);
    final weekStart = ref.watch(settingsProvider).weekStartDow;
    final byDate = ref.watch(calendarItemsByDateProvider);
    final circles = ref.watch(circlesProvider);

    final first =
        du.firstCellDate(view.viewYear, view.viewMonth, weekStart);
    final weeks = [
      for (var w = 0; w < 6; w++)
        [
          for (var d = 0; d < 7; d++)
            DateTime(first.year, first.month, first.day + w * 7 + d),
        ],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.sm, 0, Gap.sm, kCalendarBottomPad),
      children: [
        _WeekdayRow(weekStart: weekStart),
        for (final week in weeks)
          _WeekRow(
            days: week,
            viewMonth: view.viewMonth,
            selectedKey: view.selectedDay,
            byDate: byDate,
            circles: circles,
            sh: sh,
          ),
        SelectedDayList(dateKey: view.selectedDay),
      ],
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final int weekStart;
  const _WeekdayRow({required this.weekStart});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final headers = du.weekdayHeaders(weekStart);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                headers[i],
                textAlign: TextAlign.center,
                style: AppType.label.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.66,
                  color: _dowColor(i, sh),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _dowColor(int index, SurlapColors sh) {
    final dow = (weekStart + index) % 7; // 0=일
    if (dow == 0) return sh.sun;
    if (dow == 6) return sh.sat;
    return sh.ink.withValues(alpha: 0.55);
  }
}

/// 한 주 — 날짜 원 + 여러 날 막대 레인 + 칸별 시간 일정 줄.
class _WeekRow extends ConsumerWidget {
  final List<DateTime> days;
  final int viewMonth;
  final String selectedKey;
  final Map<String, List<CalendarItem>> byDate;
  final Set<String> circles;
  final SurlapColors sh;

  const _WeekRow({
    required this.days,
    required this.viewMonth,
    required this.selectedKey,
    required this.byDate,
    required this.circles,
    required this.sh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lanes = _buildLanes();
    final spannedTitles = {
      for (final lane in lanes)
        for (final bar in lane) bar.title,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: sh.ink.withValues(alpha: 0.09))),
      ),
      padding: const EdgeInsets.only(top: 3, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final d in days)
                Expanded(child: _DayCircle(date: d, week: this)),
            ],
          ),
          for (final lane in lanes) _LaneRow(bars: lane, sh: sh),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in days)
                Expanded(
                  child: _DayLines(
                    items: (byDate[du.toDateKey(d)] ?? const [])
                        .where((i) => !spannedTitles.contains(i.title))
                        .toList(),
                    sh: sh,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 같은 제목이 연속된 날짜에 걸치면 하나의 막대로 묶고 겹치면 레인을 나눈다.
  List<List<_Bar>> _buildLanes() {
    final present = <String, List<bool>>{};
    final sample = <String, CalendarItem>{};
    for (var i = 0; i < 7; i++) {
      for (final item in byDate[du.toDateKey(days[i])] ?? const <CalendarItem>[]) {
        (present[item.title] ??= List.filled(7, false))[i] = true;
        sample.putIfAbsent(item.title, () => item);
      }
    }

    final bars = <_Bar>[];
    present.forEach((title, flags) {
      var i = 0;
      while (i < 7) {
        if (!flags[i]) {
          i++;
          continue;
        }
        var j = i;
        while (j + 1 < 7 && flags[j + 1]) {
          j++;
        }
        // 하루짜리는 막대로 만들지 않는다 — 아래 줄 목록으로 보여준다.
        if (j > i) bars.add(_Bar(title, i, j, sample[title]!));
        i = j + 1;
      }
    });

    bars.sort((a, b) => a.start.compareTo(b.start));
    final lanes = <List<_Bar>>[];
    for (final bar in bars) {
      var placed = false;
      for (final lane in lanes) {
        if (lane.last.end < bar.start) {
          lane.add(bar);
          placed = true;
          break;
        }
      }
      if (!placed) lanes.add([bar]);
    }
    return lanes;
  }
}

class _Bar {
  final String title;
  final int start;
  final int end;
  final CalendarItem sample;
  const _Bar(this.title, this.start, this.end, this.sample);
}

class _LaneRow extends StatelessWidget {
  final List<_Bar> bars;
  final SurlapColors sh;
  const _LaneRow({required this.bars, required this.sh});

  @override
  Widget build(BuildContext context) {
    // 7칸 그리드 위에 막대를 배치한다.
    final cells = List<Widget>.generate(7, (_) => const SizedBox.shrink());
    final flexes = List<int>.filled(7, 1);
    final children = <Widget>[];
    var col = 0;
    final sorted = [...bars]..sort((a, b) => a.start.compareTo(b.start));

    for (final bar in sorted) {
      while (col < bar.start) {
        children.add(const Expanded(child: SizedBox.shrink()));
        col++;
      }
      final span = bar.end - bar.start + 1;
      final color = bar.sample.color ?? sh.accent;
      children.add(Expanded(
        flex: span,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            bar.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.micro.copyWith(
                fontWeight: FontWeight.w600, height: 1.4, color: sh.ink),
          ),
        ),
      ));
      col = bar.end + 1;
    }
    while (col < 7) {
      children.add(const Expanded(child: SizedBox.shrink()));
      col++;
    }
    // cells/flexes 는 배치 계산용 자리표시자 — 실제 렌더는 children.
    assert(cells.length == 7 && flexes.length == 7);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: children),
    );
  }
}

class _DayCircle extends ConsumerWidget {
  final DateTime date;
  final _WeekRow week;
  const _DayCircle({required this.date, required this.week});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = week.sh;
    final key = du.toDateKey(date);
    final isToday = du.isSameDay(date, DateTime.now());
    final isSelected = key == week.selectedKey;
    final inMonth = date.month == week.viewMonth;
    final circled = week.circles.contains(key);
    final n = ref.read(viewProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 탭: 선택. 이미 선택된 날짜를 다시 누르면 하루 보기로.
      onTap: () {
        if (isSelected) {
          n.setCalendarMode(CalendarViewMode.day);
        } else {
          n.selectDay(key);
        }
      },
      onDoubleTap: () => ref.read(circlesProvider.notifier).toggle(key),
      onLongPress: () => showDayActionSheet(context, key, date),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? sh.now : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isSelected && !isToday
                      ? Border.all(color: sh.accent, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${date.day}',
                  style: AppType.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isToday
                        ? sh.onNow
                        : sh.ink.withValues(alpha: inMonth ? 1 : 0.32),
                  ),
                ),
              ),
              if (circled)
                Positioned.fill(
                  left: -3,
                  right: -3,
                  top: -3,
                  bottom: -3,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: sh.accent2, width: 1.5),
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

/// 칸 안의 시간 일정 줄 — 3px 점 + 9.5px 제목, 최대 2줄 + 넘침 표기.
class _DayLines extends StatelessWidget {
  final List<CalendarItem> items;
  final SurlapColors sh;
  const _DayLines({required this.items, required this.sh});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(MonthGridView._maxLinesPerDay).toList();
    final rest = items.length - shown.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in shown)
            Row(
              children: [
                Container(
                  width: 3,
                  height: 3,
                  margin: const EdgeInsets.only(right: 3),
                  color: item.color ?? sh.accent,
                ),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppType.micro.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: sh.ink.withValues(alpha: 0.70)),
                  ),
                ),
              ],
            ),
          if (rest > 0)
            Text(
              trf('+{0}', [rest]),
              style: AppType.micro.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: sh.ink.withValues(alpha: 0.42)),
            ),
        ],
      ),
    );
  }
}
