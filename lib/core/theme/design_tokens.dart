import 'package:flutter/material.dart';

/// 디자인 토큰 — 핸드오프(2026) 스펙 그대로. 색은 `context.sh`(SurlapColors),
/// 여기서는 간격·반경·타이포·그림자·모션만 정의한다.
///
/// 목업 캔버스는 412 × 896 dp(Android). px = dp.

/// 4px 기반 간격 스케일. space-1/2/3/4/6/8.
abstract final class Gap {
  static const double xs = 4;   // space-1
  static const double sm = 8;   // space-2
  static const double md = 12;  // space-3
  static const double lg = 16;  // space-4 — 화면 좌우/카드 기본 패딩
  static const double xl = 24;  // space-6 — 섹션 간 간격
  static const double xxl = 36; // space-8
}

/// 모서리 반경. 모든 버튼·태그·칩은 pill.
abstract final class Radii {
  static const double small = 8;   // radius-sm — 색상 스와치보다 큰 작은 요소
  static const double swatch = 4;  // 색상 스와치
  static const double md = 12;     // radius-md — 입력·작은 카드
  static const double card = 20;   // radius-lg — 카드 기본
  static const double hero = 22;   // 카드 변형(강조 카드)
  static const double sheet = 24;  // 바텀시트 상단
  static const double pill = 999;  // 버튼·태그·칩
  static const double phone = 33;  // 폰 프레임
}

/// 최소 터치 영역.
const double kMinTouch = 44;

/// 그림자 — 라이트/다크가 다르다. 호출부는 `Shadows.card(dark)` 형태로 쓴다.
abstract final class Shadows {
  /// 0 1px 2px rgba(15,15,14,.07) / dark 0 1px 2px rgba(0,0,0,.5)
  static List<BoxShadow> sm(bool dark) => [
        BoxShadow(
          color: dark ? const Color(0x80000000) : const Color(0x120F0F0E),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// 0 6px 18px rgba(15,15,14,.10) / dark 0 6px 18px rgba(0,0,0,.55)
  static List<BoxShadow> md(bool dark) => [
        BoxShadow(
          color: dark ? const Color(0x8C000000) : const Color(0x1A0F0F0E),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  /// 0 22px 48px rgba(15,15,14,.16) / dark 0 22px 48px rgba(0,0,0,.65)
  static List<BoxShadow> lg(bool dark) => [
        BoxShadow(
          color: dark ? const Color(0xA6000000) : const Color(0x290F0F0E),
          blurRadius: 48,
          offset: const Offset(0, 22),
        ),
      ];

  /// 카드 기본 — shadow-sm.
  static List<BoxShadow> card(bool dark) => sm(dark);

  /// 들린 카드·토스트 — shadow-md.
  static List<BoxShadow> lift(bool dark) => md(dark);

  /// 시트·다이얼로그 — shadow-lg.
  static List<BoxShadow> float(bool dark) => lg(dark);
}

/// 타이포 스케일. 서체는 Pretendard 단일. 색상은 호출부에서 copyWith(color:).
///
/// 기본 letter-spacing -0.01em, 제목 -0.03em, 큰 숫자·날짜 -0.02em
/// (Flutter의 letterSpacing 은 px 이므로 fontSize × em 으로 환산해 둠).
abstract final class AppType {
  /// 앱 로고 / 대형 날짜 — 21 / 600 / -0.02em
  static const TextStyle display = TextStyle(
      fontSize: 21, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.42);

  /// 화면 제목 — 18 / 700 / -0.03em
  static const TextStyle title = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.54);

  /// 섹션 헤딩 · 시트 제목 — 17 / 700 / -0.03em
  static const TextStyle section = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.51);

  /// 카드 타이틀 — 16 / 700
  static const TextStyle cardTitle = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w700, height: 1.35, letterSpacing: -0.16);

  /// 강조 수치 · 다이얼로그 제목 — 15 / 700
  static const TextStyle number = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.3);

  /// 버튼 라벨 — 14.5 / 600
  static const TextStyle button = TextStyle(
      fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -0.145);

  /// 본문 — 13 / 400 / line-height 1.6
  static const TextStyle body = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w400, height: 1.6, letterSpacing: -0.13);

  /// 본문 강조 — 13 / 700
  static const TextStyle bodyStrong = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700, height: 1.6, letterSpacing: -0.13);

  /// 보조 본문 — 12.5 / 400 / line-height 1.6
  static const TextStyle sub = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.6, letterSpacing: -0.125);

  /// 캡션 — 11.5 / 400
  static const TextStyle caption = TextStyle(
      fontSize: 11.5, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: -0.115);

  /// 라벨 · 오버라인 — 11 / 600 (대문자 변환 없음)
  static const TextStyle label = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.11);

  /// 마이크로 라벨 · 배지 — 10.5 / 700. 읽는 텍스트에는 쓰지 말 것.
  static const TextStyle micro = TextStyle(
      fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0);

  /// 구버전 호환 — 오버라인은 label 과 동일 취급(대문자 트래킹 없음).
  static const TextStyle eyebrow = label;
}

/// 알파 단계 — 목업이 `color-mix(text N%)` 로 쓰던 값들.
abstract final class Alpha {
  static const double bodySoft = 0.58;   // 본문 보조 55–60%
  static const double caption = 0.48;    // 캡션·메타 45–50%
  static const double iconIdle = 0.38;   // 비활성 아이콘
  static const double placeholder = 0.32;
  static const double past = 0.45;       // 지난 시각 일정 감쇠
}

/// 모션 토큰.
abstract final class Motion {
  /// 상태 전환(버튼 hover/press) — background/color .14s ease
  static const Duration micro = Duration(milliseconds: 140);

  /// fade — 화면 전환
  static const Duration fast = Duration(milliseconds: 200);

  /// up — 카드·리스트 등장(translateY 14 → 0 + fade)
  static const Duration base = Duration(milliseconds: 240);

  /// sheet — 바텀시트(translateY 100% → 0)
  static const Duration slow = Duration(milliseconds: 250);

  /// 카드·리스트 등장 시 Y 이동 거리.
  static const double riseOffset = 14;

  static const Curve curve = Curves.easeOut;
  static const Curve spring = Curves.easeOutBack;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// 스켈레톤 pulse(opacity .3 ↔ 1) 한 주기.
  static const Duration pulse = Duration(milliseconds: 1400);
}

/// 보더 두께.
abstract final class Borders {
  static const double hairline = 1.0; // 목업의 divider 는 전부 1px
  static const double divider = 1.0;
  static const double thick = 1.5;    // 선택 날짜 링
}
