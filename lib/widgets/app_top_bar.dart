import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'coach_mark.dart';

// ─── 투명 상단 overlay 헤더 ──────────────────────────────────────
// Status bar 뒤쪽까지 자연스럽게 gradient가 깔리는 미니멀 상단 바.
// 뷰 전환은 헤더의 ViewSegmentControl(연·월·주·일)이 담당하고,
// 좌상단 햄버거 버튼으로 내비게이션 서랍(SurlapNavDrawer)을 연다.
class AppOverlayTopBar extends ConsumerWidget {
  const AppOverlayTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;
    final sh = context.sh;

    final gradientColors = [
      sh.bg.withValues(alpha: 0.96),
      sh.bg.withValues(alpha: 0.82),
      sh.bg.withValues(alpha: 0.0),
    ];

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // status bar 영역만 블러 — 빈 버튼 띠 없음.
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                height: topPad,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                    stops: const [0.0, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // ── 좌상단 햄버거 → 내비게이션 서랍 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _MenuButton(sh: sh),
            ),
          ),
        ],
      ),
    );
  }
}

// 유리질감 원형 햄버거 버튼. 탭하면 Scaffold 서랍을 연다.
class _MenuButton extends StatelessWidget {
  final SurlapColors sh;
  const _MenuButton({required this.sh});

  @override
  Widget build(BuildContext context) {
    final dark = sh.dark;
    final tint = dark
        ? const Color(0xFF221E32).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.74);
    final border = dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF14131A).withValues(alpha: 0.05);

    return Semantics(
      label: '메뉴',
      button: true,
      child: GestureDetector(
        key: coachKeyBottomNav,
        behavior: HitTestBehavior.opaque,
        onTap: () => Scaffold.of(context).openDrawer(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: Icon(Icons.menu_rounded, size: 24, color: sh.ink),
            ),
          ),
        ),
      ),
    );
  }
}
