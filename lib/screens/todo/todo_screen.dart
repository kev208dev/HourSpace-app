import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../core/utils/todo_parser.dart';
import '../../core/utils/todo_style.dart';
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../models/todo_item.dart';
import '../../modals/add_todo_modal.dart';
import '../../providers/todos_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/section_header.dart';

/// 할 일 탭 — "내가 아직 뭘 안 했지?" 하나에 답한다.
///
/// 기본 상태는 미완료/완료 두 가지뿐이다. "진행중"은 상세 화면의 선택 상태로
/// 남기고 메인 인터랙션에서는 뺐다.
enum TodoFilter { today, upcoming, all }

extension _TodoFilterX on TodoFilter {
  String get label => switch (this) {
        TodoFilter.today => '오늘',
        TodoFilter.upcoming => '예정',
        TodoFilter.all => '전체',
      };
}

class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  final _ctrl = TextEditingController();
  TodoFilter _filter = TodoFilter.today;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 자연어 한 줄로 바로 추가 — "내일 p1 빨래하기".
  void _quickAdd() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    final parsed = parseTodoInput(raw);
    final title = parsed.content.trim().isEmpty ? raw : parsed.content.trim();
    ref.read(todosProvider.notifier).add(TodoItem(
          id: const Uuid().v4(),
          title: title,
          priority: parsed.priority,
          dateKey: parsed.dateKey ?? du.todayKey(),
          createdAt: DateTime.now().toIso8601String(),
        ));
    _ctrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider);
    final todayKey = du.todayKey();

    final today = todos.where((t) => t.dateKey == todayKey).toList()
      ..sort(_order);
    final upcoming = todos
        .where((t) => t.dateKey != null && t.dateKey!.compareTo(todayKey) > 0)
        .toList()
      ..sort(_order);
    final undated = todos.where((t) => t.dateKey == null).toList()..sort(_order);
    final overdue = todos
        .where((t) =>
            !t.done &&
            t.dateKey != null &&
            t.dateKey!.compareTo(todayKey) < 0)
        .toList()
      ..sort(_order);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.sm, Gap.lg, kBottomNavClearance),
      children: [
        Text(tr('할 일'),
            style: AppType.headlineLarge.copyWith(color: context.sh.ink)),
        const SizedBox(height: Gap.md),
        _QuickAddField(controller: _ctrl, onSubmit: _quickAdd),
        const SizedBox(height: Gap.md),
        _FilterChips(
          current: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: Gap.md),
        ..._sections(
          todayKey: todayKey,
          today: today,
          upcoming: upcoming,
          undated: undated,
          overdue: overdue,
        ),
      ],
    );
  }

  List<Widget> _sections({
    required String todayKey,
    required List<TodoItem> today,
    required List<TodoItem> upcoming,
    required List<TodoItem> undated,
    required List<TodoItem> overdue,
  }) {
    final out = <Widget>[];

    void section(String title, List<TodoItem> items, {String? counter}) {
      if (items.isEmpty) return;
      out.add(SectionHeader(title: title, trailing: counter));
      out.addAll(items.map((t) => TodoTile(todo: t)));
      out.add(const SizedBox(height: Gap.lg));
    }

    switch (_filter) {
      case TodoFilter.today:
        if (overdue.isNotEmpty) section(tr('지난 할 일'), overdue);
        section(
          tr('오늘'),
          today,
          counter: '${today.where((t) => t.done).length}/${today.length}',
        );
        if (today.isEmpty && overdue.isEmpty) out.add(_empty(tr('오늘 할 일이 없어요')));
      case TodoFilter.upcoming:
        section(tr('예정'), upcoming);
        if (upcoming.isEmpty) out.add(_empty(tr('예정된 할 일이 없어요')));
      case TodoFilter.all:
        if (overdue.isNotEmpty) section(tr('지난 할 일'), overdue);
        section(tr('오늘'), today);
        section(tr('예정'), upcoming);
        section(tr('날짜 없음'), undated);
        if (today.isEmpty &&
            upcoming.isEmpty &&
            undated.isEmpty &&
            overdue.isEmpty) {
          out.add(_empty(tr('아직 할 일이 없어요')));
        }
    }
    return out;
  }

  Widget _empty(String text) => Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xl),
          child: Center(
            child: Text(text,
                style:
                    AppType.bodyLarge.copyWith(color: context.sh.inkFaint)),
          ),
        ),
      );

  /// 미완료 먼저, 그 다음 날짜, 그 다음 우선순위.
  static int _order(TodoItem a, TodoItem b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final d = (a.dateKey ?? '9999').compareTo(b.dateKey ?? '9999');
    if (d != 0) return d;
    int rank(TodoItem t) => t.hasPriority ? t.priority : 99;
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
  }
}

