import 'package:flutter/material.dart';

/// 색 팔레트 — 디자인 핸드오프(2026) 기준.
///
/// 라이트는 따뜻한 오프화이트 지면 위에 일렉트릭 블루 액센트,
/// 다크는 같은 구조를 뒤집은 값. `sig`(애시드 라임)는 "오늘" 신호 전용이라
/// 라이트·다크가 동일하다.
class ColorPreset {
  final String id;
  final String name;

  /// 항목 있음 표시용 점.
  final Color dot;

  /// 기본 인터랙션 색.
  final Color accent;

  /// 액센트 틴트 위에 얹는 진한 글자색(accent-800).
  final Color accentInk;

  /// 액센트 틴트 배경(accent-100).
  final Color accentBg;

  /// 액센트 틴트 배경 강(accent-200).
  final Color accentBg2;

  /// hover / pressed, 틴트 위 텍스트(accent-700).
  final Color accentPressed;

  /// accent 채움 위 텍스트.
  final Color onAccent;

  /// 경고·생일·삭제(accent-2).
  final Color accent2;
  final Color accent2Bg;
  final Color accent2Ink;

  /// "오늘" 신호 전용.
  final Color sig;
  final Color sigInk;

  /// 화면 배경.
  final Color app;

  /// 카드·시트·입력 필드.
  final Color card;

  /// 함몰된 면, 비활성 트랙, 아바타 배경(surface).
  final Color card2;

  /// 구분선·테두리.
  final Color hairline;

  final Color ink;
  final Color inkSoft;
  final Color inkFaint;

  final bool dark;

  const ColorPreset({
    required this.id,
    required this.name,
    required this.dot,
    required this.accent,
    required this.accentInk,
    required this.accentBg,
    required this.accentBg2,
    required this.accentPressed,
    required this.onAccent,
    required this.accent2,
    required this.accent2Bg,
    required this.accent2Ink,
    required this.sig,
    required this.sigInk,
    required this.app,
    required this.card,
    required this.card2,
    required this.hairline,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    this.dark = false,
  });
}

/// "오늘" 신호 — 라이트·다크 공통. 다른 강조에 쓰지 말 것.
const kSig = Color(0xFFD8FF3D);
const kSigInk = Color(0xFF0F0F0E);

const kDefaultPreset = ColorPreset(
  id: 'light',
  name: 'Surlap',
  dot: Color(0xFF1B4DFF),
  accent: Color(0xFF1B4DFF),
  accentInk: Color(0xFF0A2489),
  accentBg: Color(0xFFEAEEFF),
  accentBg2: Color(0xFFD2DBFF),
  accentPressed: Color(0xFF0F31B8),
  onAccent: Color(0xFFFFFFFF),
  accent2: Color(0xFFD1330F),
  accent2Bg: Color(0xFFFFEDE7),
  accent2Ink: Color(0xFF8E2810),
  sig: kSig,
  sigInk: kSigInk,
  app: Color(0xFFFBFBF9),
  card: Color(0xFFFFFFFF),
  card2: Color(0xFFF1F1ED),
  hairline: Color(0x1A0F0F0E), // #0F0F0E 10%
  ink: Color(0xFF0F0F0E),
  inkSoft: Color(0xFF8C8C87), // neutral-500
  inkFaint: Color(0x610F0F0E), // ink 38% — 비활성 아이콘
  dark: false,
);

const kDarkPreset = ColorPreset(
  id: 'dark',
  name: 'Surlap Dark',
  dot: Color(0xFF8AA4FF),
  accent: Color(0xFF8AA4FF),
  accentInk: Color(0xFFD5DEFF),
  accentBg: Color(0xFF161B38),
  accentBg2: Color(0xFF20295E),
  accentPressed: Color(0xFFB6C5FF),
  onAccent: Color(0xFF0C0C0B), // dark 에서는 bg 색이 onAccent
  accent2: Color(0xFFFF7A5E),
  accent2Bg: Color(0xFF3A1A12),
  accent2Ink: Color(0xFFFFC9BA),
  sig: kSig,
  sigInk: kSigInk,
  app: Color(0xFF0C0C0B),
  card: Color(0xFF161615),
  card2: Color(0xFF1A1A18),
  hairline: Color(0x24F4F4EF), // #F4F4EF 14%
  ink: Color(0xFFF4F4EF),
  inkSoft: Color(0xFF7C7C76), // neutral-500
  inkFaint: Color(0x61F4F4EF), // ink 38%
  dark: true,
);

// presetById 호출 코드 하위 호환용
ColorPreset presetById(String id) => id == 'dark' ? kDarkPreset : kDefaultPreset;
