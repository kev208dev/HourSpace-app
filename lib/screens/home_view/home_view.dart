import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.dart';
import '../../i18n/dates.dart' as i18nd;
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../models/event_item.dart';
import '../../models/calendar_theme.dart';
import '../../models/todo_item.dart';
import '../../providers/events_provider.dart';
import '../../providers/themes_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/view_provider.dart';
import '../../providers/recurring_events_provider.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/user_type_provider.dart';
import '../../core/utils/todo_style.dart';
import '../../supabase/neis_service.dart';
import '../../modals/add_todo_modal.dart';
import '../../modals/birthday_manager_modal.dart';
import '../../modals/neis_setup_modal.dart';
import '../../modals/add_edit_event_modal.dart';
import '../../modals/event_detail_sheet.dart';
import '../../widgets/mascot/mascot.dart';
import '../../widgets/mascot/mascot_feedback.dart';
import '../../widgets/pressable.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  SchoolMeals? _meals;
  bool _mealLoaded = false;
  bool _mealError = false; // fetch 실패(네트워크 등) — 미연결과 구분

  @override
  void initState() {
    super.initState();
    _loadMeal();
  }

  Future<void> _loadMeal() async {
    final school = NeisSchool.load();
    if (school == null) {
      setState(() {
        _mealLoaded = true;
        _mealError = false;
      });
      return;
    }
    setState(() {
      _mealLoaded = false;
      _mealError = false;
    });
    final dateStr = du.toDateKey(DateTime.now()).replaceAll('-', '');
    try {
      final meals = await fetchMeals(school, dateStr);
      if (mounted) {
        setState(() {
          _meals = meals;
          _mealLoaded = true;
        });
      }
    } catch (e, st) {
      debugPrint('[Home] 급식 불러오기 실패: $e\n$st');
      if (mounted) {
        setState(() {
          _mealLoaded = true;
          _mealError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final now = DateTime.now();
    final todayKey = du.toDateKey(now);
    final events = ref.watch(eventsProvider);
    final themes = ref.watch(themesProvider);
    final notifier = ref.read(viewProvider.notifier);

    final userType = ref.watch(userTypeProvider);
    final showMeal =
        userType == null || userType.usesMeal || NeisSchool.load() != null;

    final recurringToday =
        ref.watch(recurringEventsByDateProvider)[todayKey] ?? const [];
    final todayAll = [
      ...(events[todayKey] ?? []).where((e) => !e.isTimetable),
      ...recurringToday,
    ];

    final todayTodos = ref
        .watch(todosProvider)
        .where((t) => t.dateKey == todayKey || t.dateKey == null)
        .toList()
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        int rank(TodoItem t) => t.hasPriority ? t.priority : 99;
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : (a.createdAt ?? '').compareTo(b.createdAt ?? '');
      });

    final upcoming = todayAll.where((e) {
      if (!e.hasTime) return false;
      final parts = e.tm!.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return h > now.hour || (h == now.hour && m > now.minute);
    }).toList()
      ..sort((a, b) => (a.tm ?? '').compareTo(b.tm ?? ''));

    // 오늘 부담 정도 → 인사 옆 마스코트 표정.
    final busy = todayAll.length + todayTodos.where((t) => !t.done).length;
    final greetMascot = busy == 0
        ? MascotExpression.sleepy
        : busy >= 4
            ? MascotExpression.cheering
            : MascotExpression.happy;

    final upcomingBirthdays = [...ref.watch(birthdaysProvider)]
      ..sort((a, b) => a.daysUntilNext().compareTo(b.daysUntilNext()));

    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekKeys = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return du.toDateKey(d);
    });
    final weekEventCounts = {
      for (final k in weekKeys)
        k: (events[k] ?? []).where((e) => !e.isTimetable).length
    };

    // 하단 네비/FAB와 겹치지 않도록 충분한 여백.
    final bottomPad = 150.0 + MediaQuery.of(context).padding.bottom;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildGreeting(sh, now, greetMascot)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, bottomPad),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── 다음 일정 (중간 강조, full-width) ──
              _NextEventCard(
                sh: sh,
                upcoming: upcoming,
                allToday: todayAll,
                themes: themes,
                now: now,
                onTap: () => notifier.setDayView(todayKey),
                onTapEvent: (e) {
                  // 사용자 편집 가능 일정(반복 가상·sport·academic 제외)이면 편집 모달, 아니면 상세 시트.
                  final list = events[todayKey] ?? const <EventItem>[];
                  final idx = list.indexWhere((it) => it.id != null && it.id == e.id);
                  if (idx >= 0 && !e.academic && !e.birthday && !e.sport) {
                    showAddEditEventModal(context, dateKey: todayKey, editIndex: idx);
                  } else {
                    showEventDetailSheet(context, e);
                  }
                },
              ),
              const SizedBox(height: _cardGap),
              // ── 오늘 할 일 (중간 강조, full-width) ──
              _TodayTodosCard(
                sh: sh,
                todos: todayTodos,
                onToggle: (id) {
                  // 진행중(1) → 완료(2)로 넘어갈 때만 응원.
                  final willComplete = ref
                      .read(todosProvider)
                      .any((t) => t.id == id && t.status == 1);
                  ref.read(todosProvider.notifier).toggleDone(id);
                  if (willComplete) {
                    MascotToast.success(context, tr('좋아요! 하나 끝냈어요'));
                  }
                },
                onTapTodo: (t) => showAddTodoModal(context, edit: t),
              ),
              const SizedBox(height: _cardGap),
              // ── 보조 카드 2열: 급식 + 오늘 일정 ──
              if (showMeal)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Builder(builder: (_) {
                          final neis = ref.watch(neisCacheProvider);
                          final di = now.weekday - 1;
                          final cached =
                              (di >= 0 && di <= 6) ? neis.lunch[di] : null;
                          final meals = _meals ??
                              (cached != null
                                  ? SchoolMeals(lunch: cached)
                                  : null);
                          return _MealCard(
                            sh: sh,
                            meals: meals,
                            loaded: _mealLoaded || cached != null,
                            error: _mealError && cached == null,
                            onRetry: _loadMeal,
                          );
                        }),
                      ),
                      const SizedBox(width: _cardGap),
                      Expanded(
                        child: _TodayStatsCard(
                          sh: sh,
                          count: todayAll.length,
                          onTap: () => notifier.setDayView(todayKey),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _TodayStatsCard(
                  sh: sh,
                  count: todayAll.length,
                  onTap: () => notifier.setDayView(todayKey),
                ),
              if (upcomingBirthdays.isNotEmpty) ...[
                const SizedBox(height: _cardGap),
                _UpcomingBirthdaysCard(
                  sh: sh,
                  birthdays: upcomingBirthdays.take(4).toList(),
                  onTap: () => showBirthdayManagerModal(context),
                ),
              ],
              Builder(builder: (_) {
                final hi = ref.watch(nextAcademicHighlightProvider);
                if (hi == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: _cardGap),
                  child: _AcademicDDayCard(sh: sh, highlight: hi),
                );
              }),
              const SizedBox(height: _cardGap),
              _WeekStripCard(
                sh: sh,
                monday: monday,
                weekKeys: weekKeys,
                eventCounts: weekEventCounts,
                today: todayKey,
                onDayTap: (key) =>
                    ref.read(viewProvider.notifier).setWeekView(key),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting(
      SurlapColors sh, DateTime now, MascotExpression mascot) {
    final hour = now.hour;
    final greeting = hour < 6
        ? tr('늦은 밤이에요')
        : hour < 12
            ? tr('좋은 아침이에요')
            : hour < 18
                ? tr('좋은 오후예요')
                : tr('좋은 저녁이에요');

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작은 도트로 강조 — 대기업 dashboard 헤더 패턴.
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: sh.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: sh.accent.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(greeting,
                        style: AppType.eyebrow.copyWith(
                            fontSize: 11.5,
                            color: sh.accent)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  i18nd.fullDate(now),
                  style: AppType.titleLarge.copyWith(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: sh.ink,
                      height: 1.15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 인사 옆 마스코트(카드 없이 캐릭터만).
          MascotView(expression: mascot, size: 76),
        ],
      ),
    );
  }
}

