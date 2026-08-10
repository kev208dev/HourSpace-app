import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/date_utils.dart' as du;
import '../i18n/strings.dart';
import '../modals/add_edit_event_modal.dart';
import '../modals/guest_import_prompt.dart';
import '../modals/add_todo_modal.dart';
import '../modals/record_template_sheet.dart';
import '../providers/theme_sharing_provider.dart';
import '../supabase/auth_service.dart';
import '../providers/view_provider.dart';
import '../utils/screenshot_util.dart';
import '../widgets/bottom_nav_bar.dart';
import 'calendar/calendar_screen.dart';
import 'more/more_screen.dart';
import 'theme_share_page.dart';
import 'today/today_screen.dart';
import 'todo/todo_screen.dart';

/// 앱 셸 — 5개 탭 + 하단 내비 + 추가 FAB.
///
/// 라우터 없이 [viewProvider] 하나로 탭을 전환한다(기존 구조 유지).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // 로그인 상태가 바뀌면(게스트 → 계정) 기존 데이터를 가져올지 묻는다.
    ref.listenManual(authProvider, (_, user) {
      if (user == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeShowGuestImportPrompt(context, ref);
      });
    });
    // 앱을 켤 때 이미 로그인 상태여도 한 번 확인한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(authProvider) != null) {
        maybeShowGuestImportPrompt(context, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(viewProvider);
    // 공유 캘린더 실시간 동기화 오케스트레이터를 살아있게 유지.
    ref.watch(themeSharingProvider);
    final sh = context.sh;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: sh.dark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: sh.bg,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RepaintBoundary(
              key: screenshotKey,
              child: AnimatedSwitcher(
                duration: Motion.base,
                switchInCurve: Motion.curve,
                switchOutCurve: Motion.curve,
                transitionBuilder: (child, anim) => _TabTransition(
                  animation: anim,
                  direction: view.slideDirection,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey(view.tab),
                  child: ColoredBox(
                    color: sh.bg,
                    child: _buildTab(view.tab),
                  ),
                ),
              ),
            ),
          ),
          const BottomNavScrim(),
          const SurlapBottomNav(),
          const _AddFab(),
        ],
      ),
    );
  }

  Widget _buildTab(AppTab tab) => switch (tab) {
        AppTab.home => const TodayScreen(),
        AppTab.calendar => const CalendarScreen(),
        AppTab.todos => const TodoScreen(),
        AppTab.shared => const ThemeSharePage(),
        AppTab.profile => const MoreScreen(),
      };
}

/// 우측 하단 + 스피드다이얼 — 일정 / 할 일 / 기록 추가.
///
/// 추가 대상 날짜는 캘린더에서 고른 날짜를 따른다(캘린더 탭이 아니면 오늘).
class _AddFab extends ConsumerStatefulWidget {
  const _AddFab();

  @override
  ConsumerState<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends ConsumerState<_AddFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  bool _open = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() => setState(() {
        _open = !_open;
        _open ? _c.forward() : _c.reverse();
      });

  void _close() {
    if (!_open) return;
    setState(() {
      _open = false;
      _c.reverse();
    });
  }

  String get _targetDateKey {
    final view = ref.read(viewProvider);
    return view.tab == AppTab.calendar ? view.selectedDay : du.todayKey();
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.event_rounded,
        label: tr('일정'),
        onTap: () =>
            showAddEditEventModal(context, dateKey: _targetDateKey),
      ),
      (
        icon: Icons.check_circle_rounded,
        label: tr('할 일'),
        onTap: () => showAddTodoModal(context, dateKey: _targetDateKey),
      ),
      (
        icon: Icons.edit_note_rounded,
        label: tr('기록'),
        onTap: () => showRecordTemplateSheet(context),
      ),
    ];

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final v = Curves.easeOutCubic.transform(_c.value);
          return Stack(
            children: [
              if (_c.value > 0.001)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _close,
                    child: BackdropFilter(
                      filter:
                          ImageFilter.blur(sigmaX: 3.5 * v, sigmaY: 3.5 * v),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.26 * v),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 16,
                // 하단 내비 위로 띄운다 — 겹치면 둘 다 누르기 어렵다.
                bottom: bottomInset + kBottomNavClearance - 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++)
                      _Option(
                        action: actions[i],
                        order: actions.length - 1 - i,
                        count: actions.length,
                        progress: v,
                        onTap: _close,
                      ),
                    const SizedBox(height: Gap.lg),
                    _Fab(sh: sh, progress: v, onTap: _toggle),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final ({IconData icon, String label, VoidCallback onTap}) action;
  final int order;
  final int count;
  final double progress;
  final VoidCallback onTap;

  const _Option({
    required this.action,
    required this.order,
    required this.count,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = ((progress * (count + 0.6)) - order * 0.85).clamp(0.0, 1.0);
    return IgnorePointer(
      ignoring: t < 0.6,
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 46),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                onTap();
                action.onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.icon, size: 24, color: Colors.white, shadows: const [
                      Shadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 2)),
                    ]),
                    const SizedBox(width: Gap.md),
                    Text(
                      action.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              color: Color(0x33000000),
                              blurRadius: 10,
                              offset: Offset(0, 2)),
                        ],
                      ),
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

class _Fab extends StatelessWidget {
  final SurlapColors sh;
  final double progress;
  final VoidCallback onTap;

  const _Fab({required this.sh, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('추가'),
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: kMinTouch,
          height: kMinTouch,
          decoration: BoxDecoration(
            color: sh.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: sh.accent.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Transform.rotate(
            angle: progress * 0.7854, // 45°
            child: const Icon(Icons.add_rounded, size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _TabTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final int direction;

  const _TabTransition({
    required this.child,
    required this.animation,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: animation, curve: Motion.curve);
    if (direction == 0) {
      return FadeTransition(opacity: curve, child: child);
    }
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(direction * 0.16, 0),
        end: Offset.zero,
      ).animate(curve),
      child: FadeTransition(opacity: curve, child: child),
    );
  }
}
