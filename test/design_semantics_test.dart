import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surlap/core/constants/color_presets.dart';
import 'package:surlap/core/theme/app_theme.dart';

/// 2026 디자인 시스템 위에서도 스펙 §6 의 색 규칙이 유지되는지 확인한다.
///
///   Warm Off-white = 앱 배경
///   Electric Blue  = 선택 / 버튼 / 주요 interaction
///   Acid Lime      = 지금 / 오늘  ← 이 의미로만
///   Coral Red      = 경고 / 충돌 / destructive
void main() {
  SurlapColors light() => const SurlapColors(preset: kDefaultPreset);
  SurlapColors dark() => const SurlapColors(preset: kDarkPreset);

  test('시그니처 라임이 Now/Today 색이다', () {
    expect(light().now, kSig);
    expect(dark().now, kSig);
    expect(kSig, const Color(0xFFD8FF3D));
  });

  test('Now 위 글자색은 대비를 위해 어두운 잉크', () {
    expect(light().onNow, kSigInk);
    expect(kSigInk, const Color(0xFF0F0F0E));
  });

  test('Now 와 accent 는 서로 다른 색이다 — 신호가 겹치면 안 된다', () {
    expect(light().now, isNot(light().accent));
    expect(dark().now, isNot(dark().accent));
  });

  test('accent 는 일렉트릭 블루', () {
    expect(light().accent, const Color(0xFF1B4DFF));
  });

  test('danger 는 코럴 — accent 와 구분된다', () {
    expect(light().danger, const Color(0xFFD1330F));
    expect(light().danger, isNot(light().accent));
    expect(light().danger, isNot(light().now));
  });

  test('앱 배경은 웜 오프화이트', () {
    expect(light().bg, const Color(0xFFFBFBF9));
  });

  test('nowBg 는 라임 계열의 옅은 배경이다', () {
    expect(light().nowBg.toARGB32() & 0xFFFFFF, kSig.toARGB32() & 0xFFFFFF);
    expect(light().nowBg.a, lessThan(1.0));
  });

  test('다크 프리셋도 네 가지 역할이 모두 구분된다', () {
    final d = dark();
    final roles = {d.now, d.accent, d.danger, d.bg};
    expect(roles.length, 4, reason: '역할별 색이 겹치면 의미 전달이 무너진다');
  });
}
