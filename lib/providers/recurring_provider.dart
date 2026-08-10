import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/storage_keys.dart';
import '../storage/local_store.dart';

/// 매주 반복되는 내 일정(시간표 탭에서 작성).
/// 저장 단위: 요일(col 0=월..6=일) → 시각(hour) → 제목.
/// 시간표/주간/일간에 표시되며, 월간에는 표시하지 않는다.
class RecurringNotifier extends Notifier<Map<int, Map<int, String>>> {
  @override
  Map<int, Map<int, String>> build() => _load();

  Map<int, Map<int, String>> _load() {
    final raw = LocalStore.instance.getString(StorageKeys.timetableWeekly);
    final result = <int, Map<int, String>>{};
    if (raw == null) return result;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((colStr, hours) {
        final col = int.tryParse(colStr);
        if (col == null || hours is! Map) return;
        final hm = <int, String>{};
        hours.forEach((h, t) {
          final hi = int.tryParse(h.toString());
          if (hi != null) hm[hi] = t.toString();
        });
        result[col] = hm;
      });
    } catch (_) {}
    return result;
  }

  void _persist() {
    final out = <String, dynamic>{};
    state.forEach((col, hours) {
      if (hours.isEmpty) return;
      out['$col'] = hours.map((h, t) => MapEntry('$h', t));
    });
    LocalStore.instance.setString(StorageKeys.timetableWeekly, jsonEncode(out));
  }

  /// 셀 저장(빈 텍스트면 삭제).
  void setCell(int col, int hour, String text) {
    final next = {
      for (final e in state.entries) e.key: {...e.value},
    };
    final hm = next.putIfAbsent(col, () => <int, String>{});
    if (text.trim().isEmpty) {
      hm.remove(hour);
    } else {
      hm[hour] = text.trim();
    }
    if (hm.isEmpty) next.remove(col);
    state = next;
    _persist();
  }

  /// 여러 칸을 한 번에 저장한다. 시간표 빠른 편집기에서 한 번만 리빌드·저장하도록 사용한다.
  void setCells(Map<(int, int), String> cells) {
    final next = {
      for (final entry in state.entries) entry.key: {...entry.value},
    };
    for (final entry in cells.entries) {
      final (col, hour) = entry.key;
      final hours = next.putIfAbsent(col, () => <int, String>{});
      final text = entry.value.trim();
      if (text.isEmpty) {
        hours.remove(hour);
      } else {
        hours[hour] = text;
      }
      if (hours.isEmpty) next.remove(col);
    }
    state = next;
    _persist();
  }

  String? cell(int col, int hour) => state[col]?[hour];

  /// 계정 전환/클라우드 pull 후 다시 읽기.
  void reload() => state = _load();
}

/// weekday(0=월..6=일) → hour → 제목.
final recurringProvider =
    NotifierProvider<RecurringNotifier, Map<int, Map<int, String>>>(
      RecurringNotifier.new,
    );

/// DateTime의 요일을 0=월..6=일 인덱스로.
int weekdayIndex(DateTime d) => d.weekday - 1;