// ─── 홈 공통 스타일 ───────────────────────────────────────────────
const double _cardGap = 14;
const double _cardRadius = 22;

BoxDecoration _softCard(SurlapColors sh,
        {Color? color, double radius = _cardRadius, Color? border}) =>
    BoxDecoration(
      color: color ?? sh.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: border ?? sh.accent.withValues(alpha: sh.dark ? 0.16 : 0.10)),
      boxShadow: [
        // 빛나는 보라 글로우 — 카드가 다크 퍼플 위에서 은은히 떠 보이게.
        BoxShadow(
          color: sh.accent.withValues(alpha: sh.dark ? 0.16 : 0.10),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    );

/// 통일된 line-icon 배지 + 라벨(카드 헤더).
Widget _iconBadge(SurlapColors sh, IconData icon, String label,
    {Color? color}) {
  final c = color ?? sh.accent;
  return Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: c.withValues(alpha: sh.dark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: c),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: AppType.labelMedium.copyWith(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: sh.inkSoft)),
    ],
  );
}

/// 카드 안 라인 아이콘 빈 상태(마스코트 대신 통일된 아이콘).
Widget _emptyNote(SurlapColors sh, String title, String? sub) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: AppType.bodyLarge.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: sh.inkSoft)),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(sub,
                style: AppType.labelMedium.copyWith(
                    fontSize: 12.5, color: sh.inkFaint, height: 1.35)),
          ],
        ],
      ),
    );

