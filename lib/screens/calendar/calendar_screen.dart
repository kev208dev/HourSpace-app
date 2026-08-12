import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar/calendar_item.dart';
import '../../core/calendar/calendar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../modals/add_edit_event_modal.dart';
import '../../modals/event_detail_sheet.dart';
import '../../providers/view_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/ui_kit.dart';
import '../day_view/day_view.dart';
import '../planner_view/planner_view.dart';
import '../search_view.dart';
import '../year_view/year_view.dart';
import 'month_grid_view.dart';

/// 캘린더 탭 (핸드오프 C1~C4).
///
/// 연 · 월 · 3일 · 하루가 한 화면의 보기 모드다. 헤더(제목·이동·오늘·검색·
/// 빠른추가 + 모드 세그먼트)는 여기 한 곳에만 있고 아래 본문만 바뀐다.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewProvider).calendarMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CalendarHeader(),
        Expanded(
          child: switch (mode) {
            CalendarViewMode.year => const YearView(),
            CalendarViewMode.month => const MonthGridView(),
            CalendarViewMode.threeDay => const PlannerView(),
            CalendarViewMode.day =>
              DayView(dateKey: ref.watch(viewProvider).selectedDay),
          },
        ),
      ],
    );
  }
}

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final view = ref.watch(viewProvider);
    final n = ref.read(viewProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SurlapIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => n.step(-1),
                tooltip: tr('이전'),
              ),
              Text(_title(view),
                  style: AppType.navTitle.copyWith(color: sh.ink)),
              SurlapIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => n.step(1),
                tooltip: tr('다음'),
              ),
              const Spacer(),
              SurlapButton(
                label: tr('오늘'),
                onTap: n.goToToday,
                kind: SurlapButtonKind.ghost,
                dense: true,
              ),
              SurlapIconButton(
                icon: Icons.search_rounded,
                onTap: () => showSearchSheet(context),
                tooltip: tr('검색'),
              ),
              SurlapIconButton(
                icon: Icons.bolt_rounded,
                onTap: () => showAddEditEventModal(context,
                    dateKey: view.selectedDay),
                tooltip: tr('빠른 추가'),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          const CalendarModeSegment(),
        ],
      ),
    );
  }

  String _title(ViewState v) {
    if (v.calendarMode == CalendarViewMode.year) return '${v.viewYear}년';
    if (v.calendarMode == CalendarViewMode.month) {
      return '${v.viewYear}년 ${v.viewMonth}월';
    }
    final d = du.fromDateKey(v.selectedDay);
    return '${d.month}월 ${d.day}일';
  }
}

/// 보기 모드 세그먼트 — 연 · 월 · 3일 · 하루.
/// 선택은 accent 채움 + bg 글자, 사이는 divider 세로선.
class CalendarModeSegment extends ConsumerWidget {
  const CalendarModeSegment({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(viewProvider).calendarMode;
    final n = ref.read(viewProvider.notifier);
    const modes = CalendarViewMode.values;

    return SurlapSegmentedControl(
      segments: [for (final m in modes) surlapSegment(tr(m.label))],
      index: modes.indexOf(current),
      onChanged: (i) => n.setCalendarMode(modes[i]),
    );
  }
}

/// 월 보기 아래 "선택한 날짜" 목록 (핸드오프 C2).
class SelectedDayList extends ConsumerWidget {
  final String dateKey;
  const SelectedDayList({super.key, required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final items = ref.watch(calendarDayProvider(dateKey));
    final date = du.fromDateKey(dateKey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.lg, Gap.sm, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(tr('선택한 날짜'),
                  style: AppType.label.copyWith(color: sh.accent)),
              const SizedBox(width: Gap.sm),
              Text(
                '${date.month}월 ${date.day}일 '
                '${i18nd.weekdayShort(date.weekday)}',
                style: AppType.body.copyWith(color: sh.ink),
              ),
              const Spacer(),
              SurlapButton(
                label: tr('하루 보기'),
                onTap: () => ref
                    .read(viewProvider.notifier)
                    .setCalendarMode(CalendarViewMode.day),
                kind: SurlapButtonKind.ghost,
                dense: true,
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: SurlapInlineEmptyState(
                  tr('항목이 없어 한 번 더 누르면 바로 이동합니다.')),
            )
          else
            for (final item in items) _SelectedRow(item: item),
        ],
      ),
    );
  }
}

class _SelectedRow extends StatelessWidget {
  final CalendarItem item;
  const _SelectedRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final editable = item.editable && item.localIndex != null;
    return InkWell(
      onTap: () => editable
          ? showAddEditEventModal(context,
              dateKey: item.dateKey, editIndex: item.localIndex)
          : showEventDetailSheet(context, toEventItem(item)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: item.color ?? sh.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 76,
                child: Text(item.startHhmm ?? tr('종일'),
                    style: AppType.sub.copyWith(
                        fontSize: 12,
                        color: sh.ink.withValues(alpha: 0.58))),
              ),
              Expanded(
                child: Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body
                        .copyWith(fontSize: 13.5, color: sh.ink)),
              ),
              if (!item.editable)
                Icon(Icons.lock_outline_rounded,
                    size: 12, color: sh.ink.withValues(alpha: 0.40)),
              const SizedBox(width: 6),
              Text(tr(item.source.badgeLabel),
                  style: AppType.micro.copyWith(
                      fontWeight: FontWeight.w400,
                      color: sh.ink.withValues(alpha: 0.42))),
            ],
          ),
        ),
      ),
    );
  }
}

/// 캘린더 본문의 하단 여백 — 탭바에 가리지 않도록.
const double kCalendarBottomPad = kBottomNavClearance;
