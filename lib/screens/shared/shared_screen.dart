import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../models/calendar_theme.dart';
import '../../modals/share_code_modal.dart';
import '../../supabase/theme_share_service.dart';
import '../../modals/sports_subscribe_sheet.dart';
import '../../modals/theme_manager_modal.dart';
import '../../providers/themes_provider.dart';
import '../../supabase/auth_service.dart';
import '../../supabase/supabase_client.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../login/login_screen.dart';

/// 공유 (핸드오프 H1 · spec §10).
///
/// 내가 공유 중인 캘린더와 구독 중인 캘린더를 세그먼트로 나눠 보여준다.
/// 로그인 + Supabase 연결이 모두 있어야 쓸 수 있고, 없으면 잠금 카드만 뜬다.
/// 스포츠 구독은 계정 없이도 되므로 잠금 카드에서도 진입할 수 있다.
class SharedScreen extends ConsumerStatefulWidget {
  const SharedScreen({super.key});

  @override
  ConsumerState<SharedScreen> createState() => _SharedScreenState();
}

enum _ShareTab { owned, subscribed }

class _SharedScreenState extends ConsumerState<SharedScreen> {
  _ShareTab _tab = _ShareTab.owned;

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final signedIn = ref.watch(authProvider) != null && sb != null;
    final themes = ref.watch(themesProvider);
    final owned = themes
        .where((t) => t.shareCode != null && t.shareRole == 'owner')
        .toList();
    final subscribed = themes
        .where((t) => t.shareCode != null && t.shareRole == 'subscriber')
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.md, Gap.lg, kBottomNavClearance),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(tr('공유'),
                  style: AppType.display.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: sh.ink)),
            ),
            _IconBtn(
              icon: Icons.emoji_events_rounded,
              tooltip: tr('스포츠 구독'),
              onTap: () => showSportsSubscribeSheet(context),
            ),
            _IconBtn(
              icon: Icons.add_rounded,
              tooltip: tr('코드로 구독'),
              onTap: () => showThemeManagerModal(context),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        if (!signedIn)
          _LockedCard(
            onLogin: () => showLoginScreen(context),
            onSports: () => showSportsSubscribeSheet(context),
          )
        else ...[
          _SegmentedTabs(
            current: _tab,
            ownedCount: owned.length,
            subCount: subscribed.length,
            onPick: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: Gap.md),
          if (_tab == _ShareTab.owned)
            _OwnedList(themes: owned)
          else
            _SubscribedList(themes: subscribed),
        ],
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 20, color: context.sh.ink),
          ),
        ),
      );
}

/// 미로그인 — 자물쇠 + 안내 + 로그인 / 스포츠 구독 버튼.
class _LockedCard extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSports;
  const _LockedCard({required this.onLogin, required this.onSports});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: sh.shadowCard,
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded, size: 28, color: sh.accent),
          const SizedBox(height: 10),
          Text(tr('계정이 필요한 기능입니다'),
              style: AppType.cardTitle.copyWith(color: sh.ink)),
          const SizedBox(height: 7),
          Text(
            tr('공유 캘린더는 로그인과 서버 연결이 모두 있어야 씁니다. 스포츠 구독은 계정 없이도 사용할 수 있습니다.'),
            textAlign: TextAlign.center,
            style: AppType.sub.copyWith(
                height: 1.6, color: sh.ink.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: Gap.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder()),
              child: Text(tr('로그인')),
            ),
          ),
          const SizedBox(height: Gap.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSports,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: const StadiumBorder(),
                side: BorderSide(color: sh.border),
                foregroundColor: sh.ink,
              ),
              child: Text(tr('스포츠 구독 보기')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final _ShareTab current;
  final int ownedCount;
  final int subCount;
  final ValueChanged<_ShareTab> onPick;

  const _SegmentedTabs({
    required this.current,
    required this.ownedCount,
    required this.subCount,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final items = [
      (_ShareTab.owned, trf('내가 공유 중 {0}', [ownedCount])),
      (_ShareTab.subscribed, trf('구독 중 {0}', [subCount])),
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: sh.border),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(items[i].$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: items[i].$1 == current
                          ? sh.accent
                          : Colors.transparent,
                      border: i == 0
                          ? null
                          : Border(left: BorderSide(color: sh.border)),
                    ),
                    child: Text(items[i].$2,
                        style: AppType.body.copyWith(
                            color:
                                items[i].$1 == current ? sh.bg : sh.ink)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnedList extends StatelessWidget {
  final List<CalendarTheme> themes;
  const _OwnedList({required this.themes});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    if (themes.isEmpty) {
      return _EmptyNote(tr('아직 공유 중인 캘린더가 없습니다. 캘린더 관리에서 공유를 시작해 보세요.'));
    }
    return Column(
      children: [
        for (final t in themes) ...[
          _ShareCard(
            theme: t,
            badge: tr('소유'),
            badgeBg: sh.accentBg,
            badgeFg: sh.accentInk,
            trailing: Icon(Icons.share_rounded, size: 18, color: sh.accent),
            onTap: () => showShareCodeModal(
              context,
              t.name,
              t.shareCode!,
              ThemeShareService.httpsLinkForCode(t.shareCode!),
            ),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _SubscribedList extends StatelessWidget {
  final List<CalendarTheme> themes;
  const _SubscribedList({required this.themes});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    if (themes.isEmpty) {
      return _EmptyNote(tr('구독 중인 캘린더가 없습니다. 우측 상단 + 로 코드를 입력해 구독하세요.'));
    }
    return Column(
      children: [
        for (final t in themes) ...[
          _ShareCard(
            theme: t,
            badge: tr('읽기 전용'),
            badgeBg: sh.card2,
            badgeFg: sh.ink.withValues(alpha: 0.50),
            trailing: Icon(Icons.lock_outline_rounded,
                size: 14, color: sh.ink.withValues(alpha: 0.45)),
            onTap: () => showThemeManagerModal(context),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _ShareCard extends StatelessWidget {
  final CalendarTheme theme;
  final String badge;
  final Color badgeBg;
  final Color badgeFg;
  final Widget trailing;
  final VoidCallback onTap;

  const _ShareCard({
    required this.theme,
    required this.badge,
    required this.badgeBg,
    required this.badgeFg,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: sh.card,
          borderRadius: BorderRadius.circular(Radii.card),
          boxShadow: sh.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorValue,
                    borderRadius: BorderRadius.circular(Radii.swatch),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(theme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.cardTitle.copyWith(color: sh.ink)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(badge,
                      style: AppType.micro.copyWith(color: badgeFg)),
                ),
              ],
            ),
            if (theme.shareCode != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sh.card2,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Text(
                      theme.shareCode!,
                      style: AppType.number.copyWith(
                          fontSize: 15,
                          letterSpacing: 1.8,
                          color: sh.ink),
                    ),
                  ),
                  const Spacer(),
                  trailing,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Text(text,
          style: AppType.sub.copyWith(
              height: 1.55, color: sh.ink.withValues(alpha: 0.58))),
    );
  }
}
