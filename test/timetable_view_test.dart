import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:surlap/core/constants/color_presets.dart';
import 'package:surlap/core/theme/app_theme.dart';
import 'package:surlap/screens/timetable_view/timetable_view.dart';
import 'package:surlap/storage/local_store.dart';

/// 시간표는 06:00~24:00 세로 아젠다다(교시 격자에서 바뀜).
///
/// 원래 이 테스트가 지키려던 것은 "데이터가 없어도 틀이 그려지고, 세로 스크롤
/// 안 Row 의 stretch 가 무한 높이로 터지지 않는다"였다. 그 계약은 그대로 두고,
/// 격자 전용 라벨('1교시' 등) 대신 아젠다의 실제 구성 요소로 확인한다.
void main() {
  testWidgets('데이터가 비어도 타임라인이 무한높이 크래시 없이 그려진다', (tester) async {
    SharedPreferences.setMockInitialValues({}); // 빈 저장소 = 데이터 없음
    await LocalStore.init();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(kDefaultPreset),
          home: const Scaffold(
            // 앱과 동일하게 Expanded 안에 배치(상단 바운드 높이 제공)
            body: SafeArea(
              child: Column(
                children: [Expanded(child: TimetableView())],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 1) 렌더 도중 예외(무한 높이 등)가 없어야 한다.
    expect(tester.takeException(), isNull);

    // 2) 화면 제목 + 선택된 날짜가 그려진다.
    expect(find.text('스케줄표'), findsOneWidget);

    // 3) 06:00~24:00 시각 눈금이 전부 그려진다.
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('24:00'), findsOneWidget);

    // 4) 데이터가 없으면 빈 상태 안내가 뜬다.
    expect(find.text('이 날은 등록된 일정이 없어요'), findsOneWidget);

    // 5) 스크롤해도 터지지 않는다.
    await tester.drag(find.byType(TimetableView), const Offset(0, -300));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
