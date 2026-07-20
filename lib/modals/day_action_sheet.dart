import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/todo_style.dart';
import '../i18n/strings.dart';
import '../i18n/dates.dart' as i18nd;
import '../providers/events_provider.dart';
import '../providers/todos_provider.dart';
import '../providers/day_widget_provider.dart';
import '../providers/view_provider.dart';
import '../providers/template_ranges_provider.dart';
import '../providers/record_templates_provider.dart';
import '../models/template_range.dart';
import '../models/record_template.dart';
import '../widgets/record_glyph.dart';
import '../widgets/mascot/mascot.dart';
import 'add_edit_event_modal.dart';
import 'add_todo_modal.dart';
import 'day_widget_input_modal.dart';
import 'day_template_manager_modal.dart';
import 'record_entry_sheet.dart';

/// 달력에서 날짜를 탭하면 뜨는 공용 액션 시트.
/// 월간/연속 보기 양쪽에서 동일하게 사용한다.
Future<void> showDayActionSheet(
        BuildContext context, String dateKey, DateTime date) =>
    showModalBottomSheet(
      context: context,
      builder: (_) => DayActionSheet(dateKey: dateKey, date: date),
    );

class DayActionSheet extends ConsumerWidget {
  final String dateKey;
  final DateTime date;
  const DayActionSheet({super.key, required this.dateKey, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final events =
        (ref.watch(eventsProvider)[dateKey] ?? []).where((e) => !e.isTimetable).toList();
    final todos = ref.watch(todosProvider).where((t) => t.dateKey == dateKey).toList();

    // 이 날짜에 적용된 기록 템플릿(공부·독서·운동 등) — 빠른 기록 진입.
    final ranges = ref.watch(templateRangesProvider);
    final byId = ref.watch(recordTemplatesByIdProvider);
    final activeRecords = <RecordTemplate>[];
    final seenTpl = <String>{};
    for (final TemplateRange r in ranges) {
      if (!r.covers(dateKey) || seenTpl.contains(r.templateId)) continue;
      final tpl = byId[r.templateId];
      if (tpl == null) continue;
      seenTpl.add(r.templateId);
      activeRecords.add(tpl);
    }

    return Container(
      color: sh.card,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(i18nd.monthDay(date),
                    style: AppType.bodyLarge
                        .copyWith(fontWeight: FontWeight.w700, color: sh.ink)),
                const Spacer(),
                // 항상 보이는 닫기(×) 버튼.
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: tr('닫기'),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            // 기록 템플릿 적용 기간이면 맨 위에 눈에 띄는 "기록하기" 진입.
            ...activeRecords.map((tpl) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      showRecordEntrySheet(context, tpl.id, dateKey);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: sh.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: sh.accent.withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        children: [
                          recordGlyph(tpl.emoji, size: 20, color: sh.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(trf('{0} 기록하기', [tpl.name]),
                                style: AppType.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: sh.accent)),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: sh.accent),
                        ],
                      ),
                    ),
                  ),
                )),
            _Tile(
              icon: Icons.event_rounded,
              label: tr('일정 추가'),
              color: sh.accent,
              onTap: () {
                Navigator.pop(context);
                showAddEditEventModal(context, dateKey: dateKey);
              },
            ),
            _Tile(
              icon: Icons.check_circle_outline_rounded,
              label: tr('할 일 추가'),
              color: sh.accent,
              onTap: () {
                Navigator.pop(context);
                showAddTodoModal(context, dateKey: dateKey);
              },
            ),
            _Tile(
              icon: Icons.widgets_outlined,
              label: tr('위젯 추가'),
              color: sh.ink,
              onTap: () {
                Navigator.pop(context);
                _showWidgetPicker(context, ref, dateKey);
              },
            ),
            _Tile(
              icon: Icons.today_outlined,
              label: tr('이날 자세히 보기'),
              color: sh.ink,
              onTap: () {
                Navigator.pop(context);
                ref.read(viewProvider.notifier).setDayView(dateKey);
              },
            ),

            // 이 날의 일정
            if (events.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(trf('이 날의 일정 ({0})', [events.length]),
                  style: AppType.labelMedium.copyWith(
                      fontWeight: FontWeight.w700, color: sh.inkSoft)),
              ...events.asMap().entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.circle, size: 8, color: sh.accent),
                    title: Text(e.value.t,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyLarge.copyWith(color: sh.ink)),
                    trailing:
                        Icon(Icons.edit_outlined, size: 16, color: sh.inkFaint),
                    onTap: () {
                      Navigator.pop(context);
                      showAddEditEventModal(context,
                          dateKey: dateKey, editIndex: e.key);
                    },
                  )),
            ],

            // 이 날의 할 일
            if (todos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(trf('이 날의 할 일 ({0})', [todos.length]),
                  style: AppType.labelMedium.copyWith(
                      fontWeight: FontWeight.w700, color: sh.inkSoft)),
              ...todos.map((t) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: GestureDetector(
                      onTap: () =>
                          ref.read(todosProvider.notifier).toggleDone(t.id),
                      child: Icon(
                        todoStatusIcon(t.status),
                        size: 20,
                        color: todoStatusColor(t.status, t.priority, sh),
                      ),
                    ),
                    title: Text(t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyLarge.copyWith(
                            color: t.done ? sh.inkFaint : sh.ink,
                            decoration: t.done
                                ? TextDecoration.lineThrough
                                : null)),
                    trailing:
                        Icon(Icons.edit_outlined, size: 16, color: sh.inkFaint),
                    onTap: () {
                      Navigator.pop(context);
                      showAddTodoModal(context, edit: t);
                    },
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 위젯 추가: 만들어진 위젯 중 선택 또는 새로 만들기 ──────────────
void _showWidgetPicker(BuildContext context, WidgetRef ref, String dateKey) {
  showModalBottomSheet(
    context: context,
    builder: (sheetCtx) {
      final sh = sheetCtx.sh;
      final templates = ref.read(dayTemplatesProvider);
      return Container(
        color: sh.card,
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('위젯 추가'),
                style: AppType.titleMedium
                    .copyWith(fontWeight: FontWeight.w800, color: sh.ink)),
            const SizedBox(height: 4),
            if (templates.isEmpty)
              MascotNote(
                expression: MascotExpression.neutral,
                text: tr('아직 만든 위젯이 없어요. 새로 만들어 보세요.'),
                mascotSize: 44,
              )
            else
              Text(tr('추가할 위젯을 선택하세요.'),
                  style: AppType.labelMedium.copyWith(color: sh.inkSoft)),
            const SizedBox(height: Gap.sm),
            ...templates.map((tpl) {
              final applied = tpl.scope.appliesTo(dateKey);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.dashboard_customize_outlined,
                    size: 20, color: sh.accent),
                title: Text(tpl.name,
                    style: AppType.bodyLarge.copyWith(color: sh.ink)),
                subtitle: Text(trf('{0}개 항목', [tpl.fields.length]),
                    style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
                trailing: applied
                    ? Icon(Icons.check_rounded, size: 18, color: sh.accent)
                    : Icon(Icons.add_rounded, size: 18, color: sh.inkSoft),
                onTap: () {
                  // 이 날짜에 적용되도록 보장한 뒤 입력 모달을 연다.
                  if (!applied) {
                    ref.read(dayTemplatesProvider.notifier).update(
                          tpl.copyWith(scope: tpl.scope.withDay(dateKey)),
                        );
                  }
                  Navigator.pop(sheetCtx);
                  showDayWidgetInputModal(context, dateKey);
                },
              );
            }),
            const SizedBox(height: Gap.xs),
            // 새 위젯 만들기
            InkWell(
              onTap: () {
                Navigator.pop(sheetCtx);
                showDayTemplateManagerModal(context);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: sh.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sh.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: sh.accent),
                    const SizedBox(width: 6),
                    Text(tr('새 위젯 만들기'),
                        style: AppType.bodyLarge.copyWith(
                            fontWeight: FontWeight.w800, color: sh.accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Tile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: AppType.bodyLarge.copyWith(color: color)),
      onTap: onTap,
    );
  }
}
