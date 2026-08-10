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
import '../../modals/event_detail_sheet.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/user_type_provider.dart';
import '../../providers/view_provider.dart';
import '../../supabase/neis_service.dart' show NeisSchool;
import '../../widgets/bottom_nav_bar.dart';
import '../search_view.dart';

/// 홈 · 오늘 (핸드오프 B1 · spec §5).
///
/// 오늘 하루 요약을 위에서 아래로: 날짜 헤더 → 이번 주 스트립 → 오늘 일정 수와
/// 가장 가까운 학사일정 → 다가오는 일정 → 할 일 → 오늘 급식 → 다가오는 생일.
///
/// 정렬 규칙(핸드오프):
///  - 시간 일정: 내 일정 + 반복 생성분을 시작 시각순
///  - 할 일: 미완료 → 완료, 그다음 우선순위, 생성 시각순
///  - 생일: 다음 생일이 가까운 순 최대 4건
/// 지난 시각의 일정은 opacity 0.45 로 감쇠한다.
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
    // 지난 일정 감쇠와 "다가오는" 판정이 시간에 따라 바뀐다.
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
    final sh = context.sh;
    final now = DateTime.now();
    final todayKey = du.toDateKey(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.md, Gap.lg, kBottomNavClearance + Gap.xl),
      children: [
        _Header(now: now),
        const SizedBox(height: Gap.md),
        _WeekStrip(now: now),
        const SizedBox(height: Gap.lg),
        _StatsRow(dateKey: todayKey),
        _SectionHeading(tr('다가오는 일정')),
        _Upcoming(dateKey: todayKey, now: now),
        _SectionHeading(tr('할 일')),
        _TodoList(dateKey: todayKey),
        _SectionHeading(tr('오늘 급식')),
        _Meal(now: now),
        _SectionHeading(tr('다가오는 생일')),
        _Birthdays(now: now),
        SizedBox(height: Gap.lg, child: ColoredBox(color: sh.bg)),
      ],
    );
  }
}

/// 섹션 제목 — 17px / 700, 위 space-6 아래 space-2.
class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.sm),
        child: Text(text,
            style: AppType.section.copyWith(color: context.sh.ink)),
      );
}

// ─────────────────────────────────────────────────────────────────────
// 헤더 · 주 스트립
// ─────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final DateTime now;
  const _Header({required this.now});

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
                '${now.year}년 ${now.month}월 ${now.day}일 '
                '${i18nd.weekdayShort(now.weekday)}요일',
                style: AppType.sub.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sh.ink.withValues(alpha: 0.48),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${now.month}월 ${now.day}일',
                style: AppType.display.copyWith(
                  fontSize: 34,
                  letterSpacing: -1.02,
                  color: sh.ink,
                ),
              ),
            ],
          ),
        ),
        _IconBtn(
          icon: Icons.search_rounded,
          onTap: () => showSearchSheet(context),
          tooltip: tr('검색'),
        ),
        _IconBtn(
          icon: Icons.bolt_rounded,
          onTap: () => showAddEditEventModal(context, dateKey: du.todayKey()),
          tooltip: tr('빠른 추가'),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn(
      {required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 21, color: context.sh.ink),
          ),
        ),
      );
}

/// 이번 주 스트립 — 오늘은 라임 원, 항목 있는 날은 accent 점.
class _WeekStrip extends ConsumerWidget {
  final DateTime now;
  const _WeekStrip({required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final byDate = ref.watch(calendarItemsByDateProvider);
    // 오늘을 기준으로 앞뒤를 채워 이번 주를 만든다(월요일 시작).
    final back = now.weekday - 1;
    final start = DateTime(now.year, now.month, now.day - back);

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _WeekDay(
              date: DateTime(start.year, start.month, start.day + i),
              today: now,
              hasItems:
                  (byDate[du.toDateKey(DateTime(start.year, start.month, start.day + i))] ??
                          const [])
                      .isNotEmpty,
              sh: sh,
            ),
          ),
      ],
    );
  }
}

class _WeekDay extends ConsumerWidget {
  final DateTime date;
  final DateTime today;
  final bool hasItems;
  final SurlapColors sh;

