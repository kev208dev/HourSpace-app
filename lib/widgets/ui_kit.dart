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

  /// 헤더 안에 끼워 넣는 짧은 텍스트 액션("오늘", "하루 보기").
  /// 여백만 줄이고 타이포·색은 그대로 둔다.
  final bool dense;

  const SurlapButton({
    super.key,
    required this.label,
    this.onTap,
    this.kind = SurlapButtonKind.primary,
    this.block = false,
    this.icon,
    this.destructive = false,
    this.dense = false,
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
          padding: dense
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
              : EdgeInsets.symmetric(
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
// 앱 전체의 유일한 섹션 제목 컴포넌트. 화면마다 private 헤딩을 만들지 않는다.

/// 섹션 제목의 두 단계.
///
/// 하나로 합치지 않은 이유: 목업에 실제로 두 티어가 있다. 화면을 나누는
/// 큰 제목(다가오는 일정 / 할 일)과, 카드 묶음 위에 얹는 작은 오버라인
/// (학교 / 기록 / 앱, 날짜 있는 할 일)은 시각적 무게가 다르다.
enum SurlapSectionStyle {
  /// h4 17 / 700 — 화면을 나누는 섹션 제목.
  heading,

  /// 11 / 600 @50% — 카드 묶음 위 오버라인 라벨.
  overline,
}

class SurlapSection extends StatelessWidget {
  final String title;

  /// 제목 오른쪽에 붙는 위젯(수치 배지 등).
  final Widget? trailing;

  /// 제목 오른쪽 짧은 수치(예: `2/5`). [trailing] 보다 먼저 그린다.
  final String? counter;

  /// 우측 텍스트 액션.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 화면 첫 섹션이면 위 여백을 줄인다.
  final bool first;

  final SurlapSectionStyle style;

  const SurlapSection({
    super.key,
    required this.title,
    this.trailing,
    this.counter,
    this.actionLabel,
    this.onAction,
    this.first = false,
    this.style = SurlapSectionStyle.heading,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final overline = style == SurlapSectionStyle.overline;
    return Padding(
      padding: EdgeInsets.only(top: first ? Gap.md : Gap.xl, bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: overline
                  ? AppType.label.copyWith(color: sh.ink.withValues(alpha: 0.50))
                  : AppType.section.copyWith(color: sh.ink),
            ),
          ),
          if (counter != null)
            Text(counter!, style: AppType.number.copyWith(color: sh.inkSoft)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: Gap.xs),
            SurlapButton(
              label: actionLabel!,
              onTap: onAction,
              kind: SurlapButtonKind.ghost,
              dense: true,
            ),
          ],
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

  /// 목록형 카드 — 내부 여백 0 + 모서리 클립. 행이 divider 로 나뉘는 카드에 쓴다.
  final bool list;

  const SurlapCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.raised = false,
    this.color,
    this.list = false,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final radius =
        BorderRadius.circular(raised ? Radii.hero : Radii.card);
    final body = Container(
      padding: padding ?? (list ? EdgeInsets.zero : const EdgeInsets.all(Gap.lg)),
      clipBehavior: list ? Clip.antiAlias : Clip.none,
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

/// 목록형 카드([SurlapCard.list]) 안의 행 하나.
///
/// 여백과 divider 만 책임진다. 내용은 화면이 채운다 — 할 일 행과 설정 행은
/// 담는 것이 달라서 내용까지 공용화하면 오히려 기능이 뒤틀린다.
class SurlapRow extends StatelessWidget {
  final Widget child;

  /// 마지막 행이면 아래 divider 를 그리지 않는다.
  final bool last;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 완료된 항목처럼 흐리게 보여야 할 때.
  final double opacity;

  const SurlapRow({
    super.key,
    required this.child,
    this.last = false,
    this.onTap,
    this.onLongPress,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final body = Opacity(
      opacity: opacity,
      child: Container(
        padding: kListRowPadding,
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: sh.border)),
        ),
        child: child,
      ),
    );
    if (onTap == null && onLongPress == null) return body;
    return InkWell(onTap: onTap, onLongPress: onLongPress, child: body);
  }
}

// ─── 세그먼트 컨트롤 ────────────────────────────────────────────────
// 테두리 1px + radius 12, 선택 칸은 accent 채움 + bg 글자, 칸 사이 세로 divider.

/// 세그먼트 한 칸.
typedef SurlapSegment = ({String label, String? semanticsLabel});

SurlapSegment surlapSegment(String label, {String? semanticsLabel}) =>
    (label: label, semanticsLabel: semanticsLabel);

/// 캘린더 보기 모드(4칸)와 공유 탭(2칸)이 같은 컴포넌트를 쓴다.
class SurlapSegmentedControl extends StatelessWidget {
  final List<SurlapSegment> segments;
  final int index;
  final ValueChanged<int> onChanged;

  /// 가로를 꽉 채울지. 기본은 내용 폭(좌측 정렬).
  final bool expand;

  const SurlapSegmentedControl({
    super.key,
    required this.segments,
    required this.index,
    required this.onChanged,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < segments.length; i++)
          _cell(context, i, sh),
      ],
    );

    return Container(
      height: kSegmentHeight,
      decoration: BoxDecoration(
        border: Border.all(color: sh.border),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: row,
    );
  }

  Widget _cell(BuildContext context, int i, SurlapColors sh) {
    final selected = i == index;
    final cell = Semantics(
      button: true,
      selected: selected,
      label: segments[i].semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: Motion.micro,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: selected ? sh.accent : Colors.transparent,
            border:
                i == 0 ? null : Border(left: BorderSide(color: sh.border)),
          ),
          child: Text(
            segments[i].label,
            style: AppType.sub.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? sh.bg : sh.ink,
            ),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: cell) : cell;
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
///
/// [boxed] 를 켜면 card2 박스로 감싼다. 목록 아래에서 한 덩어리로 읽혀야 하는
/// 안내(저장 범위 고지 등)에 쓴다.
class SurlapNotice extends StatelessWidget {
  final String message;
  final bool boxed;
  const SurlapNotice(this.message, {super.key, this.boxed = false});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline_rounded,
              size: boxed ? 16 : 14, color: sh.inkCaption),
        ),
        SizedBox(width: boxed ? Gap.sm : 7),
        Expanded(
          child: Text(message,
              style: (boxed ? AppType.sub : AppType.caption)
                  .copyWith(color: sh.inkBody, height: 1.6)),
        ),
      ],
    );

    if (!boxed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: row,
      );
    }
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: row,
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

/// 목록 안 빈 자리 한 줄 — 화면 전체가 비지 않고 한 섹션만 비었을 때.
///
/// [SurlapEmptyState] 는 아이콘 + 제목 + 액션까지 있는 큰 빈 상태다. 섹션
/// 하나가 비었을 뿐인데 그걸 쓰면 화면이 빈 상태로 도배된다. 그 자리는 전부
/// 이 컴포넌트 하나로 통일한다(예전에는 맨 Text · card2 박스 · 인라인 Text 가
/// 화면마다 섞여 있었다).
class SurlapInlineEmptyState extends StatelessWidget {
  final String message;
  const SurlapInlineEmptyState(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Text(
        message,
        style: AppType.sub.copyWith(height: 1.55, color: sh.inkBody),
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
