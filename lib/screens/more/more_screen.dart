import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../modals/backup_modal.dart';
import '../../modals/birthday_manager_modal.dart';
import '../../modals/day_template_manager_modal.dart';
import '../../modals/record_template_sheet.dart';
import '../../modals/sports_subscribe_sheet.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/sports_provider.dart';
import '../../providers/themes_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/events_provider.dart';
import '../../supabase/auth_service.dart';
import '../../supabase/neis_service.dart' show NeisSchool;
import '../../supabase/supabase_client.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/ui_kit.dart';
import '../login/login_screen.dart';
import '../settings_view.dart' show SettingsSections;
import '../calendar/categories_screen.dart';
import '../settings/notifications_screen.dart';
import '../timetable_view/timetable_view.dart';
import '../school/school_connect_screen.dart';

/// 내 정보 (핸드오프 I1 · spec §4).
///
/// 프로필 카드 + 요약 수치 + 그룹별 진입점(학교 · 기록 · 캘린더 · 앱).
/// 계정이 있어야 하는 항목은 "계정 필요" 배지로 구분한다.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final signedIn = user != null;
    final school = NeisSchool.load();
    final birthdays = ref.watch(birthdaysProvider);
    final sports = ref.watch(sportsSubscriptionsProvider);
    final themes = ref.watch(userThemesProvider);
    final todos = ref.watch(todosProvider);
    final events = ref.watch(eventsProvider);

    var eventCount = 0;
    for (final list in events.values) {
      eventCount += list.length;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.md, Gap.lg, kBottomNavClearance),
      children: [
        SurlapScreenHeader(title: tr('내 정보')),
        const SizedBox(height: Gap.md),
        _ProfileCard(
          name: signedIn ? userDisplayName(user) : tr('게스트'),
          sub: school == null
              ? (signedIn ? (user.email ?? '') : tr('로그인하면 기기 간 동기화됩니다'))
              : trf('{0} {1}학년 {2}반',
                  [school.name, school.grade, school.classNm]),
          onTap: signedIn ? null : () => showLoginScreen(context),
        ),
        const SizedBox(height: Gap.md),
        _StatsRow(stats: [
          (n: '$eventCount', l: tr('일정')),
          (n: '${todos.length}', l: tr('할 일')),
          (n: '${themes.length}', l: tr('캘린더')),
          (n: '${birthdays.length}', l: tr('생일')),
        ]),
        _Group(head: tr('학교'), items: [
          _Item(
            icon: Icons.school_rounded,
            label: school == null ? tr('학교 연결') : tr('학교 변경'),
            sub: school == null
                ? tr('초·중·고 사용자만')
                : trf('{0} {1}학년 {2}반',
                    [school.name, school.grade, school.classNm]),
            onTap: () => showSchoolConnect(context),
          ),
          _Item(
            icon: Icons.grid_on_rounded,
            label: tr('시간표'),
            sub: tr('주간 시간표와 급식'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const _TimetablePage())),
          ),
        ]),
        _Group(head: tr('기록'), items: [
          _Item(
            icon: Icons.style_rounded,
            label: tr('하루 템플릿'),
            sub: tr('매일 채우는 항목'),
            onTap: () => showDayTemplateManagerModal(context),
          ),
          _Item(
            icon: Icons.show_chart_rounded,
            label: tr('기록 템플릿'),
            sub: tr('기간을 정해 쌓는 기록'),
            onTap: () => showRecordTemplateSheet(context),
          ),
        ]),
        _Group(head: tr('캘린더'), items: [
          _Item(
            icon: Icons.grid_view_rounded,
            label: tr('캘린더 카테고리'),
            sub: trf('{0}개', [themes.length]),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const CategoriesScreen())),
          ),
          _Item(
            icon: Icons.cake_rounded,
            label: tr('생일'),
            sub: trf('{0}명', [birthdays.length]),
            onTap: () => showBirthdayManagerModal(context),
          ),
          _Item(
            icon: Icons.emoji_events_rounded,
            label: tr('스포츠 구독'),
            sub: trf('{0}개', [sports.length]),
            onTap: () => showSportsSubscribeSheet(context),
          ),
        ]),
        _Group(head: tr('앱'), items: [
          _Item(
            icon: Icons.notifications_rounded,
            label: tr('알림'),
            sub: tr('일정·브리핑·생일'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen())),
          ),
          _Item(
            icon: Icons.tune_rounded,
            label: tr('앱 설정'),
            sub: tr('보기 옵션 · 주 시작 요일'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const _SettingsPage())),
          ),
          _Item(
            icon: Icons.download_rounded,
            label: tr('백업 · 복원 · 내보내기'),
            sub: tr('JSON · iCalendar · 클라우드'),
            onTap: () => showBackupModal(context),
          ),
          _Item(
            icon: Icons.person_rounded,
            label: tr('계정'),
            sub: signedIn ? tr('로그인됨') : tr('게스트'),
            locked: !signedIn && sb == null,
            onTap: () => signedIn
                ? _showAccountSheet(context, ref)
                : showLoginScreen(context),
          ),
        ]),
      ],
    );
  }
}

