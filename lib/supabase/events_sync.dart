// events.js 대응 — Supabase events 테이블과 동기화.
//
// 예전에는 date/title/is_timetable/theme_id/position 다섯 컬럼만 주고받아,
// 업로드 → 로그아웃 → 다운로드 하면 시작·종료 시각(tm/te), 반복 규칙(rr),
// id, created_at, 다중 캘린더가 전부 사라졌다. 모든 일정이 종일·1회성으로
// 바뀌는 데이터 손실이다.
//
// 이제 EventItem.toJson() 전체를 `payload` jsonb 컬럼에 그대로 싣는다.
// 기존 컬럼도 계속 채워 웹 클라이언트·구버전 앱과 양방향 호환을 유지한다.
import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../models/event_item.dart';
import '../storage/local_store.dart';
import 'supabase_client.dart';

class EventsSync {
  static bool _pullAttempted = false;

  /// 서버에 `payload` 컬럼이 없는 프로젝트(마이그레이션 미적용)에서는
  /// 한 번 실패한 뒤 레거시 컬럼만으로 계속 동작한다.
  static bool _payloadSupported = true;

  @visibleForTesting
  static void resetPayloadSupportForTest() => _payloadSupported = true;

  static const _selectColumns =
      'date,title,is_timetable,theme_id,position,payload';
  static const _selectColumnsLegacy =
      'date,title,is_timetable,theme_id,position';

  /// 현재 계정의 events 전체를 클라우드에서 받아 현재 스코프 로컬 캐시에 교체.
  /// 성공 시 true. 실패 시 로컬을 건드리지 않는다(증발 방지).
  static Future<bool> pullToLocal() async {
    final client = sb;
    if (client == null) return false;
    final user = client.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await _selectRows(user.id);
      if (res == null) return false;
      final byDate = <String, List<EventItem>>{};
      for (final row in res) {
        final date = row['date'] as String?;
        if (date == null) continue;
        (byDate[date] ??= []).add(rowToItem(row));
      }
      await LocalStore.instance
          .setStringQuiet(StorageKeys.events, eventsToJson(byDate));
      _pullAttempted = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// payload 컬럼을 포함해 조회하고, 컬럼이 없으면 레거시 컬럼으로 재시도.
  static Future<List<Map<String, dynamic>>?> _selectRows(String userId) async {
    final client = sb;
    if (client == null) return null;
    Future<List<Map<String, dynamic>>> run(String columns) async {
      final res = await client
          .from('events')
          .select(columns)
          .eq('user_id', userId)
          .order('date')
          .order('position');
      return (res as List).cast<Map<String, dynamic>>();
    }

    if (_payloadSupported) {
      try {
        return await run(_selectColumns);
      } catch (e) {
        if (!_looksLikeMissingPayloadColumn(e)) rethrow;
        _payloadSupported = false;
        debugPrint('[EventsSync] payload 컬럼 없음 — 레거시 컬럼으로 전환');
      }
    }
    return run(_selectColumnsLegacy);
  }

  static bool _looksLikeMissingPayloadColumn(Object e) =>
      e.toString().toLowerCase().contains('payload');

  static Map<String, dynamic> itemToRow(
    String date,
    EventItem item,
    int pos,
    String userId, {
    bool includePayload = true,
  }) =>
      {
        'date': date,
        'title': item.t,
        'is_timetable': item.isTimetable,
        'theme_id': item.themeIds.isEmpty ? null : item.themeIds.first,
        'position': pos,
        'user_id': userId,
        // 손실 없는 왕복을 위한 원본 전체. 레거시 컬럼은 웹 호환용으로 유지.
        if (includePayload) 'payload': item.toJson(),
      };

  static EventItem rowToItem(Map<String, dynamic> row) {
    // payload 가 있으면 그것이 원본 — 시각·반복·id 가 전부 살아 있다.
    final payload = row['payload'];
    if (payload is Map) {
      final item = EventItem.fromJson(Map<String, dynamic>.from(payload));
      if (item.t.isNotEmpty) return item;
    }
    // 구버전 행(payload 없음) — 있는 것만 복원.
    final isTT = row['is_timetable'] == true;
    final themeId = row['theme_id'] as String?;
    return EventItem(
      t: (row['title'] ?? '').toString(),
      tt: isTT,
      th: themeId,
    );
  }

  static Future<bool> pushDate(String date, List<EventItem> items) async {
    final client = sb;
    if (client == null || !_pullAttempted) return false;
    final user = client.auth.currentUser;
    if (user == null) return false;

    try {
      await client
          .from('events')
          .delete()
          .eq('date', date)
          .eq('user_id', user.id);
      if (items.isEmpty) return true;

      Future<void> insert({required bool withPayload}) => client
          .from('events')
          .insert(items
              .asMap()
              .entries
              .map((e) => itemToRow(date, e.value, e.key, user.id,
                  includePayload: withPayload))
              .toList());

      if (_payloadSupported) {
        try {
          await insert(withPayload: true);
          return true;
        } catch (e) {
          if (!_looksLikeMissingPayloadColumn(e)) rethrow;
          _payloadSupported = false;
          debugPrint('[EventsSync] payload 컬럼 없음 — 레거시 형식으로 저장');
        }
      }
      await insert(withPayload: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pushAll(Map<String, List<EventItem>> events) async {
    if (!_pullAttempted) return;
    for (final entry in events.entries) {
      if (entry.key.startsWith('__')) continue;
      await pushDate(entry.key, entry.value);
    }
  }

  /// 현재 스코프 로컬 events 를 통째로 클라우드에 push(디바운스 훅에서 호출).
  static Future<void> pushLocal() async {
    final raw = LocalStore.instance.getString(StorageKeys.events);
    await pushAll(raw != null ? eventsFromJson(raw) : {});
  }

  static void forceReady() => _pullAttempted = true;
}
