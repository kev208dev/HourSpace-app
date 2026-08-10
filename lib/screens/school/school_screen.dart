import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar/calendar_item.dart';
import '../../core/calendar/calendar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../modals/neis_setup_modal.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../providers/view_provider.dart';
import '../../supabase/neis_service.dart' show NeisSchool, academicVisibleForGrade;
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/school_logo.dart';
import '../../widgets/section_header.dart';
import '../timetable_view/timetable_view.dart';

/// 학교 탭 — "오늘 학교에서 뭐 하지?" 하나에 답한다.
///
/// NEIS 연동 결과(시간표·급식·학사일정)를 한 화면에 모은다. 자세한 시간표는
/// 별도 화면([TimetableView])으로 밀어 이 화면은 훑어보기용으로 유지한다.
class SchoolScreen extends ConsumerWidget {
  const SchoolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = NeisSchool.load();
    if (school == null) return const _NotConnected();

    final sh = context.sh;
    final today = DateTime.now();
    final todayKey = du.toDateKey(today);
    final neis = ref.watch(neisCacheProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.sm, Gap.lg, kBottomNavClearance),
      children: [
        _Header(school: school),
        const SizedBox(height: Gap.lg),

        // ── 오늘 시간표 ──
        SectionHeader(
          title: tr('오늘 시간표'),
          actionLabel: tr('크게 보기'),
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const _TimetablePage()),
          ),
        ),
        _TodayPeriods(dateKey: todayKey),

        // ── 급식 ──
        const SizedBox(height: Gap.xl),
        SectionHeader(title: tr('오늘 급식')),
        _Meal(text: neis.lunch[today.weekday - 1]),

        // ── 학사일정 ──
        const SizedBox(height: Gap.xl),
        SectionHeader(title: tr('학사일정')),
        _AcademicList(grade: school.grade),

        const SizedBox(height: Gap.xl),
        Center(
          child: TextButton.icon(
            onPressed: () {
              ref.read(neisCacheProvider.notifier).refresh();
              ref.read(academicScheduleProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(tr('새로고침')),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => showNeisSetupModal(context),
            style: TextButton.styleFrom(foregroundColor: sh.inkSoft),
            child: Text(tr('학교 변경')),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final NeisSchool school;
  const _Header({required this.school});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Row(
      children: [
        SchoolLogo(name: school.name, logoUrl: school.logoUrl, size: 40),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(school.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle.copyWith(
                      color: sh.ink, fontWeight: FontWeight.w800)),
              Text(
                trf('{0}학년 {1}반', [school.grade, school.classNm]),
                style: AppType.sub.copyWith(color: sh.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 오늘 교시 목록. 통합 계층에서 가져오므로 캘린더·위젯과 같은 시각을 쓴다.
class _TodayPeriods extends ConsumerWidget {
  final String dateKey;
  const _TodayPeriods({required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final now = DateTime.now();
    final classes = ref
        .watch(calendarDayProvider(dateKey))
        .where((i) => i.source == CalendarSource.schoolTimetable)
        .toList();

    if (classes.isEmpty) {
      return Text(tr('오늘은 수업이 없어요'),
          style: AppType.body.copyWith(color: sh.inkFaint));
    }

    return Column(
      children: [
        for (final c in classes)
          _PeriodRow(item: c, ongoing: c.isOngoingAt(now)),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final CalendarItem item;
  final bool ongoing;
  const _PeriodRow({required this.item, required this.ongoing});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final period = item.metadata['period'];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 10),
      decoration: BoxDecoration(
        // 진행 중인 교시만 라임 — "지금"이라는 신호.
        color: ongoing ? sh.nowBg : sh.card,
        borderRadius: BorderRadius.circular(Radii.small),
        border: Border.all(color: ongoing ? sh.now : sh.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              period == null ? '' : trf('{0}교시', [period]),
              style: AppType.caption.copyWith(
                  color: ongoing ? sh.now : sh.inkFaint,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(
                  color: sh.ink,
                  fontWeight: ongoing ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
          Text(
            '${item.startHhmm}',
            style: AppType.caption.copyWith(color: sh.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _Meal extends StatelessWidget {
  final String? text;
  const _Meal({this.text});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final menu = text?.trim();
    if (menu == null || menu.isEmpty) {
      return Text(tr('급식 정보가 없어요'),
          style: AppType.body.copyWith(color: sh.inkFaint));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.small),
        border: Border.all(color: sh.border),
      ),
      child: Text(menu.replaceAll('\n', ' · '),
          style: AppType.body.copyWith(color: sh.ink)),
    );
  }
}

class _AcademicList extends ConsumerWidget {
  final int grade;
  const _AcademicList({required this.grade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final schedule = ref.watch(academicScheduleProvider);
    final todayKey = du.todayKey();

    final upcoming = <({String dateKey, String name, int daysAway})>[];
    final today = du.fromDateKey(todayKey);
    schedule.forEach((dateKey, names) {
      if (dateKey.compareTo(todayKey) < 0) return;
      final DateTime d;
      try {
        d = du.fromDateKey(dateKey);
      } catch (_) {
        return;
      }
      for (final n in names.where((n) => academicVisibleForGrade(n, grade))) {
        upcoming.add((
          dateKey: dateKey,
          name: n,
          daysAway: d.difference(today).inDays,
        ));
      }
    });
    upcoming.sort((a, b) => a.dateKey.compareTo(b.dateKey));

    if (upcoming.isEmpty) {
      return Text(tr('예정된 학사일정이 없어요'),
          style: AppType.body.copyWith(color: sh.inkFaint));
    }

    return Column(
      children: [
        for (final e in upcoming.take(6))
          InkWell(
            onTap: () => ref.read(viewProvider.notifier).openDay(e.dateKey),
            borderRadius: BorderRadius.circular(Radii.small),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(
                            color: sh.ink, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: Gap.sm),
                  Text(
                    e.daysAway == 0 ? tr('D-DAY') : 'D-${e.daysAway}',
                    style: AppType.number.copyWith(
                      color: e.daysAway == 0 ? sh.now : sh.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 학교 미연결 상태 — 이 탭의 유일한 할 일은 "연결하기"다.
class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Gap.xl, Gap.xl, Gap.xl, kBottomNavClearance),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 56, color: sh.inkFaint),
            const SizedBox(height: Gap.lg),
            Text(
              tr('학교를 연결하면\n시간표·급식·학사일정을\n자동으로 볼 수 있어요.'),
              textAlign: TextAlign.center,
              style: AppType.cardTitle.copyWith(color: sh.inkSoft),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: () => showNeisSetupModal(context),
              child: Text(tr('학교 연결')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시간표 전체 화면.
class _TimetablePage extends StatelessWidget {
  const _TimetablePage();

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        backgroundColor: sh.bg,
        title: Text(tr('시간표')),
      ),
      body: const TimetableView(),
    );
  }
}

/// 오늘 날짜 라벨 — 학교 탭 상단에서 쓰는 짧은 표기.
String schoolDateLabel(DateTime d) =>
    '${i18nd.monthDay(d)} ${i18nd.weekdayShort(d.weekday)}';
