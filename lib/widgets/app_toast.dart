import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';

/// 앱 전역에서 사용하는 짧은 성공/오류 피드백입니다.
class AppToast {
  AppToast._();

  static void show(BuildContext context, String message, {bool error = false}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppToastView(
        message: message,
        error: error,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  static void success(BuildContext context, String message) =>
      show(context, message);

  static void error(BuildContext context, String message) =>
      show(context, message, error: true);
}

class _AppToastView extends StatefulWidget {
  final String message;
  final bool error;
  final VoidCallback onDone;

  const _AppToastView({
    required this.message,
    required this.error,
    required this.onDone,
  });

  @override
  State<_AppToastView> createState() => _AppToastViewState();
}

class _AppToastViewState extends State<_AppToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final topPad = MediaQuery.of(context).padding.top;
    final accent = widget.error ? const Color(0xFFF05995) : sh.accent;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    return Positioned(
      top: topPad + 10,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _controller,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
              alignment: Alignment.topCenter,
              child: Semantics(
                liveRegion: true,
                label: widget.message,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: kMinTouch),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md,
                      vertical: Gap.sm,
                    ),
                    decoration: BoxDecoration(
                      color: sh.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: sh.dark ? 0.4 : 0.12,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.error
                                ? Icons.error_outline_rounded
                                : Icons.check_rounded,
                            size: 19,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: AppType.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: sh.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