/// 프로필 카드 — 48px 원형 아바타 + 17px 이름 + 11.5px 부제.
class _ProfileCard extends StatelessWidget {
  final String name;
  final String sub;
  final VoidCallback? onTap;
  const _ProfileCard({required this.name, required this.sub, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return SurlapCard(
      onTap: onTap,
      child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: sh.card2, shape: BoxShape.circle),
              child: Icon(Icons.account_circle_rounded,
                  size: 26, color: sh.accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.section.copyWith(color: sh.ink)),
                  const SizedBox(height: 3),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(
                          color: sh.ink.withValues(alpha: 0.50))),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 15, color: sh.ink.withValues(alpha: 0.30)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<({String n, String l})> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: Gap.sm),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
              decoration: BoxDecoration(
                color: sh.card,
                borderRadius: BorderRadius.circular(Radii.md),
                boxShadow: sh.shadowCard,
              ),
              child: Column(
                children: [
                  Text(stats[i].n,
                      style: AppType.display.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: sh.ink)),
                  const SizedBox(height: 2),
                  Text(stats[i].l,
                      style: AppType.label.copyWith(
                          fontWeight: FontWeight.w400,
                          color: sh.ink.withValues(alpha: 0.50))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final String sub;
  final bool locked;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.locked = false,
  });
}

class _Group extends StatelessWidget {
  final String head;
  final List<_Item> items;
  const _Group({required this.head, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SurlapSection(title: head, style: SurlapSectionStyle.overline),
        SurlapCard(
          list: true,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _Row(item: items[i], last: i == items.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final _Item item;
  final bool last;
  const _Row({required this.item, required this.last});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return SurlapRow(
      last: last,
      onTap: item.onTap,
      child: Row(
          children: [
            Icon(item.icon, size: 19, color: sh.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: AppType.button.copyWith(color: sh.ink)),
                  if (item.sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(
                            color: sh.ink.withValues(alpha: 0.48))),
                  ],
                ],
              ),
            ),
            if (item.locked)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sh.card2,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(tr('계정 필요'),
                    style: AppType.micro
                        .copyWith(color: sh.ink.withValues(alpha: 0.50))),
              ),
          Icon(Icons.chevron_right_rounded,
              size: 15, color: sh.ink.withValues(alpha: 0.30)),
        ],
      ),
    );
  }
}

/// 계정 시트 — 로그아웃 · 회원 탈퇴.
Future<void> _showAccountSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final sh = context.sh;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: sh.card,
              borderRadius: BorderRadius.circular(Radii.sheet),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: sh.ink),
                  title: Text(tr('로그아웃'),
                      style: AppType.button.copyWith(color: sh.ink)),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(authProvider.notifier).signOut();
                  },
                ),
                Divider(height: 1, color: sh.border),
                ListTile(
                  leading: Icon(Icons.person_remove_rounded, color: sh.danger),
                  title: Text(tr('회원 탈퇴'),
                      style: AppType.button.copyWith(color: sh.danger)),
                  onTap: () {
                    Navigator.pop(context);
                    confirmDeleteAccount(context, ref);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

class _TimetablePage extends StatelessWidget {
  const _TimetablePage();

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(backgroundColor: sh.bg, title: Text(tr('시간표'))),
      body: const TimetableView(),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(backgroundColor: sh.bg, title: Text(tr('앱 설정'))),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(Gap.lg),
        child: SettingsSections(),
      ),
    );
  }
}

/// 회원 탈퇴 확인 → 서버 RPC 로 계정·데이터 삭제.
Future<void> confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final sh = context.sh;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: sh.card,
      title: Text(tr('회원 탈퇴'),
          style: AppType.number.copyWith(color: sh.ink)),
      content: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: sh.accent2Bg,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Text(
          tr('계정과 클라우드에 저장된 데이터가 영구히 삭제됩니다. 되돌릴 수 없습니다.'),
          style: AppType.body.copyWith(height: 1.55, color: sh.accent2Ink),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('취소')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: sh.danger),
          child: Text(tr('탈퇴')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(authProvider.notifier).deleteAccount();
    messenger.showSnackBar(SnackBar(content: Text(tr('계정이 삭제되었어요'))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('탈퇴 실패: $e')));
  }
}