// ─── 다음 일정 카드 ──────────────────────────────────────────────
class _NextEventCard extends StatelessWidget {
  final SurlapColors sh;
  final List<EventItem> upcoming;
  final List<EventItem> allToday;
  final List<CalendarTheme> themes;
  final DateTime now;
  final VoidCallback onTap;
  /// 카드 안의 "다음 일정" 자체를 누르면 그 일정 상세로 이동.
  /// 다음 일정이 없을 때는 카드 자체 onTap(데이뷰)로 동작.
  final void Function(EventItem)? onTapEvent;

  const _NextEventCard({
    required this.sh,
    required this.upcoming,
    required this.allToday,
    required this.themes,
    required this.now,
    required this.onTap,
    this.onTapEvent,
  });

  @override
  Widget build(BuildContext context) {
    final hasNext = upcoming.isNotEmpty;
    final next = hasNext ? upcoming.first : null;
    final themeColor = next != null ? _resolveColor(next) : null;
    final accent = themeColor ?? sh.accent;

    final hero = hasNext;
    final heroTextColor = hero ? Colors.white : sh.ink;
    final heroSubColor = hero ? Colors.white.withValues(alpha: 0.75) : sh.inkSoft;
    return Pressable(
      onTap: hasNext && onTapEvent != null ? () => onTapEvent!(next!) : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: hero
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: sh.accentGrad,
                )
              : null,
          color: hero ? null : sh.card,
          borderRadius: BorderRadius.circular(28),
          border: hero
              ? null
              : Border.all(color: sh.ink.withValues(alpha: 0.06)),
          boxShadow: hero
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A1FD0).withValues(alpha: 0.6),
                    blurRadius: 44,
                    offset: const Offset(0, 20),
                    spreadRadius: -16,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: -16,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 히어로 일 때 흰 톤, 비히어로일 때 accent 톤.
                Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: hero
                          ? Colors.white.withValues(alpha: 0.22)
                          : accent.withValues(alpha: sh.dark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.bolt_rounded,
                        size: 17, color: hero ? Colors.white : accent),
                  ),
                  const SizedBox(width: 8),
                  Text(tr('다음 일정'),
                      style: AppType.labelMedium.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: heroSubColor)),
                ]),
                const Spacer(),
                if (allToday.length > 1)
                  Text(trf('오늘 {0}개', [allToday.length]),
                      style: AppType.labelMedium
                          .copyWith(fontSize: 12, color: heroSubColor)),
              ],
            ),
            const SizedBox(height: 12),
            if (hasNext) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      next!.t,
                      style: AppType.titleLarge.copyWith(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: heroTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 22, color: Colors.white),
                  ),
                ],
              ),
              if (next.tm != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: heroSubColor),
                    const SizedBox(width: 5),
                    Text(
                      _startDesc(next),
                      style: AppType.bodyLarge.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: heroSubColor),
                    ),
                  ],
                ),
              ],
            ] else
              _emptyNote(
                sh,
                allToday.isEmpty ? tr('오늘 예정된 일정이 없어요') : tr('남은 일정이 없어요'),
                tr('새 일정을 추가하면 이곳에 표시돼요'),
              ),
          ],
        ),
      ),
    );
  }

  // "15:30 · 2시간 후 시작" 형태의 보조 설명.
  String _startDesc(EventItem e) {
    final tm = e.tm!;
    final parts = tm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final start = DateTime(now.year, now.month, now.day, h, m);
    final diff = start.difference(now);
    final mins = diff.inMinutes;
    String rel;
    if (mins <= 0) {
      rel = tr('곧 시작');
    } else if (mins < 60) {
      rel = trf('{0}분 후 시작', [mins]);
    } else {
      final hh = diff.inHours;
      final mm = mins % 60;
      rel = mm == 0 ? trf('{0}시간 후 시작', [hh]) : trf('{0}시간 {1}분 후 시작', [hh, mm]);
    }
    final range = e.te != null ? '$tm ~ ${e.te}' : tm;
    return '$range · $rel';
  }

  Color? _resolveColor(EventItem e) {
    final ids = e.themeIds;
    if (ids.isEmpty) return null;
    try {
      return themes.firstWhere((t) => ids.contains(t.id)).colorValue;
    } catch (_) {
      return null;
    }
  }
}

