import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'mascot.dart';

/// 마스코트 토스트 — 완료/오류 피드백을 상단에 부드럽게 띄운다(0.25s scale/fade).
/// 모달이 닫혀도 유지되도록 root overlay에 삽입한다.
class MascotToast {
  MascotToast._();

  static void show(
    BuildContext context,
    String message, {
    MascotExpression expression = MascotExpression.happy,
    bool error = false,
    bool showStars = true,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _MascotToastView(
        message: message,
        expression: expression,
        error: error,
        showStars: showStars,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  /// 완료 피드백(응원).
  static void success(BuildContext context, String message) =>
      show(context, message, expression: MascotExpression.cheering);

  /// 오류/주의 피드백(생각하는 표정).
  static void error(BuildContext context, String message) => show(context,
      message, expression: MascotExpression.thinking, error: true, showStars: false);
}

class _MascotToastView extends StatefulWidget {
  final String message;
  final MascotExpression expression;
  final bool error;
  final bool showStars;
  final VoidCallback onDone;
  const _MascotToastView({
    required this.message,
    required this.expression,
    required this.error,
    required this.showStars,
    required this.onDone,
  });

  @override
  State<_MascotToastView> createState() => _MascotToastViewState();
}

class _MascotToastViewState extends State<_MascotToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _run();
  }

  Future<void> _run() async {
    await _c.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final topPad = MediaQuery.of(context).padding.top;
    final accent = widget.error ? const Color(0xFFF05995) : sh.accent;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return Positioned(
      top: topPad + 10,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _c,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: sh.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: sh.dark ? 0.4 : 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MascotView(
                          expression: widget.expression,
                          size: 34,
                          showStars: false),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: AppType.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700, color: sh.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.showStars) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.star_rounded,
                            size: 16, color: MascotColors.mint),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
