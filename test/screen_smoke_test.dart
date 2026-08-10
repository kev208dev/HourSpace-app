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

  testWidgets('오늘 화면: 일정이 없으면 "예정된 일정이 없어요"', (tester) async {
    await boot();
    await tester.pumpWidget(wrap(const TodayScreen()));
    await tester.pump();

    expect(find.text('지금'), findsOneWidget);
    expect(find.text('예정된 일정이 없어요'), findsOneWidget);
    // 학교 미연결 안내
    expect(find.text('학교 연결'), findsOneWidget);
  });

  testWidgets('오늘 화면: 오늘 할 일이 목록에 뜬다', (tester) async {
    await boot(todos: [
      {'id': 't1', 't': '영어 단어 50개', 'p': 1, 'd': du.todayKey()},
    ]);
    await tester.pumpWidget(wrap(const TodayScreen()));
    await tester.pump();

    expect(find.text('영어 단어 50개'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('오늘 화면: 진행 중인 일정이 히어로로 올라간다', (tester) async {
    final now = DateTime.now();
    final start =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final endAt = now.add(const Duration(minutes: 40));
    final end =
        '${endAt.hour.toString().padLeft(2, '0')}:${endAt.minute.toString().padLeft(2, '0')}';

    // 자정 근처면 종료가 다음 날로 넘어가 테스트가 흔들리므로 건너뛴다.
    if (endAt.day != now.day) return;

    await boot(events: {
      du.todayKey(): [
        {'t': '수학', 'tm': start, 'te': end},
      ],
    });
    await tester.pumpWidget(wrap(const TodayScreen()));
    await tester.pump();

    expect(find.text('수학'), findsOneWidget);
    expect(find.text('지금'), findsOneWidget);
    expect(find.textContaining('남음'), findsOneWidget);
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
