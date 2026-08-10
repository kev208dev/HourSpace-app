/// 전역 검색 — 캘린더에 올라오는 모든 소스 + 할 일을 한 번에 찾는다.
///
/// 기존 검색은 로컬 일정과 할 일만 봤고 필터도 적용하지 않았다. 학교 시간표·
/// 학사일정·공유·스포츠·생일·공휴일·반복 일정은 아예 검색되지 않았다.
/// 이제 [calendarItemsByDateProvider]를 그대로 쓰므로 캘린더에 보이는 것은
/// 전부 검색된다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/todo_item.dart';
import '../../providers/todos_provider.dart';
import '../utils/date_utils.dart' as du;
import 'calendar_item.dart';
import 'calendar_repository.dart';

/// 검색 결과 한 건.
class SearchHit {
  /// 캘린더 항목이면 채워진다.
  final CalendarItem? item;

  /// 할 일이면 채워진다.
  final TodoItem? todo;

  const SearchHit._({this.item, this.todo});

  factory SearchHit.calendar(CalendarItem item) => SearchHit._(item: item);
  factory SearchHit.todo(TodoItem todo) => SearchHit._(todo: todo);

  bool get isTodo => todo != null;
  String get title => item?.title ?? todo?.title ?? '';

  /// 'YYYY-MM-DD'. 날짜 없는 할 일은 빈 문자열.
  String get dateKey => item?.dateKey ?? todo?.dateKey ?? '';

  CalendarSource? get source => item?.source;
  int get priority => todo?.priority ?? 0;

  /// 결과 묶음 — 학교 / 일정 / 할 일.
  SearchGroup get group {
    if (isTodo) return SearchGroup.todo;
    return switch (item!.source) {
      CalendarSource.schoolTimetable ||
      CalendarSource.schoolAcademic =>
        SearchGroup.school,
      _ => SearchGroup.event,
    };
  }
}

enum SearchGroup { school, event, todo }

extension SearchGroupX on SearchGroup {
  String get label => switch (this) {
        SearchGroup.school => '학교',
        SearchGroup.event => '일정',
        SearchGroup.todo => '할 일',
      };
}

/// 검색 파라미터.
class SearchQuery {
  final String text;

  /// 숨긴 캘린더도 결과에 포함할지(스펙 §16).
  final bool includeHidden;

  const SearchQuery(this.text, {this.includeHidden = false});

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.text == text &&
      other.includeHidden == includeHidden;

  @override
  int get hashCode => Object.hash(text, includeHidden);
}

/// 시간표를 함께 훑는 범위 — 오늘 기준 앞뒤 며칠.
///
/// NEIS 캐시가 이번 주만 보관하므로 그 밖은 직접 입력한 주간 시간표만 잡힌다.
/// 무한정 훑지 않는다는 사실을 여기 한 곳에 명시해 둔다.
const int kTimetableSearchDaysBack = 7;
const int kTimetableSearchDaysForward = 14;

/// 전역 검색 결과 — 그룹(학교 → 일정 → 할 일), 그룹 안에서는 날짜 순.
final globalSearchProvider =
    Provider.family<List<SearchHit>, SearchQuery>((ref, query) {
  final q = query.text.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final hits = <SearchHit>[];
  final seenIds = <String>{};

  void addItem(CalendarItem item) {
    if (!item.title.toLowerCase().contains(q)) return;
    if (!seenIds.add(item.id)) return;
    hits.add(SearchHit.calendar(item));
  }

  // ── 캘린더 항목 (시간표 제외 — 아래에서 따로) ──────────────────
  final byDate = query.includeHidden
      ? ref.watch(rawCalendarItemsByDateProvider)
      : ref.watch(calendarItemsByDateProvider);
  for (final list in byDate.values) {
    for (final item in list) {
      addItem(item);
    }
  }

  // ── 시간표 — 오늘 근처 범위만 ──────────────────────────────────
  final today = DateTime.now();
  for (var d = -kTimetableSearchDaysBack;
      d <= kTimetableSearchDaysForward;
      d++) {
    final day = DateTime(today.year, today.month, today.day + d);
    for (final item in ref.watch(calendarDayProvider(du.toDateKey(day)))) {
      if (item.source != CalendarSource.schoolTimetable) continue;
      addItem(item);
    }
  }

  // ── 할 일 ───────────────────────────────────────────────────────
  for (final t in ref.watch(todosProvider)) {
    if (t.title.toLowerCase().contains(q)) hits.add(SearchHit.todo(t));
  }

  hits.sort((a, b) {
    final g = a.group.index.compareTo(b.group.index);
    if (g != 0) return g;
    // 날짜 없는 할 일은 뒤로.
    if (a.dateKey.isEmpty != b.dateKey.isEmpty) {
      return a.dateKey.isEmpty ? 1 : -1;
    }
    final d = a.dateKey.compareTo(b.dateKey);
    if (d != 0) return d;
    return a.title.compareTo(b.title);
  });
  return hits;
});
