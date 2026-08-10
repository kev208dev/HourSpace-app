/// 게스트 데이터 → 계정 데이터 이관(스펙 §26).
///
/// 로그인하면 저장 스코프가 `guest` 에서 `user_{uid}` 로 바뀐다. 게스트로 쓰던
/// 데이터는 지워지지 않지만 **보이지 않게** 된다 — 사용자 입장에서는 사라진
/// 것과 같다. 그래서 로그인 직후 "기존 데이터를 가져올까요?" 를 묻고,
/// 사용자가 선택했을 때만 옮긴다.
///
/// 이관은 **비파괴적**이다. 게스트 스코프 원본은 그대로 두므로, 잘못 눌러도
/// 로그아웃하면 원래 데이터가 그대로 있다.
library;

import 'dart:convert';

import '../core/constants/storage_keys.dart';
import '../models/event_item.dart';
import '../models/todo_item.dart';
import '../storage/local_store.dart';

/// 게스트 스코프에 남아 있는 데이터 요약.
class GuestDataSummary {
  final int events;
  final int todos;
  final int birthdays;

  /// 위 셋 외에 값이 들어 있는 계정 키 개수(테마·시간표·기록 등).
  final int otherKeys;

  const GuestDataSummary({
    this.events = 0,
    this.todos = 0,
    this.birthdays = 0,
    this.otherKeys = 0,
  });

  /// 사용자에게 보여줄 "N개" — 개수를 셀 수 있는 항목만.
  int get itemCount => events + todos + birthdays;

  bool get isEmpty => itemCount == 0 && otherKeys == 0;
}

abstract final class GuestMigration {
  GuestMigration._();

  static const _guestScope = 'guest';

  /// 이 계정에 대해 이미 물어봤는지 기록하는 키(계정 스코프 밖, 전역).
  static String _askedKey(String scope) => '__guest_import_asked::$scope';

  /// 게스트 스코프에 무엇이 남아 있는지 센다.
  static GuestDataSummary summarize() {
    final ls = LocalStore.instance;

    int countEvents() {
      final raw = ls.getRawScoped(_guestScope, StorageKeys.events);
      if (raw == null) return 0;
      var n = 0;
      for (final list in eventsFromJson(raw).values) {
        n += list.length;
      }
      return n;
    }

    int countTodos() {
      final raw = ls.getRawScoped(_guestScope, StorageKeys.todos);
      return raw == null ? 0 : todosFromJson(raw).length;
    }

    int countBirthdays() {
      final raw = ls.getRawScoped(_guestScope, StorageKeys.birthdays);
      if (raw == null) return 0;
      try {
        return (jsonDecode(raw) as List).length;
      } catch (_) {
        return 0;
      }
    }

    var other = 0;
    for (final key in StorageKeys.accountKeys) {
      if (key == StorageKeys.events ||
          key == StorageKeys.todos ||
          key == StorageKeys.birthdays) {
        continue;
      }
      final raw = ls.getRawScoped(_guestScope, key);
      if (raw != null && raw.isNotEmpty && raw != '[]' && raw != '{}') other++;
    }

    return GuestDataSummary(
      events: countEvents(),
      todos: countTodos(),
      birthdays: countBirthdays(),
      otherKeys: other,
    );
  }

  /// 지금 로그인한 계정에게 이관을 물어볼 상황인가.
  ///
  /// 물어보는 조건:
  ///  - 로그인 상태(스코프가 `user_` 로 시작)
  ///  - 이 계정에 대해 아직 물어본 적 없음
  ///  - 게스트 쪽에 옮길 데이터가 있음
  ///  - 계정 쪽이 비어 있음 — 이미 쓰던 계정이면 섞지 않는다
  static bool shouldAsk() {
    final ls = LocalStore.instance;
    final scope = ls.scope;
    if (!scope.startsWith('user_')) return false;
    if (ls.getBool(_askedKey(scope)) == true) return false;
    if (summarize().isEmpty) return false;
    return _scopeIsEmpty(scope);
  }

  static bool _scopeIsEmpty(String scope) {
    final ls = LocalStore.instance;
    for (final key in StorageKeys.accountKeys) {
      final raw = ls.getRawScoped(scope, key);
      if (raw != null && raw.isNotEmpty && raw != '[]' && raw != '{}') {
        return false;
      }
    }
    return true;
  }

  /// 다시 묻지 않도록 표시. "새로 시작"을 골라도 호출한다.
  static Future<void> markAsked() =>
      LocalStore.instance.setBool(_askedKey(LocalStore.instance.scope), true);

  /// 게스트 데이터를 현재 계정 스코프로 복사한다.
  ///
  /// 계정 쪽에 이미 값이 있는 키는 건드리지 않는다(덮어쓰지 않음).
  /// 게스트 원본은 남겨 둔다 — 로그아웃하면 그대로 다시 보인다.
  /// 복사한 키 개수를 돌려준다.
  static Future<int> importToCurrentAccount() async {
    final ls = LocalStore.instance;
    final scope = ls.scope;
    if (!scope.startsWith('user_')) return 0;

    var copied = 0;
    for (final key in StorageKeys.accountKeys) {
      final source = ls.getRawScoped(_guestScope, key);
      if (source == null || source.isEmpty) continue;
      final existing = ls.getRawScoped(scope, key);
      if (existing != null && existing.isNotEmpty) continue;
      // setString 을 쓰면 계정 데이터 변경 훅이 돌아 클라우드로도 올라간다.
      await ls.setString(key, source);
      copied++;
    }
    await markAsked();
    return copied;
  }
}
