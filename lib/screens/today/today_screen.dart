import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar/calendar_item.dart';
import '../../core/calendar/calendar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../core/utils/todo_style.dart';
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../models/todo_item.dart';
import '../../modals/add_edit_event_modal.dart';
import '../../modals/add_todo_modal.dart';
import '../../modals/record_entry_sheet.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../providers/record_templates_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/view_provider.dart';
import '../../supabase/neis_service.dart' show NeisSchool;
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/source_badge.dart';
import '../search_view.dart';

/// 오늘 화면 — "지금 뭘 해야 하지?" 하나에 답한다.
///
/// 정보 우선순위: 지금 → 다음 일정 → 오늘 할 일 → 학교 → 오늘 기록.
/// 카드를 나열하지 않고 **지금 진행 중인 것**을 히어로로 올린다. 진행 중인
/// 것이 없으면 다음 일정이 그 자리를 차지한다.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 남은 시간·진행 상태가 실시간으로 줄어들어야 히어로가 의미를 갖는다.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = du.toDateKey(now);
    final dayItems = ref.watch(calendarDayProvider(todayKey));

    final ongoing = dayItems.where((i) => i.isOngoingAt(now)).toList();
    final upcoming = dayItems
        .where((i) => !i.allDay && i.startAt.isAfter(now))
        .toList();
    final todos = ref.watch(todosProvider).where((t) => t.dateKey == todayKey).toList()
      ..sort(_byPriority);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.sm, Gap.lg, kBottomNavClearance),
      children: [
        _Greeting(now: now),
        const SizedBox(height: Gap.lg),

        // ── 히어로: 지금 / (없으면) 다음 일정 ──
        if (ongoing.isNotEmpty)
          NowCard(item: ongoing.first, now: now)
        else if (upcoming.isNotEmpty)
          NowCard(item: upcoming.first, now: now, isNext: true)
        else
          const _NothingNowCard(),

        // ── 다음 일정 ──
        if (upcoming.length > (ongoing.isNotEmpty ? 0 : 1)) ...[
          const SizedBox(height: Gap.xl),
          SectionHeader(
            title: tr('다음 일정'),
            actionLabel: tr('캘린더'),
            onAction: () =>
                ref.read(viewProvider.notifier).setTab(AppTab.calendar),
          ),
          for (final item in upcoming.skip(ongoing.isNotEmpty ? 0 : 1).take(4))
            _UpcomingRow(item: item),
        ],

        // ── 할 일 ──
        const SizedBox(height: Gap.xl),
        SectionHeader(
          title: tr('할 일'),
          trailing: todos.isEmpty
              ? null
              : '${todos.where((t) => t.done).length}/${todos.length}',
          actionLabel: tr('전체'),
          onAction: () => ref.read(viewProvider.notifier).setTab(AppTab.todo),
        ),
        if (todos.isEmpty)
          _QuietLine(
            text: tr('오늘 할 일이 없어요'),
            actionLabel: tr('추가'),
            onAction: () => showAddTodoModal(context),
          )
        else
          for (final t in todos.take(4)) _TodoRow(todo: t),

        // ── 학교 ──
        const SizedBox(height: Gap.xl),
        _SchoolSection(dateKey: todayKey),

        // ── 오늘 기록 ──
        const SizedBox(height: Gap.xl),
        _RecordSection(dateKey: todayKey),
      ],
    );
  }

  static int _byPriority(TodoItem a, TodoItem b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    int rank(TodoItem t) => t.hasPriority ? t.priority : 99;
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
  }
}

// ─────────────────────────────────────────────────────────────────────
// 헤더
// ─────────────────────────────────────────────────────────────────────

