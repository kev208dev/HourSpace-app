import 'package:flutter/material.dart';

/// 디자인 시스템 토큰 — 전 화면 일관 적용용.
/// 색은 기존 프리셋(context.sh)을 그대로 쓰고, 여기서는 간격·반경·타이포·그림자만 정의.
///
/// [2026-07] 사용자 피드백("기존 디자인이 너무 복잡하고 다가가기 힘들다")에 따라
/// 반경/그림자/모션/타이포 토큰을 단순화. 브랜드 색상·테마 인프라는 무변경.
/// 값이 비슷해 구분이 안 되던 토큰(hero/lift/hairline shadow 등)을 정리하고,
/// app_theme.dart의 _buildTextTheme과 어긋나던 이중 타이포 체계를 통합했다.
///
/// 리포 전체에서 아래 삭제된 심볼을 참조하는 곳이 있으면 마이그레이션 필요:
///   Radii.hero, Shadows.hairline/card/lift, Motion.micro/slow/spring/emphasized,
///   AppType.display/title/section/body/caption/label, Borders.thick

abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class Radii {
  static const double small = 8;
  static const double card = 16;
  static const double sheet = 20;
  static const double pill = 999;
}

const double kMinTouch = 44;

abstract final class Shadows {
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> float = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

abstract final class AppType {
  static const TextStyle headlineLarge =
      TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4);
  static const TextStyle titleLarge =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35);
  static const TextStyle titleMedium =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static const TextStyle bodyLarge =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45);
  static const TextStyle bodyMedium =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4);
  static const TextStyle bodySmall =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.35);
  static const TextStyle labelMedium = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0.3);
  static const TextStyle eyebrow = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: 1.2);
  static const TextStyle number =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2);
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;
}

abstract final class Borders {
  static const double hairline = 0.5;
  static const double divider = 1.0;
}
