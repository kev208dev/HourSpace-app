import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/storage_keys.dart';

/// SharedPreferences 래퍼 — 웹 localStorage와 동일한 get/set 인터페이스.
///
/// 계정 분리: [StorageKeys.accountKeys] 에 속한 키는 현재 스코프
/// (`guest` 또는 `user_{uid}`) 프리픽스를 붙여 물리적으로 분리 저장한다.
/// 그 외(기기 설정성) 키는 프리픽스 없이 공용.
///
/// 타입 관대 읽기: 클라우드/백업에서 받은 값은 웹 형식이라 bool/int도 문자열로
/// 저장될 수 있어, 타입 게터는 실제 저장 타입과 무관하게 변환한다.
class LocalStore {
  LocalStore._();
  static LocalStore? _instance;
  static LocalStore get instance => _instance!;

  late SharedPreferences _prefs;

  String _scope = 'guest';
  String get scope => _scope;
  void setScope(String scope) => _scope = scope;

  /// 계정 키가 일반 setString으로 바뀌면 호출(디바운스 push 트리거용).
  /// 동기화 pull은 setStringQuiet를 써서 이 훅을 우회한다.
  void Function(String key)? onAccountKeyChanged;

  static Future<LocalStore> init() async {
    _instance ??= LocalStore._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  String _phys(String key) =>
      StorageKeys.accountKeys.contains(key) ? '$_scope::$key' : key;

  // ── 읽기 (타입 관대) ──────────────────────────────────────
  String? getString(String key) => _prefs.get(_phys(key))?.toString();

  bool? getBool(String key) {
    final v = _prefs.get(_phys(key));
    if (v == null) return null;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0' || s.isEmpty) return false;
    }
    return null;
  }

  int? getInt(String key) {
    final v = _prefs.get(_phys(key));
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  /// 특정 스코프의 값을 직접 읽는다(현재 스코프와 무관).
  ///
  /// 게스트 → 계정 데이터 이관처럼 "다른 스코프에 뭐가 있는지" 봐야 할 때만 쓴다.
  String? getRawScoped(String scope, String key) {
    if (!StorageKeys.accountKeys.contains(key)) return getString(key);
    return _prefs.get('$scope::$key')?.toString();
  }

  // ── 쓰기 ─────────────────────────────────────────────────
  Future<void> setString(String key, String value) async {
    await _prefs.setString(_phys(key), value);
    if (StorageKeys.accountKeys.contains(key)) onAccountKeyChanged?.call(key);
  }

  /// 동기화 pull 전용 — push 훅을 트리거하지 않는다(에코 방지).
  Future<void> setStringQuiet(String key, String value) =>
      _prefs.setString(_phys(key), value);

  Future<void> setBool(String key, bool value) =>
      _prefs.setBool(_phys(key), value);

  Future<void> setInt(String key, int value) => _prefs.setInt(_phys(key), value);

  Future<void> remove(String key) => _prefs.remove(_phys(key));

  // ── 계정 스코프 관리 ──────────────────────────────────────
  /// 특정 스코프의 계정 키 전체 삭제(다른 스코프/기기설정은 보존).
  Future<void> clearScope(String scope) async {
    for (final k in StorageKeys.accountKeys) {
      await _prefs.remove('$scope::$k');
    }
  }

  /// 앱 시작 시 1회: 프리픽스 없는 기존(레거시) 계정 데이터를 guest 스코프로
  /// 이전한다. 이전 직전 전체 스냅샷을 백업해 유실을 방지한다.
  Future<void> migrateLegacyToGuestOnce() async {
    const doneFlag = '__account_scope_migrated_v1';
    if (_prefs.getBool(doneFlag) == true) return;

    // 1) 안전 백업: 현재 모든 키 스냅샷(문자열화)
    try {
      final snap = <String, String>{};
      for (final k in _prefs.getKeys()) {
        final v = _prefs.get(k);
        if (v != null) snap[k] = v.toString();
      }
      await _prefs.setString('__premigration_backup_v1', jsonEncode(snap));
    } catch (_) {/* 백업 실패해도 마이그레이션은 진행(아래 비파괴) */}

    // 2) 레거시 계정 키 → guest 스코프 (guest에 이미 있으면 보존)
    for (final k in StorageKeys.accountKeys) {
      final legacy = _prefs.get(k);
      if (legacy == null) continue;
      final guestKey = 'guest::$k';
      if (_prefs.get(guestKey) == null) {
        await _prefs.setString(guestKey, legacy.toString());
      }
      await _prefs.remove(k);
    }
    await _prefs.setBool(doneFlag, true);
  }
}
