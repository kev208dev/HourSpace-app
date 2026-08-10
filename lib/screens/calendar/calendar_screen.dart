import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/view_provider.dart';
import '../../widgets/arrow_pinch.dart';
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
        Expanded(
          child: switch (view.calendarMode) {
            CalendarViewMode.month =>
              continuous ? const ContinuousWeekView() : const MonthView(),
            CalendarViewMode.threeDay => const PlannerView(),
            CalendarViewMode.day => DayView(dateKey: view.selectedDay),
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
              style: AppType.labelMedium.copyWith(
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
                      boxShadow: mode == current ? Shadows.subtle : null,
                    ),
                    child: Text(
                      tr(mode.label),
                      style: AppType.bodyMedium.copyWith(
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
