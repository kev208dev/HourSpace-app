import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Surlap 워드마크.
///
/// 핸드오프(2026): 심볼·마스코트·그라데이션은 제거됐다. 로고는 본문과 같은
/// Pretendard 로 짜인 워드마크 하나뿐 — 21px / w600 / letter-spacing -0.02em 기준,
/// `size` 로 비례 확대한다(스플래시는 54px / -0.04em).
class SurlapLogo extends StatelessWidget {
  /// 워드마크 폰트 크기.
  final double size;

  /// 지정하지 않으면 본문 잉크색.
  final Color? color;

  const SurlapLogo({super.key, this.size = 21, this.color});

  @override
  Widget build(BuildContext context) {
    // 큰 크기일수록 트래킹을 더 조인다(21px → -.02em, 54px → -.04em).
    final em = size >= 40 ? -0.04 : -0.02;
    return Text(
      'Surlap',
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: em * size,
        height: 1.0,
        color: color ?? context.sh.ink,
      ),
      semanticsLabel: 'Surlap',
    );
  }
}

/// 워드마크 아래에 놓이는 `sig` 언더바 — 스플래시 전용 신호.
/// 60 × 8, pill. 다른 화면에서 강조로 재사용하지 말 것.
class SurlapSigBar extends StatelessWidget {
  final double width;
  final double height;
  const SurlapSigBar({super.key, this.width = 60, this.height = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.sh.sig,
          borderRadius: BorderRadius.circular(999),
        ),
      );
}
