import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar/calendar_item.dart';
import '../core/calendar/global_search.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/date_utils.dart' as du;
import '../i18n/strings.dart';
import '../providers/view_provider.dart';
import '../widgets/app_toast.dart';

/// 검색 (핸드오프 C5 · spec §9).
///
/// 목업은 검색 범위를 "내 일정 + 할 일"로만 잡았지만, 여기서는 캘린더에 보이는
/// 모든 소스를 찾는다. 화면에 떠 있는 항목이 검색되지 않으면 사용자는 그것을
/// 결함으로 받아들인다. 대신 결과마다 출처를 표시해 어디서 온 항목인지 바로
/// 알 수 있게 했다.
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

  void _open(SearchHit hit) {
    if (hit.dateKey.isEmpty) {
      // 날짜 없는 할 일은 이동할 곳이 없다 — 안내만 하고 닫지 않는다.
      AppToast.show(context, tr('날짜가 없는 할 일이라 이동할 곳이 없습니다.'));
      return;
    }
    ref.read(viewProvider.notifier).openDay(hit.dateKey);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final hits = ref.watch(globalSearchProvider(
        SearchQuery(_query, includeHidden: _includeHidden)));
    final typed = _query.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: sh.bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sh.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchField(
                      controller: _ctrl,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      tr('일정·할 일·학교 일정·공유·스포츠·생일·공휴일을 모두 찾습니다.'),
                      style: AppType.caption.copyWith(
                          height: 1.6,
                          color: sh.ink.withValues(alpha: 0.48)),
                    ),
                    if (typed)
                      _HiddenToggle(
                        value: _includeHidden,
                        onChanged: (v) => setState(() => _includeHidden = v),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: !typed
                    ? _Notice(tr('검색어를 입력하세요.'))
                    : hits.isEmpty
                        ? _Notice(tr('일치하는 항목이 없습니다.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                Gap.lg, 0, Gap.lg, Gap.xl),
                            itemCount: hits.length,
                            itemBuilder: (_, i) => _ResultRow(
                              hit: hits[i],
                              onTap: () => _open(hits[i]),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              size: 17, color: sh.ink.withValues(alpha: 0.45)),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              style: AppType.button.copyWith(
                  fontSize: 14.5, fontWeight: FontWeight.w400, color: sh.ink),
              decoration: InputDecoration(
                hintText: tr('일정·할 일 검색'),
                hintStyle: TextStyle(
                    color: sh.ink.withValues(alpha: Alpha.placeholder)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
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
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                value
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 16,
                color: value ? sh.accent : sh.ink.withValues(alpha: 0.38)),
            const SizedBox(width: 7),
            Text(tr('숨긴 캘린더 포함'),
                style: AppType.sub.copyWith(
                    color: value ? sh.accent : sh.ink.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice(this.text);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 0),
          child: Text(text,
              style: AppType.body.copyWith(
                  color: context.sh.ink.withValues(alpha: 0.42))),
        ),
      );
}

/// 결과 한 줄 — 제목 · 출처(accent 11px) · 날짜(11.5px 45%).
class _ResultRow extends StatelessWidget {
  final SearchHit hit;
  final VoidCallback onTap;
  const _ResultRow({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: sh.ink.withValues(alpha: 0.07))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(hit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.button.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: sh.ink)),
            ),
            const SizedBox(width: 10),
            Text(_kind, style: AppType.label.copyWith(color: sh.accent)),
            const SizedBox(width: 10),
            Text(_sub,
                style: AppType.caption
                    .copyWith(color: sh.ink.withValues(alpha: 0.45))),
          ],
        ),
      ),
    );
  }

  String get _kind =>
      hit.isTodo ? tr('할 일') : tr(hit.source!.badgeLabel);

  String get _sub {
    if (hit.dateKey.isEmpty) return tr('날짜 없음');
    try {
      final d = du.fromDateKey(hit.dateKey);
      final time = hit.item?.startHhmm;
      final date = '${d.month}월 ${d.day}일';
      return time == null ? date : '$date $time';
    } catch (_) {
      return '';
    }
  }
}
