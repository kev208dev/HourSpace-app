import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_item.dart';
import '../core/constants/storage_keys.dart';
import '../storage/local_store.dart';

class EventsNotifier extends Notifier<Map<String, List<EventItem>>> {
  @override
  Map<String, List<EventItem>> build() {
    final raw = LocalStore.instance.getString(StorageKeys.events);
    return raw != null ? eventsFromJson(raw) : {};
  }

  Future<void> _save() async {
    await LocalStore.instance.setString(
      StorageKeys.events, eventsToJson(state));
  }

  List<EventItem> forDate(String dateKey) => state[dateKey] ?? [];

  Future<void> addEvent(String dateKey, EventItem item) async {
    final updated = Map<String, List<EventItem>>.from(state);
    updated[dateKey] = [...(updated[dateKey] ?? []), item];
    state = updated;
    await _save();
  }

  Future<void> updateEvent(String dateKey, int index, EventItem item) async {
    final updated = Map<String, List<EventItem>>.from(state);
    final list = List<EventItem>.from(updated[dateKey] ?? []);
    if (index >= 0 && index < list.length) {
      list[index] = item;
      updated[dateKey] = list;
      state = updated;
      await _save();
    }
  }

  /// 일정을 [fromKey] 의 [index] 자리에서 [toKey] 로 옮긴다(원자적).
  ///
  /// 날짜는 저장 키 자체라서 날짜 변경은 "삭제 + 추가"가 된다. 예전에는
  /// 호출부가 두 연산을 따로 했고, 게다가 새 날짜 배열에 **옛 인덱스**로 써서
  /// 엉뚱한 일정을 덮어쓰고 원본은 그대로 남는 문제가 있었다.
  /// 한 번의 state 갱신으로 처리해 중간 상태가 생기지 않게 한다.
  ///
  /// [fromKey] == [toKey] 이면 제자리 수정과 같다.
  Future<void> moveEvent(
      String fromKey, int index, String toKey, EventItem item) async {
    final updated = Map<String, List<EventItem>>.from(state);
    final from = List<EventItem>.from(updated[fromKey] ?? const []);
    if (index < 0 || index >= from.length) return;

    if (fromKey == toKey) {
      from[index] = item;
      updated[fromKey] = from;
      state = updated;
      await _save();
      return;
    }

    from.removeAt(index);
    if (from.isEmpty) {
      updated.remove(fromKey);
    } else {
      updated[fromKey] = from;
    }
    updated[toKey] = [...(updated[toKey] ?? const []), item];
    state = updated;
    await _save();
  }

  Future<void> deleteEvent(String dateKey, int index) async {
    final updated = Map<String, List<EventItem>>.from(state);
    final list = List<EventItem>.from(updated[dateKey] ?? []);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      if (list.isEmpty) {
        updated.remove(dateKey);
      } else {
        updated[dateKey] = list;
      }
      state = updated;
      await _save();
    }
  }

  /// Supabase pull 후 전체 교체
  Future<void> replaceAll(Map<String, List<EventItem>> next) async {
    state = next;
    await _save();
  }
}

final eventsProvider =
    NotifierProvider<EventsNotifier, Map<String, List<EventItem>>>(
        EventsNotifier.new);
