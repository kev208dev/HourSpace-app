import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/calendar/calendar_repository.dart';
import 'package:surlap/core/constants/storage_keys.dart';
import 'package:surlap/core/utils/date_utils.dart' as du;
import 'package:surlap/providers/filter_provider.dart';
import 'package:surlap/storage/local_store.dart';

/// 카테고리 숨김은 **모든 화면에서 같게** 동작한다(핸드오프 C6 의 한계 항목 해소).
///
/// 목업 시점에는 숨김이 월 보기에만 적용되고 3일 플래너·하루 보기·위젯에는
/// 일관되게 적용되지 않았다. 통합 계층을 거치면서 한 번만 걸러지므로 이제
/// 어느 화면에서 보든 결과가 같다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dateKey = '2026-08-10';

  Future<ProviderContainer> boot({List<String> hidden = const []}) async {
    SharedPreferences.setMockInitialValues({
      'guest::${StorageKeys.events}': jsonEncode({
        dateKey: [
          {'t': '공부', 'tm': '09:00', 'th': 'study'},
          {'t': '학원', 'tm': '17:00', 'th': 'academy'},
          {'t': '분류 없는 일정', 'tm': '20:00'},
        ],
      }),
      'guest::${StorageKeys.themes}': jsonEncode([
        {'id': 'study', 'name': '공부', 'color': '#1B4DFF'},
        {'id': 'academy', 'name': '학원', 'color': '#D1330F'},
      ]),
      'guest::${StorageKeys.themeFilter}': jsonEncode(hidden),
    });
    await LocalStore.init();
    LocalStore.instance.setScope('guest');
    return ProviderContainer();
  }

  test('숨긴 카테고리는 월 조회와 하루 조회 양쪽에서 동일하게 빠진다', () async {
    final c = await boot(hidden: ['study']);
    addTearDown(c.dispose);

    final month = c.read(calendarItemsByDateProvider)[dateKey]!;
    final day = c.read(calendarDayProvider(dateKey));

    expect(month.map((i) => i.title), isNot(contains('공부')));
    expect(day.map((i) => i.title), isNot(contains('공부')));
    // 나머지는 그대로
    expect(day.map((i) => i.title), contains('학원'));
  });

  test('여러 카테고리를 숨기면 각각 사라진다', () async {
    final c = await boot(hidden: ['study', 'academy']);
    addTearDown(c.dispose);

    final titles =
        c.read(calendarDayProvider(dateKey)).map((i) => i.title).toList();
    expect(titles, isNot(contains('공부')));
    expect(titles, isNot(contains('학원')));
    expect(titles, contains('분류 없는 일정'));
  });

  test('토글하면 즉시 되돌아온다', () async {
    final c = await boot(hidden: ['study']);
    addTearDown(c.dispose);

    expect(c.read(calendarDayProvider(dateKey)).map((i) => i.title),
        isNot(contains('공부')));
    await c.read(filterProvider.notifier).toggle('study');
    expect(c.read(calendarDayProvider(dateKey)).map((i) => i.title),
        contains('공부'));
  });

  test('숨김 목록은 저장된다', () async {
    final c = await boot();
    addTearDown(c.dispose);

    await c.read(filterProvider.notifier).toggle('academy');
    final saved = LocalStore.instance.getString(StorageKeys.themeFilter);
    expect(saved, contains('academy'));
  });

  test('시간표 카테고리 id 는 별도로 존재한다 — 학사일정과 따로 끈다', () {
    expect(timetableCalendarId, isNot('__academic__'));
    expect(timetableCalendarId, '__timetable__');
  });

  test('검색이 보는 날짜 키와 캘린더가 보는 날짜 키가 같다', () async {
    final c = await boot();
    addTearDown(c.dispose);
    final items = c.read(calendarDayProvider(dateKey));
    expect(items.every((i) => i.dateKey == dateKey), isTrue);
    expect(du.fromDateKey(dateKey).day, 10);
  });
}
