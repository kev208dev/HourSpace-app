import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/date_utils.dart' as du;
import '../models/day_template.dart';
import '../providers/day_widget_provider.dart';
import '../day_widgets/widget_cell_renderer.dart';
import '../widgets/mascot/mascot.dart';

Future<void> showDayWidgetInputModal(BuildContext context, String dateKey) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DayWidgetInputModal(dateKey: dateKey),
    );

class DayWidgetInputModal extends ConsumerWidget {
  final String dateKey;
  const DayWidgetInputModal({super.key, required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final templates = ref.watch(dayTemplatesProvider);
    final applicable = templates.where((t) => t.scope.appliesTo(dateKey)).toList();
    final date = du.fromDateKey(dateKey);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        color: sh.card,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(children: [
                Text('📊 ${date.month}월 ${date.day}일 기록',
                    style: AppType.titleMedium.copyWith(fontWeight: FontWeight.w700, color: sh.ink)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Divider(color: sh.border, height: 1),
            Expanded(
              child: applicable.isEmpty
                  ? MascotEmptyState(
                      expression: MascotExpression.neutral,
                      title: '이 날짜에 적용된 위젯이 없어요',
                      message: '위젯을 만들어 하루를 기록해보세요',
                      actionText: '닫기',
                      onAction: () => Navigator.pop(context),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: applicable.map((tpl) => _TemplateSection(
                        dateKey: dateKey, template: tpl, sh: sh, ref: ref,
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateSection extends StatelessWidget {
  final String dateKey;
  final DayTemplate template;
  final SurlapColors sh;
  final WidgetRef ref;
  const _TemplateSection({required this.dateKey, required this.template,
      required this.sh, required this.ref});

  @override
  Widget build(BuildContext context) {
    final values = ref.watch(widgetValuesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(template.name,
              style: AppType.bodyLarge.copyWith(fontWeight: FontWeight.w700,
                  color: sh.inkSoft)),
        ),
        ...template.fields.map((field) {
          final value = values[dateKey]?[template.id]?[field.id];
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg),
            child: WidgetCellRenderer(
              field: field,
              value: value,
              sh: sh,
              compact: false,
              onChanged: (v) => ref.read(widgetValuesProvider.notifier)
                  .setValue(dateKey, template.id, field.id, v),
            ),
          );
        }),
        Divider(color: sh.border, height: 24),
      ],
    );
  }
}
