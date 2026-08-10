import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../models/event_item.dart';
import '../../models/todo_item.dart';
import '../../models/calendar_theme.dart';
import '../../models/day_template.dart';
import '../../models/template_range.dart';
import '../../models/record_template.dart';
import 'day_cell.dart';
import 'multiday_span.dart';

// 바 레이아웃 상수
const double _kBarTop = 36; // 날짜 숫자 아래(셀 콘텐츠 시작 지점 = pad4+숫자30+간격2)
const double _kBadgeH = 17; // 기록 뱃지 줄 높이(겹침 방지로 실제 글리프보다 약간 여유)
const double _kBarH = 4; // 접힘 바 두께
const double _kBarStep = 6; // 접힘 레인 간격(바4 + 간격2)
const double _kLabelH = 16; // 펼침 바 높이
const double _kLabelStep = 19; // 펼침 레인 간격

class MonthGrid extends StatefulWidget {
  final int year;
  final int month;
  final int weekStartDow;
  final Map<String, List<EventItem>> events;
  final Map<String, List<TodoItem>> todosByDate;
  final List<CalendarTheme> themes;
  final SurlapColors sh;
  final bool showPast;
  final Map<String, int> starred;
  final Set<String> circles;
  final List<DayTemplate> dayTemplates;
  final Map<String, Map<String, Map<String, dynamic>>> widgetValues;
  final List<TemplateRange> templateRanges;
  final Map<String, RecordTemplate> templatesById;
  final void Function(DateTime) onDayTap;
  final void Function(DateTime) onDayLongPress;

  /// 선택된 날짜 'YYYY-MM-DD'. 그 날이 있는 주가 자동으로 펼쳐진다.
  final String? selectedKey;
  final bool heroCells;
  /// 한 칸 높이 배율. 1.0=현재 화면 6주 균등분배(스크롤 없음).
  /// 1.0 초과 → 그리드가 세로로 커지며 스크롤 가능. 1.0 미만 → 좀 더 빽빽.
  final double cellHeightFactor;

