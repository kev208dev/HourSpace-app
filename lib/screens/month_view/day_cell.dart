import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/constants/korean_holidays.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../core/utils/todo_style.dart';
import '../../models/event_item.dart';
import '../../models/todo_item.dart';
import '../../models/calendar_theme.dart';
import '../../models/day_template.dart';
import '../../models/record_template.dart';
import '../../widgets/record_glyph.dart';
import '../../day_widgets/widget_cell_renderer.dart';
import 'event_chip.dart';

class DayCell extends StatelessWidget {
  final DateTime date;
  final DateTime viewMonth;
  final List<EventItem> events;
  final List<TodoItem> todos;
  final List<CalendarTheme> themes;
  final SurlapColors sh;
  final bool showPast;
  final bool hasCircle;
  final List<DayTemplate> applicableTemplates;
  final Map<String, Map<String, dynamic>> dateWidgetValues;
  /// 기록 템플릿(공부 트래커 등) 셀 뱃지: 이모지 + 대표 숫자. 적용 기간에만 채워짐.
  final List<RecordBadge> recordBadges;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  /// 더블탭 → 동그라미 토글.
  /// 선택된 날짜인가 — 테두리로 표시한다.
  final bool isSelected;
  /// 셀 탭 시 날짜 숫자가 액션 시트 헤더로 줌인되는 Hero 전환.
  /// 연속 보기는 같은 날짜가 여러 그리드에 중복 렌더되어 태그가 충돌하므로 끈다.
  final bool heroDateNumber;
  /// 여러 날 이어지는 일정 막대가 위에 겹쳐 그려질 때, 그만큼 셀 내용을 아래로 민다.
  final double topReserve;

