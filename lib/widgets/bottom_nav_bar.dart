import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../providers/view_provider.dart';
import 'coach_mark.dart';

/// 하단 내비게이션 — 오늘 / 캘린더 / 학교 / 할 일 / 더보기.
///
/// 선택 상태는 accent(퍼플)로 표시한다. `sh.now`(라임)는 "지금/오늘"이라는
/// 의미 전용이라 여기에는 쓰지 않는다 — 아무 데나 쓰면 신호가 죽는다.
class SurlapBottomNav extends ConsumerWidget {
  const SurlapBottomNav({super.key});

  static const _icons = {
    AppTab.today: Icons.wb_sunny_rounded,
    AppTab.calendar: Icons.calendar_month_rounded,
    AppTab.school: Icons.school_rounded,
    AppTab.todo: Icons.check_circle_rounded,
    AppTab.more: Icons.more_horiz_rounded,
  };

  static final _coachKeys = {
    AppTab.school: coachKeyTabTimetable,
    AppTab.more: coachKeyTabProfile,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(viewProvider).tab;
    final notifier = ref.read(viewProvider.notifier);
    final sh = context.sh;
    final dark = sh.dark;

    final inactive = dark
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0xFF14131A).withValues(alpha: 0.34);
    final tint = dark
        ? const Color(0xFF221E32).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.74);
    final border = dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF14131A).withValues(alpha: 0.05);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                key: coachKeyBottomNav,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A1FD0).withValues(alpha: 0.30),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                      spreadRadius: -16,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tab in AppTab.values)
                      _NavItem(
                        icon: _icons[tab]!,
                        label: tr(tab.label),
                        active: tab == current,
                        onTap: () => notifier.setTab(tab),
                        coachKey: _coachKeys[tab],
                        accent: sh.accentInk,
                        activeBg: sh.accentBg,
                        inactive: inactive,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 내비 뒤 하단 스크림 — 콘텐츠가 내비 뒤로 자연스럽게 사라지도록.
class BottomNavScrim extends ConsumerWidget {
  const BottomNavScrim({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                sh.bg.withValues(alpha: 0.94),
                sh.bg.withValues(alpha: 0.55),
                sh.bg.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 내비가 가리는 높이 — 스크롤 뷰의 bottom padding 기준값.
const double kBottomNavClearance = 108;

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final GlobalKey? coachKey;
  final Color accent;
  final Color activeBg;
  final Color inactive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.accent,
    required this.activeBg,
    required this.inactive,
    this.coachKey,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: active,
      child: GestureDetector(
        key: coachKey,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.curve,
          height: kMinTouch,
          // 탭이 5개라 활성 상태에서도 가로 여백을 줄여 작은 기기에서 넘치지 않게.
          padding: EdgeInsets.symmetric(horizontal: active ? 11 : 0),
          constraints: BoxConstraints(minWidth: active ? 0 : kMinTouch),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: active ? 21 : 23, color: active ? accent : inactive),
              if (active) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ).copyWith(color: accent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
