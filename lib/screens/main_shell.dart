import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../i18n/strings.dart';
import '../providers/view_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_sharing_provider.dart';
import '../modals/add_todo_modal.dart';
import '../modals/add_edit_event_modal.dart';
import '../modals/theme_manager_modal.dart';
import '../modals/record_template_sheet.dart';
import '../utils/screenshot_util.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/app_top_bar.dart';
import 'home_view/home_view.dart';
import 'profile_view.dart';
import 'theme_share_page.dart';
import 'month_view/month_view.dart';
import 'month_view/continuous_week_view.dart';
import 'year_view/year_view.dart';
import 'day_view/day_view.dart';
import 'planner_view/planner_view.dart';
import 'timetable_view/timetable_view.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewProvider);
    final settings = ref.watch(settingsProvider);
    // 공유 테마 실시간 동기화 오케스트레이터를 살아있게 유지.
    ref.watch(themeSharingProvider);
    final sh = context.sh;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: sh.dark ? Brightness.light : Brightness.dark,
    ));

    // 투명 overlay 헤더가 status bar 영역까지 덮으므로
    // 콘텐츠는 그 높이만큼 내려서 시작한다.
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: sh.bg,
      resizeToAvoidBottomInset: false,
      // 좌상단 햄버거(AppOverlayTopBar)로 여는 내비게이션 서랍.
      drawer: const SurlapNavDrawer(),
      // 콘텐츠가 상·하단 시스템 영역까지 확장되도록 허용
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 메인 콘텐츠 (화면 전체 높이 채움) ──
          Column(
            children: [
              // overlay 헤더(상태바 블러)만큼만 공간 확보 — 버튼 띠 없음.
              SizedBox(height: topInset),
              const AppHeader(),
              Expanded(
                child: RepaintBoundary(
                  key: screenshotKey,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, anim) => _SlideTransition(
                      animation: anim,
                      direction: view.slideDirection,
                      child: child,
                    ),
                    child: KeyedSubtree(
                      // 월/연은 key에 연·월을 포함 → 화살표로 달 바꾸면 그리드가
                      // 확실히 새로 빌드되며 전환(const 위젯이라 안 바뀌던 버그 수정).
                      key: ValueKey(_viewKey(view, settings.continuousView)),
                      // 불투명 배경으로 감싸 전환 중 이전 화면이 비치지 않게(스와이프 느낌).
                      child: ColoredBox(
                        color: sh.bg,
                        child: _buildView(
                            view.mode, view.viewDay, settings.continuousView),
                      ),
                    ),
                  ),
                ),
              ),
              // 스크롤 콘텐츠 가림은 각 뷰 내부의 bottom padding으로 처리
            ],
          ),
          // ── 투명 overlay 상단 헤더 (status bar 위까지) + 좌상단 햄버거 ──
          const AppOverlayTopBar(),
          // ── 우측 하단 + 스피드다이얼 (테마일정·일정·할일) ──
          const _SpeedDialFab(),
        ],
      ),
    );
  }

  // AnimatedSwitcher 전환 단위 key.
  // 월간(비연속)·연간은 날짜가 바뀌면 새 그리드로 교체되도록 연·월을 포함.
  // 연속/주간/일간/홈 등은 내부 상태/파라미터로 갱신되므로 모드만으로 충분.
  String _viewKey(ViewState v, bool continuous) {
    if (v.mode == ViewMode.events && !continuous) {
      return 'events_${v.viewYear}_${v.viewMonth}';
    }
    if (v.mode == ViewMode.year) return 'year_${v.viewYear}';
    return '${v.mode}_$continuous';
  }

  Widget _buildView(ViewMode mode, String? dayKey, bool continuous) {
    switch (mode) {
      case ViewMode.home:      return const HomeView();
      case ViewMode.profile:   return const ProfileView();
      case ViewMode.settings:  return const ProfileView(); // 설정 통합 — 프로필로
      case ViewMode.themes:    return const ThemeSharePage();
      case ViewMode.events:
        return continuous ? const ContinuousWeekView() : const MonthView();
      case ViewMode.year:      return const YearView();
      case ViewMode.planner:   return const PlannerView();
      case ViewMode.day:       return DayView(dateKey: dayKey ?? _todayKey());
      case ViewMode.timetable: return const TimetableView();
    }
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }
}