// ─── 급식 카드 ───────────────────────────────────────────────────
class _MealCard extends StatelessWidget {
  final SurlapColors sh;
  final SchoolMeals? meals;
  final bool loaded;
  final bool error;
  final VoidCallback onRetry;

  const _MealCard({
    required this.sh,
    required this.meals,
    required this.loaded,
    required this.error,
    required this.onRetry,
  });

  // (라벨, 아이콘, 메뉴) — 있는 끼니만.
  List<(String, IconData, String)> get _sections {
    final m = meals;
    if (m == null) return const [];
    return [
      if (m.breakfast != null)
        (tr('조식'), Icons.wb_twilight_rounded, m.breakfast!),
      if (m.lunch != null) (tr('중식'), Icons.restaurant_rounded, m.lunch!),
      if (m.dinner != null) (tr('석식'), Icons.nightlight_round, m.dinner!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    // 끼니가 1개뿐이면 라벨 없이, 여러 개면(기숙사) 라벨로 구분.
    final multi = sections.length > 1;
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: _softCard(sh, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBadge(sh, Icons.restaurant_rounded, tr('오늘 급식')),
          const SizedBox(height: 12),
          if (!loaded)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (sections.isNotEmpty)
            ...sections.map((s) => _mealSection(s.$1, s.$2, s.$3, multi))
          else if (NeisSchool.load() == null)
            _LinkLine(
              sh: sh,
              text: tr('학교 미연결'),
              action: tr('학교 연결하기'),
              onTap: () => showNeisSetupModal(context),
            )
          else if (error)
            _LinkLine(
              sh: sh,
              text: tr('급식 정보를 불러오지 못했어요'),
              action: tr('다시 시도'),
              onTap: onRetry,
            )
          else
            _emptyNote(sh, tr('오늘 급식 정보가 없어요'), null),
        ],
      ),
    );
  }

  Widget _mealSection(String label, IconData icon, String menu, bool multi) {
    final items = menu
        .split(RegExp(r'[\n*]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: multi ? 10 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (multi)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(icon, size: 13, color: sh.accent),
                const SizedBox(width: 5),
                Text(label,
                    style: AppType.labelMedium.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: sh.accent)),
              ]),
            ),
          ...items.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(m,
                    style: AppType.bodyLarge.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sh.ink,
                        height: 1.3)),
              )),
        ],
      ),
    );
  }
}

// 텍스트 + 작은 링크형 액션(학교 연결 / 다시 시도).
class _LinkLine extends StatelessWidget {
  final SurlapColors sh;
  final String text;
  final String action;
  final VoidCallback onTap;
  const _LinkLine(
      {required this.sh,
      required this.text,
      required this.action,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: AppType.bodyLarge.copyWith(
                fontSize: 13.5, color: sh.inkSoft, height: 1.3),
            maxLines: 2),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Text(action,
              style: AppType.labelMedium.copyWith(
                  color: sh.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── 오늘 일정(개수) 카드 ────────────────────────────────────────
class _TodayStatsCard extends StatelessWidget {
  final SurlapColors sh;
  final int count;
  final VoidCallback onTap;

  const _TodayStatsCard(
      {required this.sh, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 120),
        decoration: _softCard(sh, radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBadge(sh, Icons.calendar_today_rounded, tr('오늘 일정')),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$count',
                    style: AppType.titleLarge.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: count > 0 ? sh.accent : sh.inkFaint,
                        height: 1)),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(tr('개'),
                      style: AppType.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600, color: sh.inkSoft)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(count > 0 ? tr('탭해서 오늘 보기') : tr('등록된 일정이 없어요'),
                style: AppType.labelMedium
                    .copyWith(fontSize: 12, color: sh.inkFaint)),
          ],
        ),
      ),
    );
  }
}

// ─── 오늘 할 일 카드 ─────────────────────────────────────────────
class _TodayTodosCard extends StatelessWidget {
  final SurlapColors sh;
  final List<TodoItem> todos;
  final void Function(String id) onToggle;
  final void Function(TodoItem) onTapTodo;

