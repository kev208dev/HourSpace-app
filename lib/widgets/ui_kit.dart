import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';

/// 핸드오프(2026) 공통 컴포넌트.
///
/// 이 디자인은 상자로 화면을 나누지 않는다 — 구획은 여백과 타이포가 만든다.
/// `SurlapCard` 는 목록 항목처럼 실제로 분리된 덩어리에만 쓴다.

// ─── 버튼 ───────────────────────────────────────────────────────────
// 전부 pill(999), weight 600, nowrap, 1px 투명 테두리.

enum SurlapButtonKind { primary, secondary, ghost }

class SurlapButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final SurlapButtonKind kind;

  /// 폭 100% + padding 13 + font 14.5.
  final bool block;
  final IconData? icon;

  /// 파괴적 액션 — accent-2 로 칠한다.
  final bool destructive;

  const SurlapButton({
    super.key,
    required this.label,
    this.onTap,
    this.kind = SurlapButtonKind.primary,
    this.block = false,
    this.icon,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final base = destructive ? sh.accent2 : sh.accent;
    final pressed = destructive ? sh.accent2Ink : sh.accentPressed;

    late final Color bg;
    late final Color fg;
    late final Color line;
    switch (kind) {
      case SurlapButtonKind.primary:
        bg = base;
        fg = sh.onAccent;
        line = Colors.transparent;
      case SurlapButtonKind.secondary:
        bg = sh.card;
        fg = destructive ? base : sh.ink;
        line = sh.border;
      case SurlapButtonKind.ghost:
        bg = Colors.transparent;
        fg = base;
        line = Colors.transparent;
    }

    final child = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: AppType.button.copyWith(color: fg),
        ),
      ],
    );

    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        highlightColor: pressed.withValues(alpha: 0.16),
        splashColor: pressed.withValues(alpha: 0.12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: block ? Gap.lg : 18,
            vertical: 13,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── 태그 / 칩 ──────────────────────────────────────────────────────

enum SurlapTagTone { accent, accent2, neutral, sig }

class SurlapTag extends StatelessWidget {
  final String label;
  final SurlapTagTone tone;

  /// 배지형 — padding 3/9, font 10.5 / 700.
  final bool badge;
  final IconData? icon;
  final VoidCallback? onTap;

  const SurlapTag({
    super.key,
    required this.label,
    this.tone = SurlapTagTone.neutral,
    this.badge = false,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    late final Color bg;
    late final Color fg;
    switch (tone) {
      case SurlapTagTone.accent:
        bg = sh.accentBg;
        fg = sh.accentInk;
      case SurlapTagTone.accent2:
        bg = sh.accent2Bg;
        fg = sh.accent2Ink;
      case SurlapTagTone.neutral:
        bg = sh.card2;
        fg = sh.ink;
      case SurlapTagTone.sig:
        bg = sh.sig;
        fg = sh.sigInk;
    }

    final body = Container(
      padding: badge
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?(icon == null ? null : Icon(icon, size: badge ? 11 : 13, color: fg)),
          if (icon != null) const SizedBox(width: 5),
          Text(
            label,
            style: (badge ? AppType.micro : AppType.body)
                .copyWith(color: fg, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: body,
    );
  }
}

// ─── 섹션 헤딩 ──────────────────────────────────────────────────────
// h4 17 / 700, 위 space-6 · 아래 space-2.

class SurlapSection extends StatelessWidget {
  final String title;
  final Widget? trailing;

  /// 화면 첫 섹션이면 위 여백을 줄인다.
  final bool first;

  const SurlapSection({
    super.key,
    required this.title,
    this.trailing,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? Gap.md : Gap.xl, bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(title,
                style: AppType.section.copyWith(color: context.sh.ink)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 필드 라벨 — 12 / 600 / text 60%.
class SurlapFieldLabel extends StatelessWidget {
  final String text;
  const SurlapFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppType.label.copyWith(
          fontSize: 12,
          color: context.sh.ink.withValues(alpha: 0.6),
        ),
      );
}

// ─── 카드 ───────────────────────────────────────────────────────────
// card 배경, radius 20–22, shadow-sm(강조 시 md), padding space-3~4.

class SurlapCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// 강조 카드 — radius 22 + shadow-md.
  final bool raised;
  final Color? color;

  const SurlapCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.raised = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final radius =
        BorderRadius.circular(raised ? Radii.hero : Radii.card);
    final body = Container(
      padding: padding ?? const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: color ?? sh.card,
        borderRadius: radius,
        boxShadow: raised ? sh.shadowLift : sh.shadowCard,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: body,
      ),
    );
  }
}

// ─── 경고 배너 ──────────────────────────────────────────────────────
// accent-2-100 배경 + accent-2-800 텍스트. 파괴적 확인 1단계.

class SurlapWarningBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SurlapWarningBanner({
    super.key,
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.accent2Bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: sh.accent2Ink),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: AppType.body
                        .copyWith(color: sh.accent2Ink, height: 1.5)),
                if (actionLabel != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: AppType.sub.copyWith(
                        color: sh.accent2Ink,
                        decoration: TextDecoration.underline,
                        decorationColor: sh.accent2Ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 인앱 고지 — 원본 앱의 알려진 한계를 화면에 그대로 노출할 때.
class SurlapNotice extends StatelessWidget {
  final String message;
  const SurlapNotice(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline_rounded,
                size: 14, color: sh.inkCaption),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(message,
                style: AppType.caption
                    .copyWith(color: sh.inkCaption, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

// ─── 빈 상태 ────────────────────────────────────────────────────────
// 아이콘 28–32 + 제목 16/700 + 설명 12.5/1.6(55%) + 액션 버튼.

class SurlapEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SurlapEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.xl, vertical: Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: sh.ink.withValues(alpha: Alpha.iconIdle)),
            const SizedBox(height: Gap.md),
            Text(title,
                textAlign: TextAlign.center,
                style: AppType.cardTitle.copyWith(color: sh.ink)),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description!,
                  textAlign: TextAlign.center,
                  style: AppType.sub.copyWith(color: sh.inkBody)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: Gap.lg),
              SurlapButton(label: actionLabel!, onTap: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 로딩 ───────────────────────────────────────────────────────────

/// 스켈레톤 — opacity .3 ↔ 1 로 맥동.
class SurlapSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const SurlapSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = Radii.small,
  });

  @override
  State<SurlapSkeleton> createState() => _SurlapSkeletonState();
}

class _SurlapSkeletonState extends State<SurlapSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.pulse)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.sh.card2,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// 인라인 스피너 + 문구.
class SurlapLoadingRow extends StatelessWidget {
  final String label;
  const SurlapLoadingRow(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: sh.accent),
        ),
        const SizedBox(width: 9),
        Text(label, style: AppType.body.copyWith(color: sh.inkBody)),
      ],
    );
  }
}

// ─── 바텀시트 핸들 ──────────────────────────────────────────────────
// 40 × 4, divider 색, 시트 상단 가운데.

class SurlapSheetHandle extends StatelessWidget {
  const SurlapSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: Gap.md),
        decoration: BoxDecoration(
          color: context.sh.border,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      );
}

// ─── 토스트 ─────────────────────────────────────────────────────────
// 화면 하단(탭바 위, bottom 96)에 떠오르고 자동 소멸.
// 목업 기준 잉크 반전 — text 배경 + bg 글자, radius 12, shadow-md.

void showSurlapToast(BuildContext context, String message) {
  final sh = context.sh;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message,
          style: AppType.body.copyWith(color: sh.bg, height: 1.5)),
      backgroundColor: sh.ink,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, 96),
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

// ─── 등장 애니메이션 ────────────────────────────────────────────────
// up — translateY 14 → 0 + opacity 0 → 1.

class SurlapRise extends StatelessWidget {
  final Widget child;
  final int index;
  const SurlapRise({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Duration(milliseconds: 30 * index),
      curve: Motion.curve,
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * Motion.riseOffset),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
