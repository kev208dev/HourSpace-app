import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/calendar/calendar_item.dart';
import 'package:surlap/core/calendar/global_search.dart';
import 'package:surlap/core/constants/storage_keys.dart';
import 'package:surlap/storage/local_store.dart';

/// 전역 검색 계약 — 기존 검색은 로컬 일정과 할 일만 봤고 필터도 무시했다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dateKey = '2026-08-10';

  Future<ProviderContainer> boot({
    Map<String, List<Map<String, dynamic>>> events = const {},
    List<Map<String, dynamic>> todos = const [],
    List<Map<String, dynamic>> themes = const [],
    List<Map<String, dynamic>> birthdays = const [],
    List<String> hiddenCalendars = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'guest::${StorageKeys.events}': jsonEncode(events),
      'guest::${StorageKeys.todos}': jsonEncode(todos),
      'guest::${StorageKeys.themes}': jsonEncode(themes),
      'guest::${StorageKeys.birthdays}': jsonEncode(birthdays),
      'guest::${StorageKeys.themeFilter}': jsonEncode(hiddenCalendars),
    });
    await LocalStore.init();
    return ProviderContainer();
  }

  test('빈 질의는 결과가 없다', () async {
    final c = await boot(events: {
      dateKey: [
        {'t': '수학', 'tm': '11:00'},
      ],
    });
    addTearDown(c.dispose);
    expect(c.read(globalSearchProvider(const SearchQuery('  '))), isEmpty);
  });

  test('일정과 할 일을 함께 찾는다', () async {
    final c = await boot(
      events: {
        dateKey: [
          {'t': '중간고사 공부 시작', 'tm': '19:00'},
        ],
      },
      todos: [
        {'id': 't1', 't': '수학 중간고사 오답', 'p': 1},
      ],
    );
    addTearDown(c.dispose);

    final hits = c.read(globalSearchProvider(const SearchQuery('중간고사')));
    expect(hits.length, 2);
    // 그룹 순서: 학교 → 일정 → 할 일
    expect(hits.first.group, SearchGroup.event);
    expect(hits.last.group, SearchGroup.todo);
    expect(hits.last.priority, 1);
  });

  test('대소문자를 가리지 않는다', () async {
    final c = await boot(events: {
      dateKey: [
        {'t': 'English Class', 'tm': '09:00'},
      ],
    });
    addTearDown(c.dispose);
    expect(c.read(globalSearchProvider(const SearchQuery('english'))).length, 1);
  });

  test('생일도 검색된다 — 예전에는 아예 잡히지 않았다', () async {
    final c = await boot(
      events: {
        dateKey: [
          {'t': '아무거나', 'tm': '09:00'},
        ],
      },
      birthdays: [
        {'id': 'b1', 'name': '민수', 'month': 8, 'day': 10},
      ],
    );
    addTearDown(c.dispose);

    final hits = c.read(globalSearchProvider(const SearchQuery('민수')));
    expect(hits.single.source, CalendarSource.birthday);
    expect(hits.single.dateKey, dateKey);
  });

  test('숨긴 캘린더는 기본적으로 결과에서 빠지고, 옵션으로 포함할 수 있다', () async {
    final c = await boot(
      events: {
        dateKey: [
          {'t': '공부 계획', 'tm': '09:00', 'th': 'study'},
        ],
      },
      themes: [
        {'id': 'study', 'name': '공부', 'color': '#3366ff'},
      ],
      hiddenCalendars: ['study'],
    );
    addTearDown(c.dispose);

    expect(c.read(globalSearchProvider(const SearchQuery('공부'))), isEmpty);
    expect(
      c
          .read(globalSearchProvider(
              const SearchQuery('공부', includeHidden: true)))
          .length,
      1,
    );
  });

  test('날짜 없는 할 일은 그룹 안에서 뒤로 간다', () async {
    final c = await boot(todos: [
      {'id': 't1', 't': '과제 제출'},
      {'id': 't2', 't': '과제 초안', 'd': dateKey},
    ]);
    addTearDown(c.dispose);

    final hits = c.read(globalSearchProvider(const SearchQuery('과제')));
    expect(hits.map((h) => h.title), ['과제 초안', '과제 제출']);
    expect(hits.last.dateKey, isEmpty);
  });

  test('SearchQuery 는 값 동등성을 가진다 — family 캐시가 매번 재계산되지 않도록', () {
    expect(const SearchQuery('a'), const SearchQuery('a'));
    expect(const SearchQuery('a').hashCode, const SearchQuery('a').hashCode);
    expect(const SearchQuery('a') == const SearchQuery('a', includeHidden: true),
        isFalse);
  });
}
