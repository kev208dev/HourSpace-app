import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../modals/backup_modal.dart';
import '../../modals/birthday_manager_modal.dart';
import '../../modals/neis_setup_modal.dart';
import '../../modals/record_template_sheet.dart';
import '../../modals/sports_subscribe_sheet.dart';
import '../../modals/theme_manager_modal.dart';
import '../../providers/color_preset_provider.dart';
import '../../supabase/auth_service.dart';
import '../../supabase/neis_service.dart' show NeisSchool;
import '../../widgets/bottom_nav_bar.dart';
import '../login/login_screen.dart';
import '../settings_view.dart'
    show SettingsSectionCard, SettingsRow, SettingsSections;
import '../theme_share_page.dart';

/// 더보기 — 자주 쓰지 않는 기능의 허브.
///
/// 예전 프로필 화면이 사실상 설정 허브였는데 SNS 프로필처럼 보였다.
/// 이름을 역할에 맞추고, 기록·캘린더 관리·공유·스포츠·생일처럼 하단 내비에서
/// 내려온 기능들의 입구를 여기 모은다.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final user = ref.watch(authProvider);
    final loggedIn = user != null;
    final isDark = ref.watch(colorPresetProvider).dark;
    final school = NeisSchool.load();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.sm, Gap.lg, kBottomNavClearance),
      children: [
        _Identity(
          name: loggedIn ? userDisplayName(user) : tr('게스트'),
          subtitle: school == null
              ? (loggedIn ? (user.email ?? '') : tr('로그인하면 기기 간 동기화돼요'))
              : trf('{0} · {1}학년 {2}반',
                  [school.name, school.grade, school.classNm]),
          onTap: loggedIn ? null : () => showLoginScreen(context),
          showLoginButton: !loggedIn,
        ),
        const SizedBox(height: Gap.lg),

        // ── 내 데이터 ──
        SettingsSectionCard(
          sh: sh,
          title: tr('내 데이터'),
          child: Column(
            children: [
              SettingsRow(
                sh: sh,
                icon: Icons.edit_note_rounded,
                title: tr('기록'),
                onTap: () => showRecordTemplateSheet(context),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.palette_rounded,
                title: tr('캘린더 관리'),
                onTap: () => showThemeManagerModal(context),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.group_rounded,
                title: tr('공유 캘린더'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _SharePage(),
                  ),
                ),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.sports_soccer_rounded,
                title: tr('스포츠 구독'),
                onTap: () => showSportsSubscribeSheet(context),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.cake_rounded,
                title: tr('생일'),
                onTap: () => showBirthdayManagerModal(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),

        // ── 앱 ──
        SettingsSectionCard(
          sh: sh,
          title: tr('앱'),
          child: Column(
            children: [
              SettingsRow(
                sh: sh,
                icon:
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: tr('다크 모드'),
                trailing: Switch.adaptive(
                  value: isDark,
                  activeThumbColor: sh.accent,
                  onChanged: (v) =>
                      ref.read(colorPresetProvider.notifier).setDark(v),
                ),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.school_rounded,
                title: school == null ? tr('학교 연결') : tr('학교 변경'),
                onTap: () => showNeisSetupModal(context),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.backup_outlined,
                title: tr('백업 · 복원'),
                onTap: () => showBackupModal(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),

        // ── 앱 설정(알림·보기 옵션 등) ──
        const SettingsSections(),
        const SizedBox(height: Gap.md),

        // ── 계정 ──
        SettingsSectionCard(
          sh: sh,
          title: tr('계정'),
          child: loggedIn
              ? Column(
                  children: [
                    SettingsRow(
                      sh: sh,
                      icon: Icons.logout_rounded,
                      title: tr('로그아웃'),
                      onTap: () => ref.read(authProvider.notifier).signOut(),
                    ),
                    SettingsRow(
                      sh: sh,
                      icon: Icons.person_remove_rounded,
                      title: tr('회원 탈퇴'),
                      onTap: () => confirmDeleteAccount(context, ref),
                    ),
                  ],
                )
              : SettingsRow(
                  sh: sh,
                  icon: Icons.login_rounded,
                  title: tr('로그인하여 클라우드 동기화'),
                  onTap: () => showLoginScreen(context),
                ),
        ),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showLoginButton;

  const _Identity({
    required this.name,
    required this.subtitle,
    required this.onTap,
    required this.showLoginButton,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.display.copyWith(color: sh.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(color: sh.inkSoft)),
                ],
              ),
            ),
            if (showLoginButton)
              FilledButton(
                onPressed: onTap,
                child: Text(tr('로그인')),
              ),
          ],
        ),
      ),
    );
  }
}

class _SharePage extends StatelessWidget {
  const _SharePage();

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        backgroundColor: sh.bg,
        title: Text(tr('공유 캘린더')),
      ),
      body: const ThemeSharePage(),
    );
  }
}

/// 회원 탈퇴 확인 → 서버 RPC 로 계정·데이터 삭제.
Future<void> confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('회원 탈퇴')),
      content: Text(
        tr('계정과 클라우드에 저장된 데이터가 영구히 삭제돼요.\n이 작업은 되돌릴 수 없어요.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('취소')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
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