  const DayCell({
    super.key,
    required this.date,
    required this.viewMonth,
    required this.events,
    this.todos = const [],
    required this.themes,
    required this.sh,
    required this.showPast,
    this.hasCircle = false,
    this.applicableTemplates = const [],
    this.dateWidgetValues = const {},
    this.recordBadges = const [],
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.heroDateNumber = false,
    this.topReserve = 0,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = du.isSameDay(date, now);
    final isCurrentMonth = date.month == viewMonth.month;
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
    // 공휴일(빨간날)은 일요일과 같은 빨강. 토요일은 파랑.
    final isHol = isHoliday(date);
    final isSun = date.weekday == DateTime.sunday;
    final isSat = date.weekday == DateTime.saturday;

    final dimmed = !isCurrentMonth || (!showPast && isPast && !isToday);

    Color dayNumColor;
    if (isSun || isHol) {
      dayNumColor = sh.sun.withValues(alpha: dimmed ? 0.35 : 1.0);
    } else if (isSat) {
      dayNumColor = sh.sat.withValues(alpha: dimmed ? 0.35 : 1.0);
    } else {
      dayNumColor = dimmed ? sh.ink.withValues(alpha: 0.30) : sh.ink;
    }

    // 오늘: 셀 색칠/원 없이 숫자에 연보라 글로우만. 선택 동그라미: 브랜드 테두리.
    Widget dayNumber = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: hasCircle
          ? BoxDecoration(
              border: Border.all(
                  color: sh.accent.withValues(alpha: dimmed ? 0.3 : 0.7),
                  width: 1.5),
              shape: BoxShape.circle)
          : null,
      child: Text(
        '${date.day}',
        style: AppType.label.copyWith(
          fontSize: 15,
          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          color: dayNumColor,
          shadows: isToday
              ? [
                  // 은은한 연보라 글로우 — 숫자 가독성 유지.
                  Shadow(
                    color: sh.accent.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
    if (heroDateNumber) {
      dayNumber = Hero(
        tag: 'daycell-${du.toDateKey(date)}',
        child: dayNumber,
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          // 기록 템플릿 적용 기간만 옅은 배경 하이라이트. 오늘 칸은 셀 색 변경 없이
          // 숫자의 글로우로만 표현.
          // 선택된 날짜는 옅은 accent 배경으로 표시(탭 = 선택이라는 피드백).
          color: isSelected
              ? sh.accent.withValues(alpha: sh.dark ? 0.16 : 0.10)
              : recordBadges.isNotEmpty
                  ? sh.accent.withValues(alpha: sh.dark ? 0.06 : 0.04)
                  : Colors.transparent,
          // 칸 구분 격자선 — 가로+세로 모두, 또렷하게.
          border: Border(
            bottom: BorderSide(
                color: sh.ink.withValues(alpha: sh.dark ? 0.18 : 0.12),
                width: 1),
            right: BorderSide(
                color: sh.ink.withValues(alpha: sh.dark ? 0.18 : 0.12),
                width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(5, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 숫자(좌측 정렬)
            Align(alignment: Alignment.centerLeft, child: dayNumber),
            const SizedBox(height: 2),
            // 이벤트 + 할 일 + 위젯 (남은 공간 채움, 넘치면 잘라 overflow 방지)
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 멀티데이 막대 자리 확보(연속 보기에서 위에 오버레이됨).
                      if (topReserve > 0) SizedBox(height: topReserve),
                      // 기록 템플릿 뱃지(이모지+대표숫자) — 셀 상단에 1줄, 절대 과밀 X.
                      ..._buildRecordBadges(dimmed),
                      ..._buildEntries(),
                      if (applicableTemplates.isNotEmpty)
                        ..._buildWidgetRows(dimmed),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 이벤트 + 할 일 합쳐 최대 3줄, 초과분은 +N.
  List<Widget> _buildEntries() {
    final visible = events.where((e) => !e.isTimetable).toList();
    final out = <Widget>[];
    int shown = 0;
    for (final e in visible) {
      if (shown >= 3) break;
      out.add(EventChip(item: e, themes: themes, sh: sh));
      shown++;
    }
    for (final t in todos) {
      if (shown >= 3) break;
      out.add(_TodoLine(todo: t, sh: sh));
      shown++;
    }
    final total = visible.length + todos.length;
    if (total > shown) {
      out.add(Text('+${total - shown}',
          style: TextStyle(fontSize: 9, color: sh.inkSoft)));
    }
    return out;
  }

  // 기록 템플릿 뱃지: 아이콘 1개 + 대표 숫자 1개. 기록 없으면 흐리게(=기록 안 함).
  List<Widget> _buildRecordBadges(bool dimmed) {
    if (recordBadges.isEmpty) return const [];
    final out = <Widget>[];
    for (final b in recordBadges) {
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Opacity(
          opacity: dimmed ? 0.5 : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘은 셀 색(accent) 따름 / 기록 없으면 흐리게. 이모지는 폴백.
              recordGlyph(b.emoji,
                  size: 13, color: sh.accent, faint: !b.hasData),
              if (b.hasData) ...[
                const SizedBox(width: 3),
                Text(b.primaryText!,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      color: sh.accent,
                    )),
              ],
            ],
          ),
        ),
      ));
    }
    return out;
  }

  List<Widget> _buildWidgetRows(bool dimmed) {
    final rows = <Widget>[];
    for (final tpl in applicableTemplates) {
      final tplValues = dateWidgetValues[tpl.id] ?? {};
      for (final field in tpl.fields) {
        final value = tplValues[field.id];
        // skip fields with no value in compact mode
        final hasVal = value != null &&
            value != '' &&
            !(value is List && value.isEmpty) &&
            !(value is Map && value.isEmpty);
        if (!hasVal) continue;
        final w = WidgetCellRenderer(
          field: field,
          value: value,
          sh: sh,
          compact: true,
        );
        rows.add(Opacity(opacity: dimmed ? 0.5 : 1.0, child: w));
        if (rows.length >= 3) break; // max 3 rows in compact cell
      }
      if (rows.length >= 3) break;
    }
    return rows;
  }
}

// 월간 셀의 할 일 한 줄: 우선순위 점 + 제목(완료 시 취소선).
class _TodoLine extends StatelessWidget {
  final TodoItem todo;
  final SurlapColors sh;
  const _TodoLine({required this.todo, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Icon(
            todoStatusIcon(todo.status),
            size: 9,
            color: todo.done
                ? sh.inkFaint
                : todoStatusColor(todo.status, todo.priority, sh),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              todo.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: todo.done ? sh.inkFaint : sh.ink,
                decoration:
                    todo.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
