import 'package:flutter/material.dart';
import '../constants/color_presets.dart';
import 'design_tokens.dart';

/// ColorPreset → Flutter ThemeData 변환. 핸드오프(2026) 토큰 기준.
///
///   bg       → scaffold background
///   card     → card / surface / 입력 필드
///   surface  → 함몰된 면(card2)
///   accent   → primary
///   text     → onSurface
///   divider  → outline
ThemeData buildTheme(ColorPreset p) {
  final cs = ColorScheme(
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentBg,
    onPrimaryContainer: p.accentInk,
    secondary: p.accent,
    onSecondary: p.onAccent,
    secondaryContainer: p.accentBg2,
    onSecondaryContainer: p.accentInk,
    surface: p.card,
    onSurface: p.ink,
    surfaceContainerHighest: p.card2,
    error: p.accent2,
    onError: p.onAccent,
    errorContainer: p.accent2Bg,
    onErrorContainer: p.accent2Ink,
    outline: p.hairline,
    outlineVariant: p.hairline,
  );

  const family = 'Pretendard';
  const fallback = ['Apple SD Gothic Neo', 'Roboto'];

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: p.app,
    cardColor: p.card,
    dividerColor: p.hairline,
    splashFactory: InkSparkle.splashFactory,
    fontFamily: family,
    fontFamilyFallback: fallback,
    textTheme: _buildTextTheme(p.ink, p.inkSoft),
    appBarTheme: AppBarTheme(
      backgroundColor: p.app,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: p.ink,
      titleTextStyle: AppType.title.copyWith(color: p.ink, fontFamily: family),
    ),
    dividerTheme: DividerThemeData(
      color: p.hairline,
      thickness: Borders.divider,
      space: Borders.divider,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: AppType.body
          .copyWith(color: p.ink.withValues(alpha: Alpha.placeholder)),
      labelStyle: AppType.label
          .copyWith(fontSize: 12, color: p.ink.withValues(alpha: 0.6)),
      border: _inputBorder(p.hairline),
      enabledBorder: _inputBorder(p.hairline),
      focusedBorder: _inputBorder(p.accent, width: Borders.thick),
      errorBorder: _inputBorder(p.accent2),
      focusedErrorBorder: _inputBorder(p.accent2, width: Borders.thick),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: Gap.md),
    ),
    // 모든 버튼은 pill.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: AppType.button.copyWith(fontFamily: family),
      ).copyWith(overlayColor: _pressOverlay(p.accentPressed)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: p.card,
        foregroundColor: p.ink,
        side: BorderSide(color: p.hairline),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: AppType.button.copyWith(fontFamily: family),
      ).copyWith(overlayColor: _pressOverlay(p.accent)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        shape: const StadiumBorder(),
        textStyle: AppType.button.copyWith(fontFamily: family),
      ).copyWith(overlayColor: _pressOverlay(p.accent)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: AppType.button.copyWith(fontFamily: family),
      ).copyWith(overlayColor: _pressOverlay(p.accentPressed)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? p.accent : Colors.transparent),
      checkColor: WidgetStateProperty.all(p.onAccent),
      side: BorderSide(color: p.ink.withValues(alpha: Alpha.iconIdle)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.swatch + 2)),
    ),
    // 트랙 폭 ~40, 켜짐 accent / 꺼짐 divider.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? p.onAccent : p.card),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? p.accent : p.card2),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? p.accent : p.hairline),
      trackOutlineWidth: WidgetStateProperty.all(1),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.card,
      selectedColor: p.accentBg,
      side: BorderSide(color: p.hairline),
      shape: const StadiumBorder(),
      labelStyle: AppType.label.copyWith(color: p.ink, fontFamily: family),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.app,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: const Color(0xFF0F0F0E).withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      titleTextStyle: AppType.number.copyWith(color: p.ink, fontFamily: family),
      contentTextStyle: AppType.body
          .copyWith(color: p.ink.withValues(alpha: Alpha.bodySoft), fontFamily: family),
    ),
    // 토스트 — 잉크 반전 + shadow-md + radius 12.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle:
          AppType.body.copyWith(color: p.app, fontFamily: family),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.card2,
      circularTrackColor: p.card2,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.card2,
      thumbColor: p.accent,
      overlayColor: p.accent.withValues(alpha: 0.12),
    ),
    extensions: [SurlapColors(preset: p)],
  );
}

OutlineInputBorder _inputBorder(Color c, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: c, width: width),
    );

/// 눌림/호버 — 목업의 `background .14s ease` 대응. accent-700 을 낮은 알파로.
WidgetStateProperty<Color?> _pressOverlay(Color pressed) =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return pressed.withValues(alpha: 0.16);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return pressed.withValues(alpha: 0.08);
      }
      return null;
    });