  const MonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.weekStartDow,
    required this.events,
    this.todosByDate = const {},
    required this.themes,
    required this.sh,
    required this.showPast,
    this.starred = const {},
    this.circles = const {},
    this.dayTemplates = const [],
    this.widgetValues = const {},
    this.templateRanges = const [],
    this.templatesById = const {},
    required this.onDayTap,
    required this.onDayLongPress,
    this.selectedKey,
    this.heroCells = false,
    this.cellHeightFactor = 1.0,
  });

  @override
  State<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<MonthGrid> {
  int? _expandedRow;

  SurlapColors get sh => widget.sh;

  @override
  void didUpdateWidget(covariant MonthGrid old) {
    super.didUpdateWidget(old);
    // 달이 바뀌면 펼침 해제.
    if (old.year != widget.year || old.month != widget.month) {
      _expandedRow = null;
    }
  }

  // ── 행 구성(메모/일자 칼럼 + 일정 데이터) ──
  late int _leadingCount, _trailingInRow5;
  late DateTime _firstCell;

  List<RecordBadge> _badgesFor(DateTime d) {
    final key = du.toDateKey(d);
    return recordBadgesForDate(key, widget.templateRanges,
        widget.widgetValues[key] ?? const {}, widget.templatesById);
  }

  ({
    List<DateTime> dates,
    List<List<EventItem>> colEvents,
    List<List<TodoItem>> colTodos,
    int leadMemo, // 0=없음, n=앞 n칸 메모
    int trailMemo, // 0=없음, n=뒤 n칸 메모
    bool hasBadge,
  }) _rowInfo(int row) {
    final dates =
        List.generate(7, (c) => _firstCell.add(Duration(days: row * 7 + c)));
    final leadMemo = (row == 0 && _leadingCount > 0) ? _leadingCount : 0;
    final trailMemo = (row == 5 && _trailingInRow5 > 0) ? _trailingInRow5 : 0;
    final colEvents = <List<EventItem>>[];
    final colTodos = <List<TodoItem>>[];
    bool hasBadge = false;
    for (int c = 0; c < 7; c++) {
      final isMemo = c < leadMemo || c >= 7 - trailMemo;
      if (isMemo) {
        colEvents.add(const []);
        colTodos.add(const []);
        continue;
      }
      final key = du.toDateKey(dates[c]);
      colEvents.add((widget.events[key] ?? const <EventItem>[])
          .where((e) => !e.isTimetable)
          .toList());
      colTodos.add(widget.todosByDate[key] ?? const []);
      if (!hasBadge && _badgesFor(dates[c]).isNotEmpty) hasBadge = true;
    }
    return (
      dates: dates,
      colEvents: colEvents,
      colTodos: colTodos,
      leadMemo: leadMemo,
      trailMemo: trailMemo,
      hasBadge: hasBadge,
    );
  }

  // 탭은 언제나 "그 날짜 선택" 하나만 뜻한다(스펙 §8). 예전에는 같은 셀을
  // 다시 누르면 접히고, 바가 있는 줄이면 선택 대신 펼치기가 되는 등 한 제스처가
  // 세 가지 뜻을 가졌다. 여러 날 바가 있는 줄은 선택되면 자동으로 펼쳐진다.
  void _onCellTap(int row, DateTime date, bool rowHasBars) {
    setState(() => _expandedRow = rowHasBars ? row : null);
    widget.onDayTap(date);
  }

  @override
  Widget build(BuildContext context) {
    final headers = du.weekdayHeaders(widget.weekStartDow);
    _firstCell =
        du.firstCellDate(widget.year, widget.month, widget.weekStartDow);

    final firstDayDate = DateTime(widget.year, widget.month, 1);
    final daysInMonth = DateTime(widget.year, widget.month + 1, 0).day;
    _leadingCount = (firstDayDate.weekday % 7 - widget.weekStartDow + 7) % 7;
    final firstTrailingIdx = _leadingCount + daysInMonth;
    _trailingInRow5 = firstTrailingIdx >= 42
        ? 0
        : firstTrailingIdx <= 35
            ? 7
            : 42 - firstTrailingIdx;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
          child: Row(
            children: headers.asMap().entries.map((e) {
              final isSunHeader =
                  (widget.weekStartDow + e.key) % 7 == DateTime.sunday % 7;
              final isSatHeader =
                  (widget.weekStartDow + e.key) % 7 == DateTime.saturday;
              return Expanded(
                child: Center(
                  child: Text(
                    e.value,
                    style: AppType.labelMedium.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: isSunHeader
                          ? sh.sun.withValues(alpha: 0.85)
                          : isSatHeader
                              ? sh.sat.withValues(alpha: 0.85)
                              : sh.ink.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            final baseRowH = c.maxHeight / 6;
            final rowH = baseRowH * widget.cellHeightFactor;
            final totalH = rowH * 6;
            final needsScroll = totalH > c.maxHeight + 0.5;
            final grid = Stack(
              children: [
                Column(
                  children: List.generate(
                      6, (r) => SizedBox(height: rowH, child: _weekRow(r, rowH))),
                ),
                if (_expandedRow != null) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _expandedRow = null),
                    ),
                  ),
                  _expandedPanel(_expandedRow!, rowH),
                ],
              ],
            );
            if (!needsScroll) return grid;
            return SingleChildScrollView(
              child: SizedBox(height: totalH, child: grid),
            );
          }),
        ),
      ],
    );
  }

  // ── 한 주 행: 셀 배경(날짜·뱃지·격자) + 접힘 색 바 오버레이 ──
  Widget _weekRow(int row, double rowH) {
    final info = _rowInfo(row);
    final viewMonth = DateTime(widget.year, widget.month);
    final res = computeWeekBars(
        info.colEvents, info.colTodos, info.dates, widget.themes, sh);
    final hasBars = res.bars.isNotEmpty;
    final barTop = _kBarTop + (info.hasBadge ? _kBadgeH : 0);
    final maxLanes =
        ((rowH - barTop - 3) / _kBarStep).floor().clamp(1, 8);

    // 모든 칸을 그린다(달 밖 날짜는 DayCell이 흐리게 처리) — 메모용 빈칸을 두면
    // 그 자리 격자선이 끊겨서, 7칸 모두 셀로 채워 선이 이어지게 한다.
    final cells = [
      for (int c = 0; c < 7; c++)
        _dayCell(info.dates[c], viewMonth, row, hasBars),
    ];

    if (!hasBars) return Row(children: cells);

    return LayoutBuilder(builder: (ctx, cc) {
      final colW = cc.maxWidth / 7;
      // 가려진(초과 레인) 바 수 — 칼럼별 +N.
      final hidden = List<int>.filled(7, 0);
      for (final b in res.bars) {
        if (b.lane >= maxLanes) {
          for (int col = b.start; col <= b.end; col++) {
            hidden[col]++;
          }
        }
      }
      return Stack(
        children: [
          Row(children: cells),
          // 접힘 색 바 (이름 없이 색만). 탭은 셀이 처리 → IgnorePointer.
          IgnorePointer(
            child: Stack(
              children: [
                for (final b in res.bars)
                  if (b.lane < maxLanes)
                    Positioned(
                      top: barTop + b.lane * _kBarStep,
                      left: b.start * colW + 1.5,
                      width: (b.end - b.start + 1) * colW - 3,
                      height: _kBarH,
                      child: _ThinBar(bar: b),
                    ),
                for (int col = 0; col < 7; col++)
                  if (hidden[col] > 0)
                    Positioned(
                      left: col * colW + 4,
                      top: barTop + maxLanes * _kBarStep,
                      child: Text('+${hidden[col]}',
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: sh.inkSoft)),
                    ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _dayCell(
      DateTime cellDate, DateTime viewMonth, int row, bool rowHasBars) {
    return Expanded(
      child: DayCell(
        date: cellDate,
        viewMonth: viewMonth,
        events: const [], // 일정은 바로만 표시 → 칩 비활성
        todos: const [],
        themes: widget.themes,
        sh: sh,
        showPast: widget.showPast,
        hasCircle: widget.circles.contains(du.toDateKey(cellDate)),
        recordBadges: _badgesFor(cellDate),
        isSelected: widget.selectedKey == du.toDateKey(cellDate),
        onTap: () => _onCellTap(row, cellDate, rowHasBars),
        onLongPress: () => widget.onDayLongPress(cellDate),
        heroDateNumber: widget.heroCells,
      ),
    );
  }

  // ── 펼침 패널: 그 주 바들을 두껍게 + 이름 표시 ──
  Widget _expandedPanel(int row, double rowH) {
    final info = _rowInfo(row);
    final res = computeWeekBars(
        info.colEvents, info.colTodos, info.dates, widget.themes, sh);
    final barTop = _kBarTop + (info.hasBadge ? _kBadgeH : 0);
    final panelH = res.laneCount * _kLabelStep + 10;

    return Positioned(
      top: row * rowH + barTop,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.96 + 0.04 * t,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: Container(
          height: panelH,
          decoration: BoxDecoration(
            color: sh.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sh.ink.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: sh.dark ? 0.4 : 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
          child: LayoutBuilder(builder: (ctx, cc) {
            final colW = cc.maxWidth / 7;
            return Stack(
              children: [
                for (final b in res.bars)
                  Positioned(
                    top: b.lane * _kLabelStep,
                    left: b.start * colW + 1.5,
                    width: (b.end - b.start + 1) * colW - 3,
                    height: _kLabelH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onDayTap(b.date),
                      child: _LabelBar(bar: b, sh: sh),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// 접힘: 색만 (이름 없음)
class _ThinBar extends StatelessWidget {
  final WeekBar bar;
  const _ThinBar({required this.bar});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bar.done ? bar.color.withValues(alpha: 0.45) : bar.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// 펼침: 색 + 이름
class _LabelBar extends StatelessWidget {
  final WeekBar bar;
  final SurlapColors sh;
  const _LabelBar({required this.bar, required this.sh});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: bar.color.withValues(alpha: sh.dark ? 0.28 : 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: bar.color, width: 3)),
      ),
      child: Text(
        bar.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: sh.dark ? sh.ink : bar.color,
          decoration: bar.done ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

