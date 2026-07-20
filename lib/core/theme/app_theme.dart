import 'package:flutter/material.dart';
import '../constants/color_presets.dart';
import 'design_tokens.dart';

/// ColorPreset → Flutter ThemeData 변환.
/// 웹 CSS 변수 대응:
///   --bg              → scaffold bg
///   --cell-bg         → card / surface
///   --today-accent    → primary
///   --text            → onSurface
///   --border          → divider / outline
ThemeData buildTheme(ColorPreset p) {
  final cs = ColorScheme(
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.accent,
    onPrimary: p.dark ? p.ink : Colors.white,
    primaryContainer: p.accentBg,
    onPrimaryContainer: p.accentInk,
    secondary: p.accent,
    onSecondary: Colors.white,
    secondaryContainer: p.accentBg,
    onSecondaryContainer: p.accentInk,
    surface: p.card,
    onSurface: p.ink,
    surfaceContainerHighest: p.card2,
    error: const Color(0xFFD9614E),
    onError: Colors.white,
    outline: p.hairline,
    outlineVariant: p.hairline,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: p.app,
    cardColor: p.card,
    dividerColor: p.hairline,
    fontFamily: 'Pretendard',
    fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
    textTheme: _buildTextTheme(p.ink, p.inkSoft),
    appBarTheme: AppBarTheme(
      backgroundColor: p.app,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: p.ink,
      titleTextStyle: TextStyle(
        color: p.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Pretendard Variable',
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.dark ? p.ink : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Pretendard'),
      ).copyWith(overlayColor: _accentOverlay(p.accent)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Pretendard'),
      ).copyWith(overlayColor: _accentOverlay(p.accent)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.dark ? p.ink : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Pretendard'),
      ).copyWith(overlayColor: _accentOverlay(p.accent)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? p.accent : Colors.transparent),
      checkColor: WidgetStateProperty.all(
          p.dark ? p.ink : Colors.white),
      side: BorderSide(color: p.inkSoft),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? p.accent : p.inkFaint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? p.accentBg
              : p.hairline),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(
        color: p.ink, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Pretendard'),
    ),
    extensions: [SurlapColors(preset: p)],
  );
}

/// 버튼 눌림/호버 시 회색 기본 리플 대신 브랜드 액센트 컬러를 낮은 알파로.
WidgetStateProperty<Color?> _accentOverlay(Color accent) =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return accent.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return accent.withValues(alpha: 0.08);
      }
      return null;
    });

TextTheme _buildTextTheme(Color ink, Color inkSoft) => TextTheme(
  headlineLarge: AppType.headlineLarge.copyWith(color: ink, fontFamily: 'Pretendard'),
  titleLarge: AppType.titleLarge.copyWith(color: ink, fontFamily: 'Pretendard'),
  titleMedium: AppType.titleMedium.copyWith(color: ink, fontFamily: 'Pretendard'),
  bodyLarge: AppType.bodyLarge.copyWith(color: ink, fontFamily: 'Pretendard'),
  bodyMedium: AppType.bodyMedium.copyWith(color: ink, fontFamily: 'Pretendard'),
  bodySmall: AppType.bodySmall.copyWith(color: inkSoft, fontFamily: 'Pretendard'),
  labelMedium: AppType.labelMedium.copyWith(color: ink, fontFamily: 'Pretendard'),
);

/// ThemeExtension으로 색상 토큰 전달 — Theme.of(context).extension 으로 접근.
class SurlapColors extends ThemeExtension<SurlapColors> {
  final ColorPreset preset;
  const SurlapColors({required this.preset});

  Color get bg       => preset.app;
  // 그라데이션 배경 — 최상위 Container 에서 BoxDecoration.gradient 로 깔기.
  Color get bgTop    => preset.dark ? kAppBgTopDark : kAppBgTopLight;
  Color get bgBottom => preset.dark ? kAppBgBottomDark : kAppBgBottomLight;
  // 히어로 카드/액티브용 액센트 그라데이션 (135°).
  List<Color> get accentGrad =>
      preset.dark ? kAccentGradDark : kAccentGradLight;
  // 알약/필터 활성 배경(라이트 .10 / 다크 .22).
  Color get accentLight => preset.dark
      ? const Color(0xFFA99FF8)
      : preset.accent;
  Color get card     => preset.card;
  Color get card2    => preset.card2;
  Color get border   => preset.hairline;
  Color get ink      => preset.ink;
  Color get inkSoft  => preset.inkSoft;
  Color get inkFaint => preset.inkFaint;
  Color get accent   => preset.accent;
  Color get accentBg => preset.accentBg;
  Color get accentInk => preset.accentInk;
  Color get dot      => preset.dot;
  bool  get dark     => preset.dark;
  // 주말 색 — 너무 튀지 않는 soft red / soft blue
  Color get sat      => preset.dark ? const Color(0xFF8AAAC8) : const Color(0xFF5C7CFA);
  Color get sun      => preset.dark ? const Color(0xFFD98A8A) : const Color(0xFFE86A6A);
  // 파괴적 액션용 (삭제 등)
  Color get danger   => const Color(0xFFD9614E);
  // NEIS 학사일정 — 기존 일정과 구분되는 청록 톤.
  Color get academicColor => const Color(0xFF0FB5AE);
  // 생일 — 분홍 톤.
  Color get birthdayColor => const Color(0xFFEC4899);

  @override
  SurlapColors copyWith({ColorPreset? preset}) =>
      SurlapColors(preset: preset ?? this.preset);

  @override
  SurlapColors lerp(SurlapColors? other, double t) => this;
}

extension BuildContextThemeX on BuildContext {
  SurlapColors get sh =>
      Theme.of(this).extension<SurlapColors>()!;
}
