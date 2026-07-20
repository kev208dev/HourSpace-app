import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/date_utils.dart' as du;
import '../models/record_template.dart';
import '../models/template_range.dart';
import '../widgets/record_glyph.dart';
import '../providers/template_ranges_provider.dart';
import '../providers/record_templates_provider.dart';
import '../i18n/strings.dart';
import 'record_template_edit_sheet.dart';

/// 기록 템플릿 적용/관리 시트.
/// 프리셋(공부·독서·운동) + 커스텀 목록. 적용(기간)·복제·편집·삭제.
Future<void> showRecordTemplateSheet(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RecordTemplateSheet(),
    );

class _RecordTemplateSheet extends ConsumerWidget {
  const _RecordTemplateSheet();

  Future<DateTimeRange?> _pickRange(BuildContext context, SurlapColors sh,
      {DateTimeRange? initial}) {
    final now = DateTime.now();
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      initialDateRange: initial ??
          DateTimeRange(start: now, end: now.add(const Duration(days: 6))),
      helpText: tr('적용 기간 선택'),
      saveText: tr('적용'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              (sh.dark ? const ColorScheme.dark() : const ColorScheme.light())
                  .copyWith(
            primary: sh.accent,
            onPrimary: Colors.white,
            surface: sh.card,
            onSurface: sh.ink,
          ),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, SurlapColors sh,
      RecordTemplate tpl) async {
    // 프리셋(공부·독서·운동)은 바로 적용하지 않고, 먼저 커스터마이즈 시트를 띄워
    // 필요 없는 필드(태그/메모)를 빼고 이름·라벨을 다듬은 뒤 그 결과로 적용.
    var target = tpl;
    if (tpl.isPreset) {
      final custom = await showRecordTemplateEditSheet(
        context,
        base: tpl.copyWith(name: tpl.name),
      );
      if (custom == null) return; // 사용자가 커스터마이즈 취소
      target = custom;
    }
    if (!context.mounted) return;
    final r = await _pickRange(context, sh);
    if (r == null) return;
    await ref.read(templateRangesProvider.notifier).apply(
        target.id, du.toDateKey(r.start), du.toDateKey(r.end));
  }

  Future<void> _editRange(BuildContext context, WidgetRef ref,
      SurlapColors sh, TemplateRange range) async {
    final r = await _pickRange(context, sh,
        initial: DateTimeRange(
            start: du.fromDateKey(range.start),
            end: du.fromDateKey(range.end)));
    if (r == null) return;
    await ref.read(templateRangesProvider.notifier).update(
        range.copyWith(start: du.toDateKey(r.start), end: du.toDateKey(r.end)));
  }

  String _rangeLabel(String start, String end) {
    final s = du.fromDateKey(start);
    final e = du.fromDateKey(end);
    final days = e.difference(s).inDays + 1;
    return trf('{0}/{1} ~ {2}/{3} · {4}일',
        [s.month, s.day, e.month, e.day, days]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final templates = ref.watch(allRecordTemplatesProvider);
    final ranges = ref.watch(templateRangesProvider);
    final byId = ref.watch(recordTemplatesByIdProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sh.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: sh.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(tr('기록 템플릿'),
                      style: AppType.titleMedium.copyWith(
                          fontWeight: FontWeight.w800, color: sh.ink)),
                ),
                GestureDetector(
                  onTap: () => showRecordTemplateEditSheet(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sh.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: sh.accent),
                        const SizedBox(width: 4),
                        Text(tr('새 템플릿'),
                            style: AppType.labelMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: sh.accent)),
                      ],
                    ),
                  ),
                ),
                // 항상 보이는 닫기(×) 버튼.
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('닫기'),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(tr('기간을 정해 적용하면 그 기간 동안 매일 빠르게 기록할 수 있어요.'),
                style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
            const SizedBox(height: 14),

            ...templates.map((tpl) => _TemplateCard(
                  tpl: tpl,
                  sh: sh,
                  onApply: () => _apply(context, ref, sh, tpl),
                  onDuplicate: () => showRecordTemplateEditSheet(context,
                      base: tpl.copyWith(name: trf('{0} 복사', [tpl.name]))),
                  onEdit: tpl.isPreset
                      ? null
                      : () => showRecordTemplateEditSheet(context,
                          base: tpl, editingId: tpl.id),
                  onDelete: tpl.isPreset
                      ? null
                      : () => ref
                          .read(recordTemplatesProvider.notifier)
                          .delete(tpl.id),
                )),

            if (ranges.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(tr('적용된 기간'),
                  style: AppType.labelMedium.copyWith(
                      fontWeight: FontWeight.w700, color: sh.inkSoft)),
              const SizedBox(height: 8),
              ...ranges.map((r) {
                final tpl = byId[r.templateId];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sh.card2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      tpl != null
                          ? recordGlyph(tpl.emoji, size: 18, color: sh.inkSoft)
                          : Icon(Icons.bookmark_border_rounded,
                              size: 18, color: sh.inkSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tpl?.name ?? r.templateId,
                                style: AppType.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: sh.ink)),
                            Text(_rangeLabel(r.start, r.end),
                                style: AppType.bodySmall
                                    .copyWith(color: sh.inkSoft)),
                          ],
                        ),
                      ),
                      _IconBtn(
                          icon: Icons.edit_outlined,
                          sh: sh,
                          onTap: () => _editRange(context, ref, sh, r)),
                      const SizedBox(width: 4),
                      _IconBtn(
                          icon: Icons.delete_outline_rounded,
                          sh: sh,
                          danger: true,
                          onTap: () => ref
                              .read(templateRangesProvider.notifier)
                              .remove(r.id)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final RecordTemplate tpl;
  final SurlapColors sh;
  final VoidCallback onApply;
  final VoidCallback onDuplicate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _TemplateCard({
    required this.tpl,
    required this.sh,
    required this.onApply,
    required this.onDuplicate,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '${tpl.primaryLabel}${tpl.primaryUnit.isNotEmpty ? '(${tpl.primaryUnit})' : ''}',
      if (tpl.hasTags) tpl.tagsLabel,
      if (tpl.hasMemo) tr('메모'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: sh.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sh.accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          recordGlyph(tpl.emoji, size: 24, color: sh.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(tpl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyLarge.copyWith(
                              fontWeight: FontWeight.w800, color: sh.ink)),
                    ),
                    if (tpl.isPreset) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: sh.ink.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tr('기본'),
                            style: AppType.bodySmall.copyWith(
                                fontSize: 10, color: sh.inkSoft)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(parts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: sh.accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onApply,
            child: Text(tr('적용'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 18, color: sh.inkSoft),
            color: sh.card,
            onSelected: (v) {
              if (v == 'dup') onDuplicate();
              if (v == 'edit') onEdit?.call();
              if (v == 'del') onDelete?.call();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'dup', child: Text(tr('복제해서 수정'))),
              if (onEdit != null)
                PopupMenuItem(value: 'edit', child: Text(tr('편집'))),
              if (onDelete != null)
                PopupMenuItem(value: 'del', child: Text(tr('삭제'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final SurlapColors sh;
  final bool danger;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon,
      required this.sh,
      this.danger = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: sh.card,
          borderRadius: BorderRadius.circular(11),
        ),
        child:
            Icon(icon, size: 19, color: danger ? sh.danger : sh.inkSoft),
      ),
    );
  }
}
