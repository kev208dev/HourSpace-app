import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';

/// 단계별 튜토리얼(coach mark / 제품 투어).
/// 마스크(어둡게) + 스포트라이트(강조 cutout) + 툴팁(N/M 단계 + 이전/다음)로
/// reference(calendar.html)의 coach mark 방식을 재현 — 정적(항상 화면에 있는)
/// 타겟만 강조한다(서랍/모달 자동 오픈·데모 데이터 주입은 제외).

// 타겟 위젯에 부착할 전역 키 — 모듈 전역에 한 번만 생성해 안정적으로 유지한다.
// (각 키는 트리에 정확히 1개 위젯에만 부착되어야 함)
final coachKeyBottomNav = GlobalKey(debugLabel: 'coach-bottom-nav');
final coachKeyTabTimetable = GlobalKey(debugLabel: 'coach-tab-timetable');
final coachKeyTabProfile = GlobalKey(debugLabel: 'coach-tab-profile');
final coachKeyBtnCategory = GlobalKey(debugLabel: 'coach-btn-category');
final coachKeyBtnSettings = GlobalKey(debugLabel: 'coach-btn-settings');

class CoachStep {
  /// null이면 화면 중앙 안내(스포트라이트 없는 텍스트 단계).
  final GlobalKey? targetKey;
  final String title;
  final String desc;
  final String? extra;
  const CoachStep({
    this.targetKey,
    required this.title,
    required this.desc,
    this.extra,
  });
}

/// 정적 타겟 기반 기본 투어.
List<CoachStep> get kCoachSteps => [
      CoachStep(
        title: tr('사용법을 안내해드릴게요'),
        desc: tr('강조된 부분을 보면서 [다음 →]으로 따라오시면 됩니다. '
            '오른쪽 위 ✕ 로 언제든 종료할 수 있어요.'),
      ),
      CoachStep(
        targetKey: coachKeyBottomNav,
        title: tr('아래 바로 화면 전환'),
        desc: tr('꾸미기 · 일정 · 플래너 · 시간표 · 프로필. 화면 아래 둥근 바에서 '
            '원하는 화면으로 바로 이동해요.'),
      ),
      CoachStep(
        targetKey: coachKeyTabTimetable,
        title: tr('시간표'),
        desc: tr('요일 + 교시 시간표예요. 학교를 연결하면 수업과 급식이 자동으로 '
            '채워지고, 빈 칸은 직접 눌러 입력할 수 있어요.'),
      ),
      CoachStep(
        targetKey: coachKeyBtnSettings,
        title: tr('설정 · 보기 옵션'),
        desc: tr('카테고리 필터, 지난 날 표시 / 알림 / 연속 보기, '
            '반복 시간표 설정과 학교 연결(NEIS)을 여기서 관리해요.'),
      ),
      CoachStep(
        targetKey: coachKeyBtnCategory,
        title: tr('카테고리'),
        desc: tr('일정 카테고리(캘린더)를 만들고 색을 지정할 수 있어요. '
            '색으로 일정을 한눈에 구분해요.'),
      ),
      CoachStep(
        targetKey: coachKeyTabProfile,
        title: tr('프로필'),
        desc: tr('이름 · 프로필 사진 · 학교 연결 · 정보 백업 · 로그아웃은 '
            '프로필에서 관리해요.'),
      ),
      CoachStep(
        title: tr('준비 완료!'),
        desc: tr('핵심 기능을 다 둘러봤어요. 필요할 땐 언제든 '
            '설정 ▸ 사용법 안내 에서 다시 볼 수 있어요.'),
      ),
    ];

/// 코치마크 투어를 띄운다. 페이지 위젯(타겟 키)은 그대로 뒤에 남아 있어
/// 측정이 가능하다.
Future<void> showCoachMarks(BuildContext context, {List<CoachStep>? steps}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent, // 마스크는 직접 그린다
    barrierLabel: 'coach',
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => _CoachOverlay(steps: steps ?? kCoachSteps),
    transitionBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _CoachOverlay extends StatefulWidget {
  final List<CoachStep> steps;
  const _CoachOverlay({required this.steps});

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  int _i = 0;

  Rect? _targetRect(CoachStep step) {
    final key = step.targetKey;
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  void _next() {
    if (_i >= widget.steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _i++);
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final size = MediaQuery.of(context).size;
    final step = widget.steps[_i];
    final rawRect = _targetRect(step);
    // 화면 안으로 약간 안전 클램프
    final rect = rawRect == null
        ? null
        : Rect.fromLTRB(
            rawRect.left.clamp(0.0, size.width),
            rawRect.top.clamp(0.0, size.height),
            rawRect.right.clamp(0.0, size.width),
            rawRect.bottom.clamp(0.0, size.height),
          );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 마스크 + 스포트라이트 — 빈 곳 탭은 무시(모달)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // 마스크 영역 탭 흡수
              child: CustomPaint(
                painter: _MaskPainter(
                  hole: rect,
                  radius: 14,
                  color: Colors.black.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
          _positionedCard(sh, size, step, rect),
        ],
      ),
    );
  }

  Widget _positionedCard(
      SurlapColors sh, Size size, CoachStep step, Rect? rect) {
    final card = _Card(
      sh: sh,
      step: step,
      index: _i,
      total: widget.steps.length,
      onNext: _next,
      onPrev: _prev,
      onClose: _close,
    );

    if (rect == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: card));
    }
    // 스포트라이트가 위쪽이면 카드는 아래, 아래쪽이면 카드는 위에 배치.
    final below = rect.center.dy < size.height / 2;
    if (below) {
      return Positioned(
        top: rect.bottom + 16,
        left: 16,
        right: 16,
        child: Align(alignment: Alignment.topCenter, child: card),
      );
    }
    return Positioned(
      bottom: size.height - rect.top + 16,
      left: 16,
      right: 16,
      child: Align(alignment: Alignment.bottomCenter, child: card),
    );
  }
}

class _Card extends StatelessWidget {
  final SurlapColors sh;
  final CoachStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;
  const _Card({
    required this.sh,
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: sh.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: sh.accentBg,
                  borderRadius: BorderRadius.circular(Radii.small),
                ),
                child: Text('${index + 1} / $total',
                    style: AppType.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: sh.accentInk)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 18, color: sh.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(step.title,
              style: AppType.titleMedium.copyWith(fontWeight: FontWeight.w700, color: sh.ink)),
          const SizedBox(height: Gap.sm),
          Text(step.desc,
              style: AppType.bodyLarge.copyWith(color: sh.inkSoft, height: 1.45)),
          if (step.extra != null) ...[
            const SizedBox(height: Gap.sm),
            Text(step.extra!,
                style: AppType.bodySmall.copyWith(color: sh.inkFaint, height: 1.45)),
          ],
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              if (index > 0)
                TextButton(
                  onPressed: onPrev,
                  style: TextButton.styleFrom(foregroundColor: sh.inkSoft),
                  child: Text(tr('이전')),
                ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                child: Text(isLast ? tr('완료') : tr('다음 →')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  final Rect? hole;
  final double radius;
  final Color color;
  const _MaskPainter({
    required this.hole,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, paint);
      return;
    }
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          hole!.inflate(6), Radius.circular(radius)));
    final masked = Path.combine(PathOperation.difference, full, holePath);
    canvas.drawPath(masked, paint);
    // 스포트라이트 테두리(살짝 강조)
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole!.inflate(6), Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.hole != hole || old.color != color || old.radius != radius;
}