TextTheme _buildTextTheme(Color ink, Color inkSoft) => TextTheme(
      headlineSmall: AppType.display.copyWith(color: ink),
      titleLarge: AppType.title.copyWith(color: ink),
      titleMedium: AppType.cardTitle.copyWith(color: ink),
      titleSmall: AppType.label.copyWith(color: inkSoft),
      bodyLarge: AppType.body.copyWith(color: ink),
      bodyMedium: AppType.sub.copyWith(color: ink),
      bodySmall: AppType.caption.copyWith(color: inkSoft),
      labelLarge: AppType.button.copyWith(color: ink),
      labelMedium: AppType.label.copyWith(color: ink),
      labelSmall: AppType.micro.copyWith(color: inkSoft),
    );

/// ThemeExtension 으로 색 토큰 전달 — `context.sh` 로 접근.
class SurlapColors extends ThemeExtension<SurlapColors> {
  final ColorPreset preset;
  const SurlapColors({required this.preset});

  /// 화면 배경.
  Color get bg => preset.app;

  /// 카드·시트·입력 필드.
  Color get card => preset.card;

  /// 함몰된 면·비활성 트랙·아바타 배경(surface).
  Color get card2 => preset.card2;

  /// 구분선·테두리.
  Color get border => preset.hairline;

  Color get ink => preset.ink;
  Color get inkSoft => preset.inkSoft;
  Color get inkFaint => preset.inkFaint;

  /// 기본 인터랙션.
  Color get accent => preset.accent;

  /// 연한 틴트 배경(accent-100).
  Color get accentBg => preset.accentBg;

  /// 틴트 배경 강(accent-200).
  Color get accentBg2 => preset.accentBg2;

  /// 틴트 위 텍스트·pressed(accent-700).
  Color get accentPressed => preset.accentPressed;

  /// 틴트 배경 위 진한 텍스트(accent-800).
  Color get accentInk => preset.accentInk;

  /// accent 채움 위 텍스트.
  Color get onAccent => preset.onAccent;

  /// 경고·생일·삭제(accent-2). 다른 강조에 쓰지 말 것.
  Color get accent2 => preset.accent2;
  Color get accent2Bg => preset.accent2Bg;
  Color get accent2Ink => preset.accent2Ink;

  /// "오늘" 신호 전용(애시드 라임). 오늘 칩·활성 탭 pill·현재 교시에만.
  Color get sig => preset.sig;
  Color get sigInk => preset.sigInk;

  Color get dot => preset.dot;
  bool get dark => preset.dark;

  /// 본문 보조(55–60%).
  Color get inkBody => ink.withValues(alpha: Alpha.bodySoft);

  /// 캡션·메타(45–50%).
  Color get inkCaption => ink.withValues(alpha: Alpha.caption);

  /// 주말 — 일요일·공휴일은 accent-2, 토요일은 accent.
  Color get sat => preset.accent;
  Color get sun => preset.accent2;

  /// 파괴적 액션.
  Color get danger => preset.accent2;

  /// NEIS 학사일정 — 액센트 틴트 계열로 통일(별도 청록 폐기).
  Color get academicColor => preset.accentPressed;

  /// 생일 — accent-2.
  Color get birthdayColor => preset.accent2;

  // ── Now / Today 시맨틱 ────────────────────────────────────────
  // 시그니처 라임(#D8FF3D)은 "지금 · 오늘"에만 쓴다. NOW 카드, 오늘 날짜,
  // 현재 시각 인디케이터, 진행 중인 교시, 완료 체크가 전부. 하단 내비 선택
  // 상태처럼 일반적인 활성 표시에 쓰면 "라임 = 지금"이라는 신호가 죽는다.
  // 선택·버튼 같은 상호작용은 accent(#1B4DFF), 경고·삭제는 danger(#D1330F).

  /// 지금 · 오늘.
  Color get now => preset.sig;

  /// [now] 위에 얹는 글자색.
  Color get onNow => preset.sigInk;

  /// [now] 의 옅은 배경(뱃지·칩).
  Color get nowBg => preset.sig.withValues(alpha: dark ? 0.22 : 0.30);

  /// 카드 그림자.
  List<BoxShadow> get shadowCard => Shadows.sm(dark);
  List<BoxShadow> get shadowLift => Shadows.md(dark);
  List<BoxShadow> get shadowFloat => Shadows.lg(dark);

  @override
  SurlapColors copyWith({ColorPreset? preset}) =>
      SurlapColors(preset: preset ?? this.preset);

  @override
  SurlapColors lerp(SurlapColors? other, double t) => this;
}

extension BuildContextThemeX on BuildContext {
  SurlapColors get sh => Theme.of(this).extension<SurlapColors>()!;
}
