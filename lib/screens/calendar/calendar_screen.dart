import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar/calendar_item.dart';
import '../../core/calendar/calendar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/view_provider.dart';
import '../../modals/add_edit_event_modal.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/arrow_pinch.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/source_badge.dart';
import '../../widgets/calendar_filter_strip.dart';
import '../day_view/day_view.dart';
import '../month_view/continuous_week_view.dart';
import '../month_view/month_view.dart';
import '../planner_view/planner_view.dart';
import '../search_view.dart';
import '../year_view/year_view.dart';

/// 캘린더 탭 — 월 / 3일 / 하루가 **같은 화면의 보기 방식**이다.
///
/// 예전에는 월간·주간·일간·연간이 각각 독립 화면처럼 동작했고 헤더도 화면마다
/// 따로 있었다. 이제 헤더(제목·이동 화살표·보기 전환·필터칩)는 여기 한 곳에만
/// 있고, 아래 본문만 보기 방식에 따라 바뀐다.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewProvider);
    final continuous = ref.watch(settingsProvider).continuousView;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CalendarHeader(),
        const CalendarFilterStrip(),
        if (view.calendarMode == CalendarViewMode.month) ...[
          // 월간에서는 날짜를 고르면 아래 아젠다가 갱신된다 — 다른 화면으로
          // 튕겨 나가지 않는다(스펙 §7).
          Expanded(
            flex: 3,
            child: continuous ? const ContinuousWeekView() : const MonthView(),
          ),
          Expanded(flex: 2, child: DayAgenda(dateKey: view.selectedDay)),
        ] else
          Expanded(
            child: switch (view.calendarMode) {
              CalendarViewMode.threeDay => const PlannerView(),
              _ => DayView(dateKey: view.selectedDay),
            },
          ),
      ],
    );
  }
}

/// 월간 그리드 아래 아젠다 — 선택된 날짜의 모든 소스를 시간순으로.
class DayAgenda extends ConsumerWidget {
  final String dateKey;
  const DayAgenda({super.key, required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final items = ref.watch(calendarDayProvider(dateKey));
    final date = du.fromDateKey(dateKey);
    final isToday = du.isSameDay(date, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xs),
          child: Row(
            children: [
              Text(
                '${i18nd.monthDay(date)} ${i18nd.weekdayShort(date.weekday)}',
                style: AppType.cardTitle.copyWith(
                    color: sh.ink, fontWeight: FontWeight.w800),
              ),
              if (isToday) ...[
                const SizedBox(width: Gap.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: sh.nowBg,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(tr('오늘'),
                      style: AppType.label.copyWith(
                          color: sh.now, fontWeight: FontWeight.w800)),
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: () =>
                    showAddEditEventModal(context, dateKey: dateKey),
                icon: Icon(Icons.add_rounded, color: sh.accent),
                tooltip: tr('일정 추가'),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? AppEmptyState(
                  icon: Icons.event_available_rounded,
                  title: tr('일정이 없어요'),
                  actionText: tr('일정 추가'),
                  onAction: () =>
                      showAddEditEventModal(context, dateKey: dateKey),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, 0, Gap.lg, kBottomNavClearance),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _AgendaRow(item: items[i]),
                ),
        ),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final CalendarItem item;
  const _AgendaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return InkWell(
      onTap: item.editable && item.localIndex != null
          ? () => showAddEditEventModal(context,
              dateKey: item.dateKey, editIndex: item.localIndex)
          : null,
      borderRadius: BorderRadius.circular(Radii.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                item.startHhmm ?? tr('종일'),
                style: AppType.sub.copyWith(color: sh.inkSoft),
              ),
            ),
            Container(
              width: 3,
              height: 18,
              margin: const EdgeInsets.only(right: Gap.md),
              decoration: BoxDecoration(
                color: item.color ?? sh.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body
                    .copyWith(color: sh.ink, fontWeight: FontWeight.w600),
              ),
            ),
            SourceBadge(source: item.source, color: item.color),
          ],
        ),
      ),
    );
  }
}

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewProvider);
    final notifier = ref.read(viewProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xs),
          child: Row(
            children: [
              Expanded(child: _Title(view: view)),
              ArrowPinch(
                onPrev: () => notifier.step(-1),
                onNext: () => notifier.step(1),
              ),
              const SizedBox(width: 2),
              _OverflowMenu(
                onSearch: () => showSearchSheet(context),
                onToday: notifier.goToToday,
                onYear: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _YearPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.sm),
          child: CalendarModeSegment(),
        ),
      ],
    );
  }
}

/// 헤더 제목. 월간은 연·월, 3일/하루는 선택된 날짜를 보여준다.
/// 탭하면 오늘로 돌아온다.
class _Title extends ConsumerWidget {
  final ViewState view;
  const _Title({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final selected = du.fromDateKey(view.selectedDay);
    final isMonth = view.calendarMode == CalendarViewMode.month;
    final headline =
        isMonth ? i18nd.monthName(view.viewMonth) : i18nd.monthDay(selected);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ref.read(viewProvider.notifier).goToToday,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMonth ? '${view.viewYear}' : '${selected.year}',
              style: AppType.label.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: sh.inkSoft,
              ),
            ),
            Text(
              headline,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                height: 1.05,
              ).copyWith(color: sh.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보기 방식 전환 — 월 / 3일 / 하루.
class CalendarModeSegment extends ConsumerWidget {
  const CalendarModeSegment({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final current = ref.watch(viewProvider).calendarMode;
    final notifier = ref.read(viewProvider.notifier);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: sh.border),
      ),
      child: Row(
        children: [
          for (final mode in CalendarViewMode.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == current,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => notifier.setCalendarMode(mode),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    curve: Motion.curve,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mode == current ? sh.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      boxShadow: mode == current ? sh.shadowCard : null,
                    ),
                    child: Text(
                      tr(mode.label),
                      style: AppType.sub.copyWith(
                        fontWeight:
                            mode == current ? FontWeight.w800 : FontWeight.w600,
                        color: mode == current ? sh.accentInk : sh.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onToday;
  final VoidCallback onYear;

  const _OverflowMenu({
    required this.onSearch,
    required this.onToday,
    required this.onYear,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 20, color: sh.inkSoft),
      padding: EdgeInsets.zero,
      tooltip: tr('더보기'),
      color: sh.card,
      onSelected: (v) => switch (v) {
        'search' => onSearch(),
        'today' => onToday(),
        'year' => onYear(),
        _ => null,
      },
      itemBuilder: (_) => [
        _menuItem('search', Icons.search_rounded, tr('검색'), sh),
        _menuItem('today', Icons.today_rounded, tr('오늘로'), sh),
        _menuItem('year', Icons.calendar_view_month_rounded, tr('연간 보기'), sh),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
          String value, IconData icon, String label, SurlapColors sh) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 18, color: sh.inkSoft),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: sh.ink)),
        ]),
      );
}

/// 연간 보기 — 자주 쓰지 않아 탭이 아니라 별도 화면으로 뺐다.
class _YearPage extends ConsumerWidget {
  const _YearPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final view = ref.watch(viewProvider);
    final notifier = ref.read(viewProvider.notifier);
    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        backgroundColor: sh.bg,
        title: Text('${view.viewYear}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: notifier.prevYear,
            tooltip: tr('이전 해'),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: notifier.nextYear,
            tooltip: tr('다음 해'),
          ),
        ],
      ),
      body: const YearView(),
    );
  }
}
