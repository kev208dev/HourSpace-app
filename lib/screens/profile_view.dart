import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../providers/color_preset_provider.dart';
import '../supabase/auth_service.dart';
import '../widgets/mascot/mascot.dart';
import '../widgets/pressable.dart';
import '../modals/backup_modal.dart';
import 'login/login_screen.dart';
import 'settings_view.dart'
    show SettingsSectionCard, SettingsRow, SettingsSections;

/// 프로필 — 하단 nav 5번째 탭의 in-shell 뷰.
/// 계정 정보 + 설정 진입 + 다크모드 토글 + 백업/로그인.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final user = ref.watch(authProvider);
    final loggedIn = user != null;
    final isDark = ref.watch(colorPresetProvider).dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 120),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACCOUNT',
                  style: AppType.eyebrow.copyWith(color: sh.accent)),
              const SizedBox(height: 4),
              Text(tr('프로필'),
                  style: AppType.titleLarge.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: sh.ink)),
            ],
          ),
        ),

        // ── 계정 카드 ──
        _AccountCard(
          sh: sh,
          loggedIn: loggedIn,
          name: loggedIn ? userDisplayName(user) : tr('로그인하고 동기화하기'),
          email: loggedIn ? (user.email ?? '') : tr('일정·시간표·캘린더를 기기 간 동기화'),
          onTap: () => loggedIn ? null : showLoginScreen(context),
        ),
        const SizedBox(height: 18),

        // ── 설정 섹션(내 유형·카테고리·보기 옵션·더보기) — 설정 화면 통합 ──
        const SettingsSections(),
        const SizedBox(height: 12),

        // ── 앱 ──
        SettingsSectionCard(
          sh: sh,
          title: tr('앱'),
          child: Column(
            children: [
              SettingsRow(
                sh: sh,
                icon: isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
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
                icon: Icons.backup_outlined,
                title: tr('정보 백업'),
                onTap: () => showBackupModal(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

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
                      onTap: () => _confirmDeleteAccount(context, ref),
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

// 회원 탈퇴 확인 → 서버 RPC 로 계정·데이터 삭제.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
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
    messenger.showSnackBar(
      SnackBar(content: Text(tr('계정이 삭제되었어요'))),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('탈퇴 실패: $e')),
    );
  }
}

// ── 계정 hero 카드 ──
class _AccountCard extends StatelessWidget {
  final SurlapColors sh;
  final bool loggedIn;
  final String name;
  final String email;
  final VoidCallback? onTap;

  const _AccountCard({
    required this.sh,
    required this.loggedIn,
    required this.name,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        loggedIn && name.isNotEmpty ? name.substring(0, 1).toUpperCase() : null;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              sh.accent.withValues(alpha: 0.16),
              sh.accent.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: sh.accent.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: sh.accent.withValues(alpha: sh.dark ? 0.18 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: sh.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: sh.accent.withValues(alpha: 0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: initial != null
                  ? Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800))
                  : const ClipOval(
                      child: MascotView(
                          expression: MascotExpression.happy, size: 50)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.titleLarge.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: sh.ink)),
                  const SizedBox(height: 3),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelMedium.copyWith(
                          fontSize: 12.5,
                          color: sh.ink.withValues(alpha: 0.55))),
                ],
              ),
            ),
            if (!loggedIn)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sh.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(tr('로그인'),
                    style: AppType.labelMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}