  const _TodayTodosCard({
    required this.sh,
    required this.todos,
    required this.onToggle,
    required this.onTapTodo,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = todos.where((t) => !t.done).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _softCard(sh, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(sh, Icons.checklist_rounded, tr('오늘 할 일')),
              const Spacer(),
              if (todos.isNotEmpty)
                Text('$remaining / ${todos.length}',
                    style: AppType.labelMedium
                        .copyWith(fontSize: 12, color: sh.inkSoft)),
            ],
          ),
          const SizedBox(height: 10),
          if (todos.isEmpty)
            _emptyNote(
              sh,
              tr('아직 할 일이 없어요'),
              tr('오른쪽 아래 + 버튼으로 추가해보세요'),
            )
          else
            ...todos.map((t) {
              final c = todoPriorityColor(t.priority, sh);
              return InkWell(
                onTap: () => onTapTodo(t),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => onToggle(t.id),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          todoStatusIcon(t.status),
                          size: 22,
                          color: todoStatusColor(t.status, t.priority, sh),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (t.hasPriority) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('P${t.priority}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: c)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyLarge.copyWith(
                            fontSize: 15,
                            color: t.done ? sh.inkFaint : sh.ink,
                            decoration: t.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── 다가오는 생일 카드 ──────────────────────────────────────────
class _UpcomingBirthdaysCard extends StatelessWidget {
  final SurlapColors sh;
  final List<Birthday> birthdays;
  final VoidCallback onTap;
  const _UpcomingBirthdaysCard(
      {required this.sh, required this.birthdays, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _softCard(sh, radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _iconBadge(sh, Icons.cake_rounded, tr('다가오는 생일'),
                  color: sh.birthdayColor),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 18, color: sh.inkFaint),
            ]),
            const SizedBox(height: 10),
            ...birthdays.map((b) {
              final d = b.daysUntilNext();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(Icons.cake_rounded, size: 16, color: sh.birthdayColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyLarge.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: sh.ink)),
                  ),
                  Text('${b.month}.${b.day}',
                      style: AppType.labelMedium
                          .copyWith(fontSize: 12, color: sh.inkSoft)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: d == 0
                          ? sh.birthdayColor
                          : sh.birthdayColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(d == 0 ? tr('오늘') : 'D-$d',
                        style: AppType.labelMedium.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: d == 0 ? Colors.white : sh.birthdayColor)),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── 이번 주 미니 스트립 ─────────────────────────────────────────
class _WeekStripCard extends StatelessWidget {
  final SurlapColors sh;
  final DateTime monday;
  final List<String> weekKeys;
  final Map<String, int> eventCounts;
  final String today;
  final void Function(String) onDayTap;

  const _WeekStripCard({
    required this.sh,
    required this.monday,
    required this.weekKeys,
    required this.eventCounts,
    required this.today,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onDayTap(today),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _softCard(sh, radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _iconBadge(sh, Icons.calendar_view_week_rounded, tr('이번 주')),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: sh.inkFaint),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(7, (i) {
                final d = monday.add(Duration(days: i));
                final key = weekKeys[i];
                final isToday = key == today;
                final count = eventCounts[key] ?? 0;
                final isSat = d.weekday == DateTime.saturday;
                final isSun = d.weekday == DateTime.sunday;

                final dayColor = isToday
                    ? sh.accentInk
                    : isSun
                        ? sh.danger
                        : isSat
                            ? sh.sat
                            : sh.inkSoft;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTap(key),
                    child: Column(
                      children: [
                        Text(i18nd.weekdayShort(i + 1),
                            style: AppType.labelMedium.copyWith(color: dayColor)),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: isToday
                              ? BoxDecoration(
                                  color: sh.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: sh.accent.withValues(alpha: 0.40),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                )
                              : null,
                          child: Text(
                            '${d.day}',
                            style: AppType.bodySmall.copyWith(
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                              color: isToday
                                  ? (sh.dark ? sh.ink : Colors.white)
                                  : sh.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (count > 0)
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isToday ? sh.accentInk : sh.accent,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 5),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademicDDayCard extends StatelessWidget {
  final SurlapColors sh;
  final AcademicHighlight highlight;
  const _AcademicDDayCard({required this.sh, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final d = highlight.daysAway;
    final dLabel = d == 0 ? tr('오늘') : 'D-$d';
    final c = sh.academicColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _softCard(sh,
          radius: 18, color: c.withValues(alpha: sh.dark ? 0.10 : 0.06)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withValues(alpha: sh.dark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.school_rounded, size: 18, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(highlight.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700, color: sh.ink)),
                Text(highlight.dateKey,
                    style: AppType.labelMedium
                        .copyWith(fontSize: 12, color: sh.inkSoft)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: d == 0 ? c : c.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(dLabel,
                style: AppType.labelMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: d == 0 ? Colors.white : c)),
          ),
        ],
      ),
    );
  }
}
