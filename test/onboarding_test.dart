import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/constants/color_presets.dart';
import 'package:surlap/core/theme/app_theme.dart';
import 'package:surlap/i18n/app_lang.dart';
import 'package:surlap/providers/locale_provider.dart';
import 'package:surlap/screens/onboarding/onboarding_screen.dart';
import 'package:surlap/storage/local_store.dart';

/// 첫 실행 UX — 두 걸음이면 Today 에 닿아야 한다(스펙 §28).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
  }

  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(theme: buildTheme(kDefaultPreset), home: child),
      );

  testWidgets('소개 → 학교 연결 두 걸음', (tester) async {
    await boot();
    var done = false;
    await tester
        .pumpWidget(wrap(OnboardingScreen(onDone: () => done = true)));
    await tester.pump();

    // 1걸음: 소개
    expect(find.text('학교와 일상을\n한 곳에서.'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    // 2걸음: 학교 연결 — 여기서 끝. 세 번째 화면은 없다.
    expect(find.text('학교에 다니고 있나요?'), findsOneWidget);
    expect(find.text('학교 검색'), findsOneWidget);
    expect(find.text('나중에 할게요'), findsOneWidget);

    // "나중에 할게요" → 바로 Today 로
    expect(done, isFalse);
    await tester.tap(find.text('나중에 할게요'));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('언어를 고르는 화면이 없다', (tester) async {
    await boot();
    await tester.pumpWidget(wrap(OnboardingScreen(onDone: () {})));
    await tester.pumpAndSettle();

    // 예전 흐름의 언어 선택 화면 문구가 어디에도 없어야 한다.
    for (final lang in AppLang.values) {
      expect(find.text(lang.nativeName), findsNothing);
    }
  });

  test('저장된 언어가 없으면 기기 로케일을 따른다', () async {
    await boot();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // 테스트 환경 로케일이 무엇이든, 지원 목록 안의 값으로 정해진다.
    expect(AppLang.values, contains(c.read(localeProvider)));
    expect(c.read(localeProvider), LocaleNotifier.deviceLang());
  });

  test('사용자가 고른 언어는 기기 로케일보다 우선한다', () async {
    SharedPreferences.setMockInitialValues({'calendar-app-lang-v1': 'ja'});
    await LocalStore.init();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(localeProvider), AppLang.ja);
  });
}
