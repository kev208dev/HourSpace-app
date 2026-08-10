import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/constants/color_presets.dart';
import 'package:surlap/core/constants/storage_keys.dart';
import 'package:surlap/core/theme/app_theme.dart';
import 'package:surlap/core/utils/date_utils.dart' as du;
import 'package:surlap/screens/school/school_screen.dart';
import 'package:surlap/screens/today/today_screen.dart';
import 'package:surlap/screens/todo/todo_screen.dart';
import 'package:surlap/storage/local_store.dart';

/// 새 탭 화면들이 실제로 그려지는지 확인한다.
///
/// 데이터 계층 테스트만으로는 "화면이 크래시 없이 뜬다"를 잡지 못한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot({
    Map<String, List<Map<String, dynamic>>> events = const {},
    List<Map<String, dynamic>> todos = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'guest::${StorageKeys.events}': jsonEncode(events),
      'guest::${StorageKeys.todos}': jsonEncode(todos),
    });
    await LocalStore.init();
  }

  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: buildTheme(kDefaultPreset),
          home: Scaffold(body: child),
        ),
      );

  testWidgets('홈: 섹션이 핸드오프 순서대로 그려진다', (tester) async {
    await boot();
    await tester.pumpWidget(wrap(const TodayScreen()));
    await tester.pump();

    // B1 의 섹션 구성 — 다가오는 일정 → 할 일 → 오늘 급식 → 다가오는 생일
    expect(find.text('다가오는 일정'), findsOneWidget);
    expect(find.text('할 일'), findsOneWidget);
    expect(find.text('오늘 급식'), findsOneWidget);
    expect(find.text('다가오는 생일'), findsOneWidget);
    // 오늘 내 일정 수 · 가장 가까운 학사일정
    expect(find.text('오늘 내 일정'), findsOneWidget);
    expect(find.text('가장 가까운 학사일정'), findsOneWidget);
  });

  testWidgets('홈: 일정이 없으면 빈 문구가 뜬다', (tester) async {
    await boot();
    await tester.pumpWidget(wrap(const TodayScreen()));
    await tester.pump();
    expect(find.text('오늘 남은 시간 일정이 없습니다.'), findsOneWidget);
  });

  testWidgets('홈: 학교 미설정이면 급식 안내 문구', (tester) async {
    await boot();
    await tester.pumpWidget(wrap(const TodayScreen()));
    await tester.pump();
    expect(
        find.text('학교가 설정되지 않았습니다. 초·중·고 사용자만 급식 정보를 볼 수 있습니다.'),
        findsOneWidget);
  });

  testWidgets('홈: 오늘 할 일과 우선순위가 보인다', (tester) async {
    await boot(todos: [
      {'id': 't1', 't': '영어 단어 50개', 'p': 1, 'd': du.todayKey()},
    ]);
    await tester.pumpWidget(wrap(const TodayScreen()));
    await tester.pump();

    expect(find.text('영어 단어 50개'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
  });

  testWidgets('할 일 화면: 자연어 한 줄로 추가된다', (tester) async {
    await boot();
    await tester.pumpWidget(wrap(const TodoScreen()));
    await tester.pump();

    expect(find.text('오늘 할 일이 없어요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '수학 문제집 30쪽');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(find.text('수학 문제집 30쪽'), findsOneWidget);
  });

  testWidgets('할 일 화면: 완료 토글은 두 단계만 오간다', (tester) async {
    await boot(todos: [
      {'id': 't1', 't': '오답 정리', 'd': du.todayKey()},
    ]);
    await tester.pumpWidget(wrap(const TodoScreen()));
    await tester.pump();

    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // 예전에는 여기서 "진행중"(timelapse)을 거쳤다.
    await tester.tap(find.byIcon(Icons.check_circle_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timelapse_rounded), findsNothing);
  });

  testWidgets('학교 화면: 미연결이면 연결 안내만 보인다', (tester) async {
    await boot();
    await tester.pumpWidget(wrap(const SchoolScreen()));
    await tester.pump();

    expect(find.text('학교 연결'), findsOneWidget);
    expect(find.textContaining('시간표·급식·학사일정'), findsOneWidget);
  });
}
