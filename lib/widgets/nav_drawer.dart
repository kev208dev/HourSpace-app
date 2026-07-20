import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../providers/view_provider.dart';
import 'coach_mark.dart';

// ─── 좌측 내비게이션 서랍 (2026 리디자인) ───────────────────────────
// 하단 플로팅 탭바를 대체. 5개 목적지를 세로 리스트로 나열하고,
// 선택된 항목은 accent 필박스(accentBg 틴트 + accent 아이콘/라벨)로 강조.
class SurlapNavDrawer extends ConsumerWidget {
  const SurlapNavDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewProvider);
    final notifier = ref.read(viewProvider.notifier);
    final sh = context.sh;

    final items = <_NavEntry>[
      _NavEntry(
        icon: Icons.home_rounded,
        label: tr('홈'),
        active: view.mode == ViewMode.home,
        onTap: () => notifier.setMode(ViewMode.home),
      ),
      _NavEntry(
        icon: Icons.calendar_month_rounded,
        label: tr('캘린더'),
        active: const {
          ViewMode.events,
          ViewMode.year,
          ViewMode.planner,
          ViewMode.day,
        }.contains(view.mode),
        onTap: () => notifier.setMode(ViewMode.events),
      ),
      _NavEntry(
        icon: Icons.grid_view_rounded,
        label: tr('스케줄'),
        active: view.mode == ViewMode.timetable,
        onTap: () => notifier.setMode(ViewMode.timetable),
        coachKey: coachKeyTabTimetable,
      ),
      _NavEntry(
        icon: Icons.palette_rounded,
        label: tr('공유'),
        active: view.mode == ViewMode.themes,
        onTap: () => notifier.setMode(ViewMode.themes),
      ),
      _NavEntry(
        icon: Icons.person_rounded,
        label: tr('프로필'),
        active: view.mode == ViewMode.profile ||
            view.mode == ViewMode.settings,
        onTap: () => notifier.setMode(ViewMode.profile),
        coachKey: coachKeyTabProfile,
      ),
    ];

    return Drawer(
      backgroundColor: sh.bg,
      width: 288,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 브랜드 헤더 ──
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.lg),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: sh.accentGrad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: const Icon(Icons.calendar_today_rounded,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: Gap.md),
                  Text(
                    'Surlap',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: sh.ink,
                    ),
                  ),
                ],
              ),
            ),
            // ── 목적지 리스트 ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                children: [
                  for (final e in items)
                    _NavTile(
                      entry: e,
                      sh: sh,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavEntry {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final GlobalKey? coachKey;
  const _NavEntry({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.coachKey,
  });
}

class _NavTile extends StatelessWidget {
  final _NavEntry entry;
  final SurlapColors sh;
  final VoidCallback onClose;
  const _NavTile({
    required this.entry,
    required this.sh,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final active = entry.active;
    final fg = active ? sh.accent : sh.inkSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Semantics(
        label: entry.label,
        button: true,
        selected: active,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: entry.coachKey,
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () {
              entry.onTap();
              onClose();
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: kMinTouch),
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              decoration: BoxDecoration(
                color: active ? sh.accentBg : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Row(
                children: [
                  Icon(entry.icon, size: 22, color: fg),
                  const SizedBox(width: Gap.md),
                  Text(
                    entry.label,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: -0.2,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