class _Greeting extends ConsumerWidget {
  final DateTime now;
  const _Greeting({required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i18nd.monthDay(now)} ${i18nd.weekdayShort(now.weekday)}',
                style: AppType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800, color: sh.ink),
              ),
              const SizedBox(height: 2),
              Text(tr(_greetingFor(now.hour)),
                  style: AppType.bodyLarge.copyWith(color: sh.inkSoft)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => showSearchSheet(context),
          icon: Icon(Icons.search_rounded, color: sh.inkSoft),
          tooltip: tr('검색'),
        ),
        IconButton(
          onPressed: () => ref.read(viewProvider.notifier).setTab(AppTab.more),
          icon: Icon(Icons.settings_rounded, color: sh.inkSoft),
          tooltip: tr('더보기'),
        ),
      ],
    );
  }

  static String _greetingFor(int hour) {
    if (hour < 5) return '아직 안 잤네요';
    if (hour < 11) return '좋은 아침이에요';
    if (hour < 17) return '오늘도 화이팅';
    if (hour < 22) return '수고했어요';
    return '오늘 하루 어땠나요';
  }
}

// ─────────────────────────────────────────────────────────────────────
// 히어로
// ─────────────────────────────────────────────────────────────────────

/// 지금 진행 중(또는 곧 시작할) 항목 히어로 카드.
///
/// 라임(`sh.now`)은 여기와 "오늘/현재 시각" 표시에만 쓴다.
class NowCard extends StatelessWidget {
  final CalendarItem item;
  final DateTime now;

  /// 진행 중인 게 없어 "다음 일정"을 히어로로 올린 경우.
  final bool isNext;

  const NowCard({
    super.key,
    required this.item,
    required this.now,
    this.isNext = false,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final accentColor = isNext ? sh.accent : sh.now;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        boxShadow: Shadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                tr(isNext ? '다음' : '지금'),
                style: AppType.eyebrow.copyWith(color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.headlineLarge.copyWith(color: sh.ink),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            _timeRange,
            style: AppType.titleMedium
                .copyWith(color: sh.inkSoft, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  _countdown(context),
                  style: AppType.titleMedium.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SourceBadge(source: item.source, color: item.color),
            ],
          ),
        ],
      ),
    );
  }

  String get _timeRange {
    final start = item.startHhmm ?? '';
    final end = item.endHhmm;
    return end == null ? start : '$start — $end';
  }

  String _countdown(BuildContext context) {
    if (isNext) {
      final mins = item.startAt.difference(now).inMinutes;
      if (mins <= 0) return tr('곧 시작');
      return trf('{0} 후 시작', [_humanize(mins)]);
    }
    final end = item.endAt ?? item.startAt.add(const Duration(minutes: 50));
    final mins = end.difference(now).inMinutes;
    if (mins <= 0) return tr('곧 끝나요');
    return trf('{0} 남음', [_humanize(mins)]);
  }

  static String _humanize(int minutes) {
    if (minutes < 60) return trf('{0}분', [minutes]);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? trf('{0}시간', [h]) : trf('{0}시간 {1}분', [h, m]);
  }
}

class _NothingNowCard extends ConsumerWidget {
  const _NothingNowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: sh.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('지금'), style: AppType.eyebrow.copyWith(color: sh.inkFaint)),
          const SizedBox(height: Gap.md),
          Text(tr('예정된 일정이 없어요'),
              style: AppType.titleLarge.copyWith(color: sh.ink)),
          const SizedBox(height: Gap.xs),
          Text(tr('오늘은 여유가 있네요'),
              style: AppType.bodyLarge.copyWith(color: sh.inkSoft)),
          const SizedBox(height: Gap.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showAddEditEventModal(context,
                  dateKey: du.todayKey()),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(tr('일정 추가')),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 목록 행
// ─────────────────────────────────────────────────────────────────────

class _UpcomingRow extends ConsumerWidget {
  final CalendarItem item;
  const _UpcomingRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return InkWell(
      onTap: item.editable && item.localIndex != null
          ? () => showAddEditEventModal(context,
              dateKey: item.dateKey, editIndex: item.localIndex)
          : null,
      borderRadius: BorderRadius.circular(Radii.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                item.startHhmm ?? '',
                style: AppType.number.copyWith(color: sh.inkSoft),
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
                style: AppType.bodyLarge
                    .copyWith(color: sh.ink, fontWeight: FontWeight.w600),
              ),
            ),
            if (item.source != CalendarSource.local)
              SourceBadge(source: item.source, color: item.color),
          ],
        ),
      ),
    );
  }
}

