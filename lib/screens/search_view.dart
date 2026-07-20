import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/date_utils.dart' as du;
import '../i18n/strings.dart';
import '../models/event_item.dart';
import '../models/todo_item.dart';
import '../providers/events_provider.dart';
import '../providers/todos_provider.dart';
import '../providers/view_provider.dart';
import '../core/utils/todo_style.dart';
import '../widgets/mascot/mascot.dart';

/// 일정 + 할 일 통합 검색 시트. 결과 탭 → 해당 날짜 일간 뷰로 이동.
Future<void> showSearchSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SearchSheet(),
    );

class SearchHit {
  final String dateKey;
  final String title;
  final bool isTodo;
  final int priority;
  const SearchHit({
    required this.dateKey,
    required this.title,
    required this.isTodo,
    this.priority = 0,
  });
}

/// 일정+할 일 통합 검색 — 헤더 인라인 검색·검색 시트 공용.
List<SearchHit> searchHits(WidgetRef ref, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final hits = <SearchHit>[];
  ref.read(eventsProvider).forEach((dateKey, list) {
    for (final EventItem e in list) {
      if (e.isTimetable) continue;
      if (e.t.toLowerCase().contains(q)) {
        hits.add(SearchHit(dateKey: dateKey, title: e.t, isTodo: false));
      }
    }
  });
  for (final TodoItem t in ref.read(todosProvider)) {
    if (t.title.toLowerCase().contains(q)) {
      hits.add(SearchHit(
        dateKey: t.dateKey ?? '',
        title: t.title,
        isTodo: true,
        priority: t.priority,
      ));
    }
  }
  hits.sort((a, b) => b.dateKey.compareTo(a.dateKey));
  return hits;
}

class _SearchSheet extends ConsumerStatefulWidget {
  const _SearchSheet();

  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<SearchHit> _search() => searchHits(ref, _query);

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final hits = _search();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: sh.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: sh.ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 검색 입력
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                decoration: BoxDecoration(
                  color: sh.card2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: sh.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: AppType.bodyLarge.copyWith(color: sh.ink),
                        decoration: InputDecoration(
                          hintText: tr('일정·할 일 검색'),
                          hintStyle: TextStyle(color: sh.inkFaint),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() {
                          _ctrl.clear();
                          _query = '';
                        }),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: sh.inkFaint),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.sm),
              Expanded(
                child: _query.trim().isEmpty
                    ? MascotEmptyState(
                        expression: MascotExpression.neutral,
                        title: tr('무엇을 찾고 있나요?'),
                        message: tr('일정과 할 일을 검색해요'),
                        mascotSize: 110,
                        showStars: false,
                      )
                    : hits.isEmpty
                        ? MascotEmptyState(
                            expression: MascotExpression.thinking,
                            title: tr('검색 결과가 없어요'),
                            message: tr('다른 단어로 찾아볼까요?'),
                            mascotSize: 110,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: hits.length,
                            itemBuilder: (_, i) =>
                                SearchHitTile(hit: hits[i], sh: sh, onTap: () {
                              if (hits[i].dateKey.isNotEmpty) {
                                ref
                                    .read(viewProvider.notifier)
                                    .setDayView(hits[i].dateKey);
                              }
                              Navigator.pop(context);
                            }),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchHitTile extends StatelessWidget {
  final SearchHit hit;
  final SurlapColors sh;
  final VoidCallback onTap;
  const SearchHitTile(
      {super.key, required this.hit, required this.sh, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateLabel = hit.dateKey.isEmpty
        ? tr('날짜 없음')
        : () {
            final d = du.fromDateKey(hit.dateKey);
            return '${d.year}.${d.month}.${d.day}';
          }();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        hit.isTodo ? Icons.check_circle_outline_rounded : Icons.event_rounded,
        size: 20,
        color: hit.isTodo
            ? todoPriorityColor(hit.priority, sh)
            : sh.accent,
      ),
      title: Text(hit.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.bodyLarge.copyWith(color: sh.ink)),
      subtitle: Text(
        '${hit.isTodo ? tr('할 일') : tr('일정')} · $dateLabel',
        style: AppType.bodySmall.copyWith(color: sh.inkSoft),
      ),
      onTap: onTap,
    );
  }
}
