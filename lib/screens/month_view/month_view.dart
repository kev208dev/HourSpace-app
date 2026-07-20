import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../models/event_item.dart';
import '../../models/todo_item.dart';
import '../../providers/view_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/themes_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/extras_provider.dart';
import '../../providers/recurring_events_provider.dart';
import '../../providers/day_widget_provider.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/template_ranges_provider.dart';
import '../../providers/record_templates_provider.dart';
import '../../providers/sports_provider.dart';
import '../../providers/shared_theme_events_provider.dart';
import '../../modals/day_action_sheet.dart';
import '../../widgets/mascot/mascot.dart';
import '../../widgets/long_press_hint_bar.dart';
import 'month_grid.dart';

class MonthView extends ConsumerWidget {
  const MonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewProvider);
    final events = ref.watch(eventsProvider);
    final themes = ref.watch(themesProvider);
    final settings = ref.watch(settingsProvider);
    final hiddenThemes = ref.watch(filterProvider);
    final starred = ref.watch(starredProvider);
    final circles = ref.watch(circlesProvider);
    final widgetValues = ref.watch(widgetValuesProvider);
    final dayTemplates = ref.watch(dayTemplatesProvider);
    final birthdays = ref.watch(birthdaysProvider);
    final todos = ref.watch(todosProvider);
    final templateRanges = ref.watch(templateRangesProvider);
    final templatesById = ref.watch(recordTemplatesByIdProvider);
    final sh = context.sh;

    // 날짜별 할 일 묶음 (날짜 지정된 것만 캘린더에 표시).
    final todosByDate = <String, List<TodoItem>>{};
    for (final t in todos) {
      final k = t.dateKey;
      if (k == null) continue;
      todosByDate.putIfAbsent(k, () => []).add(t);
    }

    final filteredEvents = Map.fromEntries(
      events.entries.map((e) => MapEntry(
        e.key,
        e.value.where((item) {
          if (hiddenThemes.isEmpty) return true;
          final ids = item.themeIds;
          if (ids.isEmpty) return !hiddenThemes.contains('__none__');
          return ids.every((id) => !hiddenThemes.contains(id));
        }).toList(),
      )),
    );

    // Merge birthday events (별도 카테고리 — 필터로 켜고/끔)
    final mergedEvents = Map<String, List<EventItem>>.from(filteredEvents);
    if (!hiddenThemes.contains(birthdayThemeId)) {
      for (final b in birthdays) {
        if (b.month < 1 || b.month > 12 || b.day < 1 || b.day > 31) continue;
        final bKey =
            '${view.viewYear}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}';
        mergedEvents[bKey] = [
          ...(mergedEvents[bKey] ?? []),
          EventItem(t: b.name, th: birthdayThemeId, birthday: true),
        ];
      }
    }
    // Merge NEIS 학사일정 (academic — 읽기 전용 표시, 별도 카테고리로 필터 가능)
    if (!hiddenThemes.contains(academicThemeId)) {
      ref.watch(academicScheduleProvider).forEach((dateKey, names) {
        mergedEvents[dateKey] = [
          ...(mergedEvents[dateKey] ?? []),
          for (final n in names)
            EventItem(t: n, th: academicThemeId, academic: true),
        ];
      });
    }
    // Merge 스포츠 구독 경기 (구독별 필터 — th=구독id).
    ref.watch(sportsEventsByDateProvider).forEach((dateKey, items) {
      final vis = items
          .where((e) => !hiddenThemes.contains(e.themeIds.first))
          .toList();
      if (vis.isEmpty) return;
      mergedEvents[dateKey] = [...(mergedEvents[dateKey] ?? []), ...vis];
    });
    // Merge 구독 중인 공유 테마 일정 (읽기 전용 — th=구독 테마id).
    ref.watch(sharedThemeEventsByDateProvider).forEach((dateKey, items) {
      final vis = items
          .where((e) =>
              e.themeIds.isNotEmpty && !hiddenThemes.contains(e.themeIds.first))
          .toList();
      if (vis.isEmpty) return;
      mergedEvents[dateKey] = [...(mergedEvents[dateKey] ?? []), ...vis];
    });
    // Merge 반복 일정 가상 occurrence — 카테고리 필터 적용(앵커와 동일 themeIds 사용).
    ref.watch(recurringEventsByDateProvider).forEach((dateKey, items) {
      final vis = items.where((e) {
        if (e.themeIds.isEmpty) return true;
        return !hiddenThemes.contains(e.themeIds.first);
      }).toList();
      if (vis.isEmpty) return;
      mergedEvents[dateKey] = [...(mergedEvents[dateKey] ?? []), ...vis];
    });

    // 이 달이 진짜로 비었는지(일정·할일 모두 0건) 판단 — 빈 상태 안내용.
    // 키가 'YYYY-MM-' 로 시작하는 항목이 하나라도 있으면 비어있지 않음.
    final monthPrefix =
        '${view.viewYear}-${view.viewMonth.toString().padLeft(2, '0')}-';
    bool hasAnyInMonth<T>(Map<String, List<T>> byDate) =>
        byDate.entries.any(
            (e) => e.key.startsWith(monthPrefix) && e.value.isNotEmpty);
    final isMonthEmpty =
        !hasAnyInMonth(mergedEvents) && !hasAnyInMonth(todosByDate);

    return Container(
      margin: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: sh.ink.withValues(alpha: 0.04)),
        // 캘린더 카드를 살짝 띄우는 부드러운 그림자(따뜻한 톤).
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: sh.dark ? 0.30 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const LongPressHintBar(),
          Expanded(
            child: Stack(
              children: [
                MonthGrid(
            year: view.viewYear,
            month: view.viewMonth,
            weekStartDow: settings.weekStartDow,
            events: mergedEvents,
            todosByDate: todosByDate,
            themes: themes,
            sh: sh,
            showPast: settings.showPast,
            starred: starred,
            circles: circles,
            dayTemplates: dayTemplates,
            widgetValues: widgetValues,
            templateRanges: templateRanges,
            templatesById: templatesById,
            // 월간: 날짜 탭 → 그 날이 가운데(3일 중)인 주간 뷰로 이동.
            onDayTap: (date) =>
                ref.read(viewProvider.notifier).setWeekView(du.toDateKey(date)),
            // 길게 누르면 추가/액션 시트(일정·할일·위젯·자세히 보기).
            onDayLongPress: (date) => _handleDayTap(context, ref, date),
            // 더블탭 → 동그라미 토글.
            onDayDoubleTap: (date) =>
                ref.read(circlesProvider.notifier).toggle(du.toDateKey(date)),
            heroCells: true,
            cellHeightFactor: settings.monthCellHeightFactor,
          ),
          // 이 달에 아무 데이터도 없으면 친근한 빈 상태를 그리드 위에 띄운다.
          // 날짜 숫자와 겹쳐 안 보이지 않게 불투명 카드 박스로 감싼다.
          // IgnorePointer로 날짜 셀 탭은 그대로 통과시킨다.
          if (isMonthEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    duration: Motion.base,
                    curve: Motion.curve,
                    tween: Tween(begin: 0, end: 1),
                    builder: (_, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * 8),
                        child: child,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 22),
                      decoration: BoxDecoration(
                        color: sh.card,
                        borderRadius: BorderRadius.circular(Radii.card),
                        border: Border.all(
                            color: sh.ink.withValues(alpha: 0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: sh.dark ? 0.4 : 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MascotView(
                              expression: MascotExpression.happy,
                              size: 84,
                              showStars: false),
                          const SizedBox(height: 14),
                          Text(tr('이 달은 아직 비어 있어요'),
                              textAlign: TextAlign.center,
                              style: AppType.bodyLarge.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: sh.ink)),
                          const SizedBox(height: 6),
                          Text(tr('아래 + 버튼을 누르거나,\n날짜를 길게 눌러 일정을 추가해 보세요'),
                              textAlign: TextAlign.center,
                              style: AppType.labelMedium.copyWith(
                                  fontSize: 13,
                                  color: sh.inkSoft,
                                  height: 1.45)),
                        ],
                      ),
                    ),
                  ),
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

  void _handleDayTap(
      BuildContext context, WidgetRef ref, DateTime date) {
    showDayActionSheet(context, du.toDateKey(date), date);
  }

}
