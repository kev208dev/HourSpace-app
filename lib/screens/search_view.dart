import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/calendar/calendar_item.dart';
import '../core/calendar/global_search.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/date_utils.dart' as du;
import '../core/utils/todo_style.dart';
import '../i18n/strings.dart';
import '../providers/view_provider.dart';
import '../widgets/source_badge.dart';
import '../widgets/ui_kit.dart';

/// 전역 검색 시트 — 캘린더에 보이는 모든 소스 + 할 일.
/// 결과를 탭하면 해당 날짜의 일간 뷰로 이동한다.
Future<void> showSearchSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SearchSheet(),
    );

class _SearchSheet extends ConsumerStatefulWidget {
  const _SearchSheet();

  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';
  bool _includeHidden = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openHit(SearchHit hit) {
    if (hit.dateKey.isNotEmpty) {
      ref.read(viewProvider.notifier).openDay(hit.dateKey);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final hits = ref.watch(
        globalSearchProvider(SearchQuery(_query, includeHidden: _includeHidden)));
    final rows = _buildRows(hits);

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
              _SearchField(
                controller: _ctrl,
                query: _query,
                onChanged: (v) => setState(() => _query = v),
                onClear: () => setState(() {
                  _ctrl.clear();
                  _query = '';
                }),
              ),
              if (_query.trim().isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _HiddenToggle(
                    value: _includeHidden,
                    onChanged: (v) => setState(() => _includeHidden = v),
                  ),
                ),
              const SizedBox(height: Gap.sm),
              Expanded(
                child: _query.trim().isEmpty
                    ? SurlapEmptyState(
  icon: Icons.search_rounded,
                        title: tr('무엇을 찾고 있나요?'),
                        description: tr('일정·할 일·학교 일정을 모두 찾아요'),
                      )
                    : hits.isEmpty
                        ? SurlapEmptyState(
  icon: Icons.search_rounded,
                            title: tr('검색 결과가 없어요'),
                            description: tr('다른 단어로 찾아볼까요?'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: rows.length,
                            itemBuilder: (_, i) {
                              final row = rows[i];
                              if (row.header != null) {
                                return _GroupHeader(
                                    label: tr(row.header!.label), sh: sh);
                              }
                              return SearchHitTile(
                                hit: row.hit!,
                                sh: sh,
                                onTap: () => _openHit(row.hit!),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 그룹 헤더를 끼워 넣은 평면 리스트.
  List<_Row> _buildRows(List<SearchHit> hits) {
    final rows = <_Row>[];
    SearchGroup? current;
    for (final h in hits) {
      if (h.group != current) {
        current = h.group;
        rows.add(_Row.header(current));
      }
      rows.add(_Row.hit(h));
    }
    return rows;
  }
}

class _Row {
  final SearchGroup? header;
  final SearchHit? hit;
  const _Row.header(this.header) : hit = null;
  const _Row.hit(this.hit) : header = null;
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
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
              controller: controller,
              autofocus: true,
              style: AppType.body.copyWith(color: sh.ink),
              decoration: InputDecoration(
                hintText: tr('일정·할 일·학교 검색'),
                hintStyle: TextStyle(color: sh.inkFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: onChanged,
            ),
          ),
          if (query.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded, size: 18, color: sh.inkFaint),
            ),
        ],
      ),
    );
  }
}

class _HiddenToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _HiddenToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return TextButton.icon(
      onPressed: () => onChanged(!value),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: const Size(0, kMinTouch),
        foregroundColor: value ? sh.accent : sh.inkSoft,
      ),
      icon: Icon(
        value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
        size: 18,
      ),
      label: Text(tr('숨긴 캘린더 포함'), style: AppType.caption),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final SurlapColors sh;
  const _GroupHeader({required this.label, required this.sh});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, Gap.lg, 4, Gap.xs),
        child: Text(
          label,
          style: AppType.eyebrow.copyWith(color: sh.inkFaint),
        ),
      );
}

class SearchHitTile extends StatelessWidget {
  final SearchHit hit;
  final SurlapColors sh;
  final VoidCallback onTap;
  const SearchHitTile(
      {super.key, required this.hit, required this.sh, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minVerticalPadding: 10,
      leading: Icon(
        _icon,
        size: 20,
        color: hit.isTodo ? todoPriorityColor(hit.priority, sh) : _tint,
      ),
      title: Text(hit.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.body.copyWith(color: sh.ink)),
      subtitle: Text(_subtitle, style: AppType.caption.copyWith(color: sh.inkSoft)),
      trailing: hit.isTodo
          ? const TodoBadge()
          : SourceBadge(source: hit.source!, color: hit.item?.color),
      onTap: onTap,
    );
  }

  Color get _tint => hit.item?.color ?? sh.accent;

  IconData get _icon {
    if (hit.isTodo) return Icons.check_circle_outline_rounded;
    return switch (hit.source!) {
      CalendarSource.schoolTimetable => Icons.schedule_rounded,
      CalendarSource.schoolAcademic => Icons.school_rounded,
      CalendarSource.shared => Icons.group_rounded,
      CalendarSource.sports => Icons.sports_soccer_rounded,
      CalendarSource.birthday => Icons.cake_rounded,
      CalendarSource.holiday => Icons.flag_rounded,
      CalendarSource.local => Icons.event_rounded,
    };
  }

  String get _subtitle {
    if (hit.dateKey.isEmpty) return tr('날짜 없음');
    final d = du.fromDateKey(hit.dateKey);
    final date = '${d.year}.${d.month}.${d.day}';
    final time = hit.item?.startHhmm;
    return time == null ? date : '$date · $time';
  }
}
