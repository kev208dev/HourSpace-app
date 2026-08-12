import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../core/utils/todo_style.dart';
import '../../i18n/dates.dart' as i18nd;
import '../../i18n/strings.dart';
import '../../models/todo_item.dart';
import '../../modals/add_todo_modal.dart';
import '../../providers/todos_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../search_view.dart';

/// 할 일 (핸드오프 E1 · spec §8).
///
/// 날짜가 있는 할 일과 날짜 없는 할 일을 카드 그룹 둘로 나눠 보여준다.
/// 정렬은 P1 → P2 → P3 → 없음 → 생성 시각.
///
/// 상태 표기는 세 단계(시작 전 · 진행 중 · 완료)를 그대로 보여주되, 탭은
/// 완료 ↔ 미완료 두 단계만 오간다. 진행 중은 상세 화면에서 지정한다 —
/// 체크박스를 눌러 완료를 취소하려는데 "진행 중"을 거치는 동작이 헷갈린다.
class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final todos = ref.watch(todosProvider);
    final dated = todos.where((t) => t.dateKey != null).toList()..sort(_order);
    final undated = todos.where((t) => t.dateKey == null).toList()..sort(_order);
    final done = todos.where((t) => t.done).length;

    // 추가 버튼은 MainShell 의 전역 FAB(일정·할 일·기록) 하나만 쓴다.
    // 하단 여백은 다른 탭과 같게 내비 + 전역 FAB 기준으로만 잡는다.
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.md, Gap.lg, kBottomNavClearance + Gap.xl),
      children: [
        _Header(done: done, total: todos.length),
        const SizedBox(height: Gap.sm),
        _GroupLabel(tr('날짜가 있는 할 일')),
        if (dated.isEmpty)
          _EmptyLine(tr('날짜가 있는 할 일이 없습니다.'))
        else
          _TodoCard(todos: dated, showDate: true),
        const SizedBox(height: Gap.lg),
        _GroupLabel(tr('날짜 없는 할 일')),
        if (undated.isEmpty)
          _EmptyLine(tr('날짜 없는 할 일이 없습니다.'))
        else
          _TodoCard(todos: undated, showDate: false),
        const SizedBox(height: Gap.lg),
        // 저장 범위를 화면에 그대로 고지한다.
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: sh.card2,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: sh.ink.withValues(alpha: 0.45)),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  tr('할 일은 계정별로 기기에 저장되고, 클라우드 동기화와 JSON 백업에도 함께 담깁니다.'),
                  style: AppType.sub.copyWith(
                      fontSize: 12,
                      height: 1.55,
                      color: sh.ink.withValues(alpha: 0.58)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// P1 → P2 → P3 → 없음 → 생성 시각.
  static int _order(TodoItem a, TodoItem b) {
    int rank(TodoItem t) => t.hasPriority ? t.priority : 99;
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
  }
}

class _Header extends StatelessWidget {
  final int done;
  final int total;
  const _Header({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('할 일'),
                  style: AppType.display.copyWith(
                      fontSize: 26, fontWeight: FontWeight.w700, color: sh.ink)),
              const SizedBox(height: 4),
              Text(
                trf('{0} / {1} 완료', [done, total]),
                style: AppType.sub
                    .copyWith(color: sh.ink.withValues(alpha: 0.55)),
              ),
            ],
          ),
        ),
        InkResponse(
          onTap: () => showSearchSheet(context),
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.search_rounded, size: 20, color: sh.ink),
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.sm),
        child: Text(text,
            style: AppType.label
                .copyWith(color: context.sh.ink.withValues(alpha: 0.50))),
      );
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Text(text,
            style: AppType.body
                .copyWith(color: context.sh.ink.withValues(alpha: 0.42))),
      );
}

/// 할 일 카드 — 흰 카드 안에 행이 divider 로 나뉜다.
class _TodoCard extends StatelessWidget {
  final List<TodoItem> todos;
  final bool showDate;
  const _TodoCard({required this.todos, required this.showDate});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: sh.shadowCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < todos.length; i++)
            _TodoRow(
              todo: todos[i],
              showDate: showDate,
              last: i == todos.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TodoRow extends ConsumerWidget {
  final TodoItem todo;
  final bool showDate;
  final bool last;

  const _TodoRow({
    required this.todo,
    required this.showDate,
    required this.last,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return InkWell(
      onTap: () => ref.read(todosProvider.notifier).toggleDone(todo.id),
      onLongPress: () => showAddTodoModal(context, edit: todo),
      child: Opacity(
        opacity: todo.done ? 0.55 : 1,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 13),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: sh.border)),
          ),
          child: Row(
            children: [
              Icon(todoStatusIcon(todo.status),
                  size: 21,
                  color: todoStatusColor(todo.status, todo.priority, sh)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.button.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: sh.ink,
                        decoration:
                            todo.done ? TextDecoration.lineThrough : null,
                        decorationColor: sh.ink.withValues(alpha: 0.45),
                      ),
                    ),
                    if (showDate) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${_statusLabel(todo)} · ${_dateLabel(todo)}',
                        style: AppType.caption.copyWith(
                            color: sh.ink.withValues(alpha: 0.48)),
                      ),
                    ],
                  ],
                ),
              ),
              if (todo.hasPriority) ...[
                const SizedBox(width: Gap.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: todoPriorityColor(todo.priority, sh)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text('P${todo.priority}',
                      style: AppType.micro.copyWith(
                          color: todoPriorityColor(todo.priority, sh))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(TodoItem t) {
    if (t.done) return tr('완료');
    if (t.inProgress) return tr('진행 중');
    return tr('시작 전');
  }

  static String _dateLabel(TodoItem t) {
    final key = t.dateKey;
    if (key == null) return tr('날짜 없음');
    try {
      final d = du.fromDateKey(key);
      return '${d.month}월 ${d.day}일 ${i18nd.weekdayShort(d.weekday)}';
    } catch (_) {
      return '';
    }
  }
}
