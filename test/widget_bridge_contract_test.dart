import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/calendar/calendar_repository.dart';
import 'package:surlap/core/constants/storage_keys.dart';
import 'package:surlap/core/utils/date_utils.dart' as du;
import 'package:surlap/storage/local_store.dart';

/// 홈 위젯 데이터 계약(`surlap.widget.v2`).
///
/// 네이티브(SurlapWidgetProvider.kt / SurlapWidget.swift)가 읽는 키가 빠지면
/// 위젯이 조용히 빈 화면이 된다. Dart 쪽에서만 고쳐도 알아채지 못하므로
/// 계약을 테스트로 고정한다.
///
/// `WidgetBridge._build` 는 private 이라 직접 부르지 않고, 그 입력이 되는
/// 통합 계층이 위젯이 필요로 하는 값을 실제로 만들어 내는지 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 네이티브가 읽는 평탄화 키 — 참조용 목록(회귀 시 눈에 띄게).
  const nativeFlatKeys = {
    'today',
    'schoolClass',
    'periods',
    'currentIndex',
    'progress',
    'minutesRemaining',
    'nowName',
    'nowStart',
    'nowEnd',
    'nextName',
    'nextStart',
    'widgetSchemaVersion',
    'theme',
    'accent',
    'ddayTitle',
    'ddayLabel',
    'mediumEvents',
    'nextClass',
  };

  Future<ProviderContainer> boot({
    Map<String, List<Map<String, dynamic>>> events = const {},
    List<Map<String, dynamic>> todos = const [],
    List<String> hidden = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'guest::${StorageKeys.events}': jsonEncode(events),
      'guest::${StorageKeys.todos}': jsonEncode(todos),
      'guest::${StorageKeys.themeFilter}': jsonEncode(hidden),
    });
    await LocalStore.init();
    LocalStore.instance.setScope('guest');
    return ProviderContainer();
  }

  test('네이티브가 읽는 평탄화 키 목록이 18개로 유지된다', () {
    // 이 숫자가 바뀌면 네이티브 쪽도 함께 봐야 한다는 신호다.
    expect(nativeFlatKeys.length, 18);
  });

  test('위젯이 그리는 오늘 항목은 통합 계층에서 나온다', () async {
    final today = du.todayKey();
    final c = await boot(events: {
      today: [
        {'t': '수학', 'tm': '11:00', 'te': '11:50'},
        {'t': '준비물'},
      ],
    });
    addTearDown(c.dispose);

    final items = c.read(calendarDayProvider(today));
    expect(items.map((i) => i.title), containsAll(['수학', '준비물']));
    // 종일이 먼저 — 위젯의 allDay/timed 분리가 이 정렬에 기댄다.
    expect(items.first.allDay, isTrue);
  });

  test('숨긴 캘린더는 위젯에도 나오지 않는다 — 앱과 같은 결과', () async {
    final today = du.todayKey();
    final c = await boot(
      events: {
        today: [
          {'t': '공부', 'tm': '09:00', 'th': 'study'},
          {'t': '학원', 'tm': '17:00'},
        ],
      },
      hidden: ['study'],
    );
    addTearDown(c.dispose);

    final titles = c.read(calendarDayProvider(today)).map((i) => i.title);
    expect(titles, contains('학원'));
    expect(titles, isNot(contains('공부')));
  });

  test('시각이 있는 항목은 HH:MM 문자열로 나온다 — 위젯이 문자열 비교로 정렬한다', () async {
    final today = du.todayKey();
    final c = await boot(events: {
      today: [
        {'t': '아침', 'tm': '09:00', 'te': '09:50'},
      ],
    });
    addTearDown(c.dispose);

    final item =
        c.read(calendarDayProvider(today)).firstWhere((i) => !i.allDay);
    expect(item.startHhmm, matches(RegExp(r'^\d{2}:\d{2}$')));
    expect(item.endHhmm, matches(RegExp(r'^\d{2}:\d{2}$')));
  });
}
