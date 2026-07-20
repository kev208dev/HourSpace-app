import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// 누름 시 미세하게 줄어드는 카드/타일 래퍼.
/// 대기업 앱 특유의 "탭 반응 있음" 느낌을 통일적으로 부여.
/// 텍스트 버튼·아이콘은 자체 ripple 이 있으므로 카드/타일 단위에서만 사용.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;
  final double pressedScale;
  final Duration duration;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
    this.pressedScale = 0.97,
    this.duration = Motion.fast,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}