class _TodoRow extends ConsumerWidget {
  final TodoItem todo;
  const _TodoRow({required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return InkWell(
      onTap: () => showAddTodoModal(context, edit: todo),
      borderRadius: BorderRadius.circular(Radii.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: () =>
                  ref.read(todosProvider.notifier).toggleDone(todo.id),
              iconSize: 22,
              constraints: const BoxConstraints(
                  minWidth: kMinTouch, minHeight: kMinTouch),
              padding: EdgeInsets.zero,
              tooltip: tr(todo.done ? '완료 취소' : '완료'),
              icon: Icon(
                todo.done
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: todo.done ? sh.now : sh.inkFaint,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodyLarge.copyWith(
                  color: todo.done ? sh.inkFaint : sh.ink,
                  decoration: todo.done ? TextDecoration.lineThrough : null,
                  decorationColor: sh.inkFaint,
                ),
              ),
            ),
            if (todo.hasPriority)
              Text(
                'P${todo.priority}',
                style: AppType.labelMedium.copyWith(
                  color: todoPriorityColor(todo.priority, sh),
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 비어 있을 때의 한 줄 안내 — 큰 빈 상태 일러스트 대신 조용하게.
class _QuietLine extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _QuietLine({required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: AppType.bodyLarge.copyWith(color: sh.inkFaint)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 학교 · 기록
// ─────────────────────────────────────────────────────────────────────

class _SchoolSection extends ConsumerWidget {
  final String dateKey;
  const _SchoolSection({required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = NeisSchool.load();
    if (school == null) {
      return _ConnectSchoolPrompt(
        onConnect: () => ref.read(viewProvider.notifier).setTab(AppTab.school),
      );
    }

    final sh = context.sh;
    final neis = ref.watch(neisCacheProvider);
    final di = du.fromDateKey(dateKey).weekday - 1;
    final meal = neis.lunch[di];
    final highlight = ref.watch(nextAcademicHighlightProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: tr('학교'),
          actionLabel: tr('자세히'),
          onAction: () => ref.read(viewProvider.notifier).setTab(AppTab.school),
        ),
        if (meal != null && meal.trim().isNotEmpty) ...[
          Text(tr('오늘 급식'),
              style: AppType.bodySmall.copyWith(color: sh.inkFaint)),
          const SizedBox(height: 2),
          Text(
            meal.replaceAll('\n', ' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.bodyLarge.copyWith(color: sh.ink),
          ),
        ] else
          Text(tr('오늘 급식 정보가 없어요'),
              style: AppType.bodyLarge.copyWith(color: sh.inkFaint)),
        if (highlight != null) ...[
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: Text(highlight.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyLarge.copyWith(
                        color: sh.ink, fontWeight: FontWeight.w600)),
              ),
              Text(
                highlight.daysAway == 0
                    ? tr('D-DAY')
                    : 'D-${highlight.daysAway}',
                style: AppType.number.copyWith(
                  color: highlight.daysAway == 0 ? sh.now : sh.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConnectSchoolPrompt extends StatelessWidget {
  final VoidCallback onConnect;
  const _ConnectSchoolPrompt({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: sh.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('학교를 연결하면\n시간표·급식·학사일정을 자동으로 볼 수 있어요.'),
              style: AppType.bodyLarge.copyWith(color: sh.inkSoft)),
          const SizedBox(height: Gap.md),
          FilledButton(onPressed: onConnect, child: Text(tr('학교 연결'))),
        ],
      ),
    );
  }
}

class _RecordSection extends ConsumerWidget {
  final String dateKey;
  const _RecordSection({required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final templates = ref.watch(activeRecordTemplatesProvider(dateKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: tr('오늘 기록')),
        if (templates.isEmpty)
          _QuietLine(text: tr('기록할 항목이 없어요'))
        else
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final tpl in templates)
                ActionChip(
                  avatar: Text(tpl.emoji),
                  label: Text(trf('{0} 기록하기', [tpl.name])),
                  onPressed: () =>
                      showRecordEntrySheet(context, tpl.id, dateKey),
                  backgroundColor: sh.card2,
                  side: BorderSide(color: sh.border),
                ),
            ],
          ),
      ],
    );
  }
}
