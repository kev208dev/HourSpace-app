import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/constants/storage_keys.dart';
import 'package:surlap/storage/local_store.dart';
import 'package:surlap/supabase/guest_migration.dart';

/// 게스트 → 계정 이관(스펙 §26).
///
/// 로그인하면 스코프가 바뀌어 게스트 데이터가 화면에서 사라진다. 지워지지는
/// 않지만 사용자 입장에서는 날아간 것과 같다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'user_abc';

  Future<void> boot(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    await LocalStore.init();
    // LocalStore 는 프로세스 단일 인스턴스라 스코프가 테스트 간에 남는다.
    // 앱은 시작할 때 guest 로 출발하므로 여기서도 맞춰 준다.
    LocalStore.instance.setScope('guest');
  }

  Map<String, Object> guestData() => {
        'guest::${StorageKeys.events}': jsonEncode({
          '2026-08-10': [
            {'t': '수학', 'tm': '11:00'},
            {'t': '영어', 'tm': '14:00'},
          ],
        }),
        'guest::${StorageKeys.todos}': jsonEncode([
          {'id': 't1', 't': '오답 정리'},
        ]),
        'guest::${StorageKeys.birthdays}': jsonEncode([
          {'id': 'b1', 'name': '민수', 'month': 8, 'day': 10},
        ]),
        'guest::${StorageKeys.themes}': jsonEncode([
          {'id': 'study', 'name': '공부', 'color': '#3366ff'},
        ]),
      };

  test('게스트 데이터를 종류별로 센다', () async {
    await boot(guestData());
    final s = GuestMigration.summarize();
    expect(s.events, 2);
    expect(s.todos, 1);
    expect(s.birthdays, 1);
    expect(s.otherKeys, 1); // themes
    expect(s.itemCount, 4);
    expect(s.isEmpty, isFalse);
  });

  test('게스트가 비어 있으면 묻지 않는다', () async {
    await boot({});
    LocalStore.instance.setScope(uid);
    expect(GuestMigration.summarize().isEmpty, isTrue);
    expect(GuestMigration.shouldAsk(), isFalse);
  });

  test('게스트 상태에서는 묻지 않는다', () async {
    await boot(guestData());
    expect(LocalStore.instance.scope, 'guest');
    expect(GuestMigration.shouldAsk(), isFalse);
  });

  test('빈 계정으로 로그인하면 묻는다', () async {
    await boot(guestData());
    LocalStore.instance.setScope(uid);
    expect(GuestMigration.shouldAsk(), isTrue);
  });

  test('이미 쓰던 계정이면 묻지 않는다 — 남의 데이터와 섞지 않는다', () async {
    await boot({
      ...guestData(),
      '$uid::${StorageKeys.events}': jsonEncode({
        '2026-01-01': [
          {'t': '계정 쪽 일정'},
        ],
      }),
    });
    LocalStore.instance.setScope(uid);
    expect(GuestMigration.shouldAsk(), isFalse);
  });

  test('한 번 물어본 계정에는 다시 묻지 않는다', () async {
    await boot(guestData());
    LocalStore.instance.setScope(uid);
    expect(GuestMigration.shouldAsk(), isTrue);
    await GuestMigration.markAsked();
    expect(GuestMigration.shouldAsk(), isFalse);
  });

  test('가져오면 계정 스코프에서 데이터가 보인다', () async {
    await boot(guestData());
    LocalStore.instance.setScope(uid);

    final copied = await GuestMigration.importToCurrentAccount();
    expect(copied, 4); // events, todos, birthdays, themes

    final ls = LocalStore.instance;
    expect(ls.getString(StorageKeys.events), contains('수학'));
    expect(ls.getString(StorageKeys.todos), contains('오답 정리'));
    expect(ls.getString(StorageKeys.birthdays), contains('민수'));
    expect(ls.getString(StorageKeys.themes), contains('공부'));
  });

  test('가져와도 게스트 원본은 남는다 — 로그아웃하면 그대로', () async {
    await boot(guestData());
    LocalStore.instance.setScope(uid);
    await GuestMigration.importToCurrentAccount();

    LocalStore.instance.setScope('guest');
    expect(LocalStore.instance.getString(StorageKeys.events), contains('수학'));
    expect(
        LocalStore.instance.getString(StorageKeys.todos), contains('오답 정리'));
  });

  test('계정 쪽에 이미 있는 키는 덮어쓰지 않는다', () async {
    await boot({
      ...guestData(),
      '$uid::${StorageKeys.todos}': jsonEncode([
        {'id': 'x', 't': '계정 쪽 할 일'},
      ]),
    });
    LocalStore.instance.setScope(uid);

    await GuestMigration.importToCurrentAccount();
    final todos = LocalStore.instance.getString(StorageKeys.todos)!;
    expect(todos, contains('계정 쪽 할 일'));
    expect(todos, isNot(contains('오답 정리')));
  });

  test('가져오기가 끝나면 다시 묻지 않는다', () async {
    await boot(guestData());
    LocalStore.instance.setScope(uid);
    await GuestMigration.importToCurrentAccount();
    expect(GuestMigration.shouldAsk(), isFalse);
  });

  test('로그인하지 않은 상태에서 가져오기를 부르면 아무 일도 없다', () async {
    await boot(guestData());
    expect(await GuestMigration.importToCurrentAccount(), 0);
  });
}