class _QuickAddField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  const _QuickAddField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.only(left: Gap.md, right: Gap.xs),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sh.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style: AppType.bodyLarge.copyWith(color: sh.ink),
              decoration: InputDecoration(
                hintText: tr('할 일을 말하듯 입력…'),
                hintStyle: TextStyle(color: sh.inkFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            onPressed: onSubmit,
            icon: Icon(Icons.add_rounded, color: sh.accent),
            tooltip: tr('추가'),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final TodoFilter current;
  final ValueChanged<TodoFilter> onChanged;
  const _FilterChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Wrap(
      spacing: Gap.sm,
      children: [
        for (final f in TodoFilter.values)
          ChoiceChip(
            label: Text(tr(f.label)),
            selected: f == current,
            onSelected: (_) => onChanged(f),
            showCheckmark: false,
            backgroundColor: sh.card2,
            selectedColor: sh.accentBg,
            labelStyle: AppType.bodyMedium.copyWith(
              color: f == current ? sh.accentInk : sh.inkSoft,
              fontWeight: f == current ? FontWeight.w800 : FontWeight.w600,
            ),
            side: BorderSide(color: f == current ? sh.accent : sh.border),
          ),
      ],
    );
  }
}

/// 할 일 한 줄 — 체크박스 + 제목 + (날짜) + 우선순위.
class TodoTile extends ConsumerWidget {
  final TodoItem todo;

  /// 날짜 배지를 숨긴다(이미 날짜별로 묶인 목록 안에서).
  final bool hideDate;

  const TodoTile({super.key, required this.todo, this.hideDate = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return InkWell(
      onTap: () => showAddTodoModal(context, edit: todo),
      borderRadius: BorderRadius.circular(Radii.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            IconButton(
              onPressed: () =>
                  ref.read(todosProvider.notifier).toggleDone(todo.id),
              iconSize: 22,
              constraints: const BoxConstraints(
                  minWidth: kMinTouch, minHeight: kMinTouch),
              padding: EdgeInsets.zero,
              tooltip: tr(todo.done ? '완료 취소' : '완료'),
              icon: Icon(
                todo.done
                    ? Icons.check_circle_rounded
                    : todo.inProgress
                        ? Icons.timelapse_rounded
                        : Icons.circle_outlined,
                color: todo.done
                    ? sh.now
                    : todo.inProgress
                        ? todoPriorityColor(2, sh)
                        : sh.inkFaint,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                todo.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodyLarge.copyWith(
                  color: todo.done ? sh.inkFaint : sh.ink,
                  decoration: todo.done ? TextDecoration.lineThrough : null,
                  decorationColor: sh.inkFaint,
                ),
              ),
            ),
            if (!hideDate && todo.dateKey != null) ...[
              const SizedBox(width: Gap.sm),
              Text(
                i18nd.monthDay(du.fromDateKey(todo.dateKey!)),
                style: AppType.bodySmall.copyWith(color: sh.inkFaint),
              ),
            ],
            if (todo.hasPriority) ...[
              const SizedBox(width: Gap.sm),
              Text(
                'P${todo.priority}',
                style: AppType.labelMedium.copyWith(
                  color: todoPriorityColor(todo.priority, sh),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
