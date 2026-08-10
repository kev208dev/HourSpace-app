import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/constants/storage_keys.dart';
import 'package:surlap/models/calendar_theme.dart';
import 'package:surlap/providers/holidays_provider.dart';
import 'package:surlap/providers/themes_provider.dart';
import 'package:surlap/storage/local_store.dart';

/// 시스템 캘린더(공휴일)와 사용자 캘린더의 분리(스펙 §10).
///
/// 공휴일은 켜고 끌 수 있는 캘린더 소스이지 사용자가 이름·색을 고치거나
/// 지울 수 있는 항목이 아니다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> boot(List<Map<String, dynamic>> themes) async {
    SharedPreferences.setMockInitialValues({
      'guest::${StorageKeys.themes}': jsonEncode(themes),
    });
    await LocalStore.init();
    LocalStore.instance.setScope('guest');
    return ProviderContainer();
  }

  test('공휴일은 시스템 캘린더로 분류된다', () {
    expect(isSystemCalendarTheme(holidayThemeId), isTrue);
    expect(isSystemCalendarTheme('study'), isFalse);
  });

  test('저장된 목록에 공휴일이 없어도 항상 채워 넣는다', () async {
    final c = await boot([
      {'id': 'study', 'name': '공부', 'color': '#3366ff'},
    ]);
    addTearDown(c.dispose);

    final all = c.read(themesProvider);
    expect(all.map((t) => t.id), contains(holidayThemeId));
  });

  test('userThemesProvider 는 시스템 캘린더를 뺀다', () async {
    final c = await boot([
      {'id': 'study', 'name': '공부', 'color': '#3366ff'},
    ]);
    addTearDown(c.dispose);

    final user = c.read(userThemesProvider);
    expect(user.map((t) => t.id), ['study']);
    expect(user.map((t) => t.id), isNot(contains(holidayThemeId)));
  });

  test('시스템 캘린더는 삭제되지 않는다', () async {
    final c = await boot([
      {'id': 'study', 'name': '공부', 'color': '#3366ff'},
    ]);
    addTearDown(c.dispose);

    await c.read(themesProvider.notifier).delete(holidayThemeId);
    expect(c.read(themesProvider).map((t) => t.id), contains(holidayThemeId));
  });

  test('시스템 캘린더는 이름·색이 바뀌지 않는다', () async {
    final c = await boot(const []);
    addTearDown(c.dispose);

    await c.read(themesProvider.notifier).update(
          const CalendarTheme(id: holidayThemeId, name: '내맘대로', color: '#000000'),
        );
    final holiday =
        c.read(themesProvider).firstWhere((t) => t.id == holidayThemeId);
    expect(holiday.name, holidayCalendarTheme.name);
    expect(holiday.color, holidayCalendarTheme.color);
  });

  test('사용자 캘린더는 정상적으로 추가·삭제된다', () async {
    final c = await boot(const []);
    addTearDown(c.dispose);

    final notifier = c.read(themesProvider.notifier);
    await notifier
        .add(const CalendarTheme(id: 'club', name: '동아리', color: '#22aa88'));
    expect(c.read(userThemesProvider).map((t) => t.id), contains('club'));

    await notifier.delete('club');
    expect(c.read(userThemesProvider).map((t) => t.id), isNot(contains('club')));
  });
}