// ─── 우측 하단 + 스피드다이얼 ─────────────────────────────────────
// 탭하면 테마일정/일정/할일 추가가 위로 촤라락 펼쳐지고, + 가 45° 회전해 ×.
// 배경은 살짝 블러+딤 처리해 선택지가 잘 보이게.
class _SpeedDialFab extends StatefulWidget {
  const _SpeedDialFab();

  @override
  State<_SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<_SpeedDialFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 440));
  bool _open = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      _open ? _c.forward() : _c.reverse();
    });
  }

  void _close() {
    if (!_open) return;
    setState(() {
      _open = false;
      _c.reverse();
    });
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.palette_rounded,
        label: tr('공유 캘린더'),
        onTap: () => showThemeManagerModal(context),
      ),
      (
        icon: Icons.event_rounded,
        label: tr('일정 추가'),
        onTap: () => showAddEditEventModal(context, dateKey: _todayKey()),
      ),
      (
        icon: Icons.check_circle_rounded,
        label: tr('할 일 추가'),
        onTap: () => showAddTodoModal(context),
      ),
      (
        icon: Icons.dashboard_customize_rounded,
        label: tr('기록 템플릿'),
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
              // ── 배경 블러 + 딤 (열렸을 때만 탭 영역) ──
              if (_c.value > 0.001)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _close,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3.5 * v, sigmaY: 3.5 * v),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.26 * v),
                      ),
                    ),
                  ),
                ),
              // ── 옵션 + FAB ──
              Positioned(
                right: 16,
                bottom: bottomInset + 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < actions.length; i++)
                      _buildOption(actions[i], i, actions.length, v, sh),
                    const SizedBox(height: 20),
                    _buildFab(sh, v),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOption(
    ({IconData icon, String label, VoidCallback onTap}) a,
    int i,
    int count,
    double v,
    SurlapColors sh,
  ) {
    // 버튼에서 가까운(아래쪽) 항목이 먼저, 느긋하게 위로 올라오도록 스태거.
    final order = count - 1 - i;
    final t = ((v * (count + 0.6)) - order * 0.85).clamp(0.0, 1.0);
    return IgnorePointer(
      ignoring: t < 0.6,
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 46),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _close();
                a.onTap();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 백드롭 블러+딤이 충분히 어둡게 깔리므로 텍스트 그림자는 빼고,
                    // 부드러운 단일 drop shadow만 살짝 — 검은 외곽선처럼 보이던
                    // 잔상 제거.
                    Icon(a.icon, size: 24, color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 2)),
                        ]),
                    const SizedBox(width: 12),
                    Text(a.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 2)),
                          ],
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFab(SurlapColors sh, double v) {
    return Semantics(
      label: '추가',
      button: true,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          width: 44,
          height: 44,
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
            // 한 바퀴 넘게 휘리릭 돌아 ×로(=2π + 45°).
            angle: v * 7.06858,
            child: const Icon(Icons.add_rounded, size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SlideTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final int direction;

  const _SlideTransition({
    required this.child,
    required this.animation,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    // 방향 없는 전환(연·월·주·일·프로필 등)은 페이드 + 미세 줌으로 부드럽게
    // — 높이 다른 뷰끼리 바뀔 때 툭 끊기는 느낌 완화(살짝 확대되며 안착).
    if (direction == 0) {
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
          child: child,
        ),
      );
    }
    // 좌우 전환은 페이드 없이 슬라이드만 — 불투명 배경이 덮어 스와이프처럼.
    final offset = Tween<Offset>(
      begin: Offset(direction * 0.22, 0),
      end: Offset.zero,
    ).animate(curve);
    return SlideTransition(position: offset, child: child);
  }
}