  const _WeekDay({
    required this.date,
    required this.today,
    required this.hasItems,
    required this.sh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = du.isSameDay(date, today);
    return InkWell(
      onTap: () =>
          ref.read(viewProvider.notifier).openThreeDay(du.toDateKey(date)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(
              i18nd.weekdayShort(date.weekday),
              style: AppType.label.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: sh.ink.withValues(alpha: 0.48)),
            ),
            const SizedBox(height: 5),
            Container(
              width: 33,
              height: 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? sh.now : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: AppType.button.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isToday ? sh.onNow : sh.ink,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: hasItems && !isToday ? sh.accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 오늘 일정 수 · 가장 가까운 학사일정
// ─────────────────────────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  final String dateKey;
  const _StatsRow({required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final localCount = ref
        .watch(calendarDayProvider(dateKey))
        .where((i) => i.source == CalendarSource.local)
        .length;
    final acad = ref.watch(nextAcademicHighlightProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('오늘 내 일정'),
                  style: AppType.label.copyWith(
                      color: sh.ink.withValues(alpha: 0.45))),
              const SizedBox(height: 3),
              RichText(
                text: TextSpan(
                  style: AppType.display.copyWith(fontSize: 28, color: sh.ink),
                  children: [
                    TextSpan(text: '$localCount'),
                    TextSpan(
                        text: tr('건'),
                        style: AppType.body.copyWith(
                            fontSize: 14, color: sh.ink)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Gap.lg),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('가장 가까운 학사일정'),
                  style: AppType.label.copyWith(color: sh.accent)),
              const SizedBox(height: 3),
              if (acad == null)
                Text(tr('예정된 학사일정이 없습니다.'),
                    style: AppType.sub
                        .copyWith(color: sh.ink.withValues(alpha: 0.45)))
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      acad.daysAway == 0 ? tr('D-DAY') : 'D-${acad.daysAway}',
                      style: AppType.display
                          .copyWith(fontSize: 28, color: sh.accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(acad.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppType.body.copyWith(fontSize: 14, color: sh.ink)),
                    ),
                  ],
                ),
                Text(
                  _whenLabel(acad.dateKey),
                  style: AppType.caption
                      .copyWith(color: sh.ink.withValues(alpha: 0.45)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _whenLabel(String dateKey) {
    try {
      final d = du.fromDateKey(dateKey);
      return '${d.month}월 ${d.day}일';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// 다가오는 일정
// ─────────────────────────────────────────────────────────────────────

class _Upcoming extends ConsumerWidget {
  final String dateKey;
  final DateTime now;
  const _Upcoming({required this.dateKey, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final timed = ref
        .watch(calendarDayProvider(dateKey))
        .where((i) => !i.allDay)
        .toList();

    if (timed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Text(tr('오늘 남은 시간 일정이 없습니다.'),
            style:
                AppType.body.copyWith(color: sh.ink.withValues(alpha: 0.45))),
      );
    }

    return Column(
      children: [
        for (final item in timed) _UpcomingRow(item: item, now: now),
      ],
    );
  }
}

class _UpcomingRow extends ConsumerWidget {
  final CalendarItem item;
  final DateTime now;
  const _UpcomingRow({required this.item, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final past = item.startAt.isBefore(now);
    final editable = item.editable && item.localIndex != null;

    return InkWell(
      onTap: () {
        if (editable) {
          showAddEditEventModal(context,
              dateKey: item.dateKey, editIndex: item.localIndex);
        } else {
          showEventDetailSheet(context, toEventItem(item));
        }
      },
      child: Opacity(
        // 지난 시각 일정은 감쇠.
        opacity: past ? Alpha.past : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color ?? sh.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: Gap.sm),
              SizedBox(
                width: 78,
                child: Text(
                  _timeLabel,
                  style: AppType.sub.copyWith(
                      fontWeight: FontWeight.w600,
                      color: sh.ink.withValues(alpha: 0.62)),
                ),
              ),
              Expanded(
                child: Text(item.title,
                    style: AppType.button.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                        color: sh.ink)),
              ),
              // 읽기 전용 출처는 자물쇠로 표시한다.
              if (!item.editable) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.lock_outline_rounded,
                      size: 13, color: sh.ink.withValues(alpha: 0.40)),
                ),
              ],
              if (item.source != CalendarSource.local) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(tr(item.source.badgeLabel),
                      style: AppType.micro.copyWith(
                          fontWeight: FontWeight.w400,
                          color: sh.ink.withValues(alpha: 0.42))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _timeLabel {
    final start = item.startHhmm ?? '';
    final end = item.endHhmm;
    return end == null ? start : '$start–$end';
  }
}

// ─────────────────────────────────────────────────────────────────────
// 할 일
// ─────────────────────────────────────────────────────────────────────

class _TodoList extends ConsumerWidget {
  final String dateKey;
  const _TodoList({required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    // 오늘 + 날짜 없는 할 일.
    final todos = ref
        .watch(todosProvider)
        .where((t) => t.dateKey == dateKey || t.dateKey == null)
        .toList()
      ..sort(_order);

    if (todos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Text(tr('할 일이 없습니다.'),
            style:
                AppType.body.copyWith(color: sh.ink.withValues(alpha: 0.45))),
      );
    }

    return Column(
      children: [for (final t in todos) _TodoRow(todo: t)],
    );
  }

  /// 미완료 → 완료, 그다음 우선순위, 생성 시각순.
  static int _order(TodoItem a, TodoItem b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    int rank(TodoItem t) => t.hasPriority ? t.priority : 99;
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
  }
}

class _TodoRow extends ConsumerWidget {
  final TodoItem todo;
  const _TodoRow({required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return InkWell(
      onTap: () => ref.read(todosProvider.notifier).toggleDone(todo.id),
      onLongPress: () => showAddTodoModal(context, edit: todo),
      child: Opacity(
        opacity: todo.done ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(todoStatusIcon(todo.status),
                  size: 19,
                  color: todoStatusColor(todo.status, todo.priority, sh)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  todo.title,
                  style: AppType.button.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: sh.ink,
                    decoration:
                        todo.done ? TextDecoration.lineThrough : null,
                    decorationColor: sh.ink.withValues(alpha: 0.45),
                  ),
                ),
              ),
              if (todo.hasPriority) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: todoPriorityColor(todo.priority, sh)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text('P${todo.priority}',
                      style: AppType.micro.copyWith(
                          color: todoPriorityColor(todo.priority, sh))),
                ),
              ],
              SizedBox(
                width: 48,
                child: Text(
                  _dateLabel,
                  textAlign: TextAlign.right,
                  style: AppType.label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: sh.ink.withValues(alpha: 0.42)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _dateLabel {
    final key = todo.dateKey;
    if (key == null) return tr('날짜 없음');
    try {
      final d = du.fromDateKey(key);
      return '${d.month}/${d.day}';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// 오늘 급식 — 미설정 / 불러오는 중 / 정상 / 실패
// ─────────────────────────────────────────────────────────────────────

class _Meal extends ConsumerWidget {
  final DateTime now;
  const _Meal({required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final school = NeisSchool.load();
    final usesMeal = ref.watch(userTypeProvider)?.usesMeal ?? false;

    if (school == null || !usesMeal) {
      return Text(
        tr('학교가 설정되지 않았습니다. 초·중·고 사용자만 급식 정보를 볼 수 있습니다.'),
        style: AppType.body.copyWith(color: sh.ink.withValues(alpha: 0.50)),
      );
    }

    final neis = ref.watch(neisCacheProvider);
    final menu = neis.lunch[now.weekday - 1]?.trim();

    if (menu == null || menu.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: sh.accent2Bg,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.cloud_off_rounded,
                  size: 17, color: sh.accent2Ink),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('급식 정보를 가져오지 못했습니다. 저장된 급식이 없어 표시할 내용이 없습니다.'),
                      style: AppType.body.copyWith(
                          height: 1.5, color: sh.accent2Ink)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () =>
                        ref.read(neisCacheProvider.notifier).refresh(),
                    child: Text(tr('다시 시도'),
                        style: AppType.sub.copyWith(
                          color: sh.accent2Ink,
                          decoration: TextDecoration.underline,
                          decorationColor: sh.accent2Ink,
                        )),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final items = menu
        .split(RegExp(r'[\n·,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: sh.card2,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(m, style: AppType.body.copyWith(color: sh.ink)),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 다가오는 생일 — 가까운 순 최대 4건
// ─────────────────────────────────────────────────────────────────────

class _Birthdays extends ConsumerWidget {
  final DateTime now;
  const _Birthdays({required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final list = ref.watch(birthdaysProvider).toList()
      ..sort((a, b) => a.daysUntilNext(now).compareTo(b.daysUntilNext(now)));
    final upcoming = list.take(4).toList();

    if (upcoming.isEmpty) {
      return Text(tr('등록된 생일이 없습니다.'),
          style: AppType.body.copyWith(color: sh.ink.withValues(alpha: 0.45)));
    }

    return Column(
      children: [
        for (final b in upcoming)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.button.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: sh.ink)),
                ),
                if (b.year != null) ...[
                  Text('${now.year - b.year!}세',
                      style: AppType.caption
                          .copyWith(color: sh.ink.withValues(alpha: 0.42))),
                  const SizedBox(width: 10),
                ],
                SizedBox(
                  width: 64,
                  child: Text('${b.month}월 ${b.day}일',
                      style: AppType.sub
                          .copyWith(color: sh.ink.withValues(alpha: 0.55))),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    b.daysUntilNext(now) == 0
                        ? tr('오늘')
                        : 'D-${b.daysUntilNext(now)}',
                    textAlign: TextAlign.right,
                    style: AppType.sub.copyWith(
                        fontWeight: FontWeight.w600, color: sh.accent),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
