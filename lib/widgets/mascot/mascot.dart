import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

/// Surlap 마스코트(우주 백호) 표정.
enum MascotExpression { neutral, happy, cheering, sleepy, thinking }

/// 마스코트 브랜드 팔레트.
abstract final class MascotColors {
  static const primary = Color(0xFF8B7FF5);
  static const lightPurple = Color(0xFFA99FF8);
  static const mint = Color(0xFF5DCAA5);
  static const coral = Color(0xFFF05995);
  static const orange = Color(0xFFFFB85C);
  static const cream = Color(0xFFFFF7ED);
  static const deepPurple = Color(0xFF3E2D6B);
}

/// 표정별 개별 PNG가 있으면 그것을, 없으면 브랜드 플레이스홀더를 보여준다.
/// 나중에 `assets/mascot/mascot_<expression>.png` 를 넣으면 자동으로 교체됨.
class MascotView extends StatelessWidget {
  final MascotExpression expression;
  final double size;
  final bool showStars;
  const MascotView({
    super.key,
    this.expression = MascotExpression.neutral,
    this.size = 120,
    this.showStars = false,
  });

  /// 표정별 전용 아트(이상적). 있으면 우선 사용.
  String get _asset => 'assets/mascot/mascot_${expression.name}.png';

  /// 전용 표정 PNG가 아직 없을 때 보여줄 실제 캐릭터 포즈.
  /// 절대 이모지/스마일 아이콘으로 떨어지지 않도록 보장한다.
  String get _fallbackAsset => switch (expression) {
        MascotExpression.neutral => 'assets/mascot/mascot_neutral.png',
        MascotExpression.happy => 'assets/mascot/mascot_happy.png',
        MascotExpression.cheering => 'assets/mascot/mascot_cheering.png',
        MascotExpression.sleepy => 'assets/mascot/mascot_sleepy.png',
        MascotExpression.thinking => 'assets/mascot/mascot_thinking.png',
      };

  /// 표정 전용 아트도 없을 때 마지막으로 시도할 실제 캐릭터 기본 포즈.
  /// (front.png 는 항상 존재 — 이모지 플레이스홀더 전 단계.)
  static const String _basePoseAsset = 'assets/mascot/front.png';

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // 1순위: 전용 표정 아트가 없으면 같은 표정의 실제 캐릭터 아트로 폴백.
      errorBuilder: (_, _, _) => Image.asset(
        _fallbackAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // 2순위: 표정 전용 아트도 없으면 항상 존재하는 기본 포즈(front.png)로.
        errorBuilder: (_, _, _) => Image.asset(
          _basePoseAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          // 최후 폴백(마스코트 PNG가 하나도 로드되지 않을 때만): 브랜드 플레이스홀더.
          errorBuilder: (_, _, _) =>
              _MascotPlaceholder(expression: expression, size: size),
        ),
      ),
    );
    if (!showStars) return img;
    return SizedBox(
      width: size * 1.2,
      height: size * 1.1,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          img,
          Positioned(
            top: 0,
            right: size * 0.08,
            child: Icon(Icons.star_rounded,
                size: size * 0.16, color: MascotColors.mint),
          ),
          Positioned(
            bottom: size * 0.06,
            left: size * 0.02,
            child: Icon(Icons.star_rounded,
                size: size * 0.12, color: MascotColors.orange),
          ),
        ],
      ),
    );
  }
}

/// 개별 마스코트 PNG가 없을 때의 임시 표현 — 브랜드 톤의 둥근 블롭 + 표정 아이콘.
class _MascotPlaceholder extends StatelessWidget {
  final MascotExpression expression;
  final double size;
  const _MascotPlaceholder({required this.expression, required this.size});

  IconData get _icon => switch (expression) {
        MascotExpression.neutral => Icons.sentiment_neutral_rounded,
        MascotExpression.happy => Icons.sentiment_satisfied_rounded,
        MascotExpression.cheering => Icons.celebration_rounded,
        MascotExpression.sleepy => Icons.bedtime_rounded,
        MascotExpression.thinking => Icons.psychology_alt_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1ECFF), Color(0xFFE7DEFF)],
        ),
        border: Border.all(
            color: MascotColors.lightPurple.withValues(alpha: 0.5), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(_icon, size: size * 0.46, color: MascotColors.primary),
          // 꼬리 별 느낌의 작은 별
          Positioned(
            top: size * 0.12,
            right: size * 0.16,
            child: Icon(Icons.star_rounded,
                size: size * 0.16, color: MascotColors.lightPurple),
          ),
        ],
      ),
    );
  }
}

/// 빈 상태(데이터 없음) — 마스코트 + 제목 + 설명 + 선택 액션.
class MascotEmptyState extends StatelessWidget {
  final MascotExpression expression;
  final String title;
  final String? message;
  final double mascotSize;
  final String? actionText;
  final VoidCallback? onAction;
  final bool showStars;

  const MascotEmptyState({
    super.key,
    this.expression = MascotExpression.neutral,
    required this.title,
    this.message,
    this.mascotSize = 120,
    this.actionText,
    this.onAction,
    this.showStars = true,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotView(
                expression: expression, size: mascotSize, showStars: showStars),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.bodyLarge.copyWith(
                  fontSize: 16, fontWeight: FontWeight.w800, color: sh.ink),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppType.labelMedium
                    .copyWith(fontSize: 13, color: sh.inkSoft, height: 1.4),
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: sh.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                ),
                child: Text(actionText!,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 카드 안 인라인 빈 상태 — 작은 마스코트 + 문구(+선택 액션).
/// `MascotEmptyState`(큰 중앙형)가 과한, 컴팩트 카드 내부용.
class MascotNote extends StatelessWidget {
  final MascotExpression expression;
  final String text;
  final double mascotSize;
  final Widget? trailing;
  final CrossAxisAlignment align;
  const MascotNote({
    super.key,
    this.expression = MascotExpression.neutral,
    required this.text,
    this.mascotSize = 46,
    this.trailing,
    this.align = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Row(
      crossAxisAlignment: align,
      children: [
        MascotView(expression: expression, size: mascotSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: AppType.bodyLarge
                    .copyWith(color: sh.inkFaint, height: 1.35),
              ),
              if (trailing != null) ...[
                const SizedBox(height: 4),
                trailing!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 작은 마스코트 + 메시지 카드(홈의 응원/휴식 메시지 등).
class MascotMessageCard extends StatelessWidget {
  final MascotExpression expression;
  final String message;
  final Color? tint;
  const MascotMessageCard({
    super.key,
    required this.expression,
    required this.message,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final c = tint ?? sh.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: sh.dark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          MascotView(expression: expression, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppType.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700, color: sh.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
