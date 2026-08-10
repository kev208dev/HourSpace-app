import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../providers/view_provider.dart';
import 'coach_mark.dart';

/// 하단 탭바 — 홈 · 캘린더 · 할 일 · 공유 · 내 정보.
///
/// 활성 탭은 아이콘 뒤에 시그니처 라임 pill 이 깔리고 라벨이 700 이 된다.
/// 비활성은 pill 투명 · 라벨 500 · 글자색 text 45%.
/// 첫 실행 흐름에서는 이 위젯을 아예 띄우지 않는다.
class SurlapBottomNav extends ConsumerWidget {
  const SurlapBottomNav({super.key});

  static const _icons = {
    AppTab.home: Icons.home_rounded,
    AppTab.calendar: Icons.calendar_today_rounded,
    AppTab.todos: Icons.check_box_rounded,
    AppTab.shared: Icons.share_rounded,
    AppTab.profile: Icons.account_circle_rounded,
  };

  static final _coachKeys = {
    AppTab.calendar: coachKeyTabTimetable,
    AppTab.profile: coachKeyTabProfile,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final current = ref.watch(viewProvider).tab;
    final notifier = ref.read(viewProvider.notifier);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        key: coachKeyBottomNav,
        decoration: BoxDecoration(
          color: sh.card,
          border: Border(top: BorderSide(color: sh.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: kNavBarHeight,
            child: Row(
              children: [
                for (final tab in AppTab.values)
                  Expanded(
                    child: _NavItem(
                      icon: _icons[tab]!,
                      label: tr(tab.label),
                      active: tab == current,
                      onTap: () => notifier.setTab(tab),
                      coachKey: _coachKeys[tab],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 탭바 높이(세이프에어리어 제외).
const double kNavBarHeight = 58;

/// 탭바가 가리는 높이 — 스크롤 뷰의 bottom padding 기준값.
const double kBottomNavClearance = kNavBarHeight + Gap.xl;

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final GlobalKey? coachKey;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.coachKey,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final fg = active ? sh.ink : sh.ink.withValues(alpha: 0.45);

    return Semantics(
      label: label,
      button: true,
      selected: active,
      child: GestureDetector(
        key: coachKey,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘 뒤에 깔리는 라임 pill — "지금 여기" 신호.
            AnimatedContainer(
              duration: Motion.micro,
              curve: Motion.curve,
              width: 44,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? sh.now : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Icon(icon, size: 19, color: active ? sh.onNow : fg),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.micro.copyWith(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 탭바 뒤 하단 스크림 — 콘텐츠가 탭바 밑으로 자연스럽게 사라지도록.
///
/// 탭바가 이제 불투명 카드라 스크림은 쓰지 않지만, 기존 호출부 호환을 위해
/// 자리만 남긴다.
class BottomNavScrim extends StatelessWidget {
  const BottomNavScrim({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
