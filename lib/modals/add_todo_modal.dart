import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/date_utils.dart' as du;
import '../i18n/strings.dart';
import '../core/utils/todo_parser.dart';
import '../core/utils/todo_style.dart';
import '../models/todo_item.dart';
import '../providers/todos_provider.dart';
import '../widgets/mascot/mascot_feedback.dart';

/// 할 일 추가/편집 모달. dateKey가 주어지면 기본 날짜로 사용.
Future<void> showAddTodoModal(
  BuildContext context, {
  String? dateKey,
  TodoItem? edit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddTodoModal(initialDateKey: dateKey, edit: edit),
  );
}

class AddTodoModal extends ConsumerStatefulWidget {
  final String? initialDateKey;
  final TodoItem? edit;
  const AddTodoModal({super.key, this.initialDateKey, this.edit});

  @override
  ConsumerState<AddTodoModal> createState() => _AddTodoModalState();
}

class _AddTodoModalState extends ConsumerState<AddTodoModal> {
  final _textCtrl = TextEditingController();
  final _speech = SpeechToText();

  // 수동 override (null이면 자연어 파싱값 사용)
  String? _dateOverride;
  int? _prioOverride;
  bool _dateTouched = false;
  bool _prioTouched = false;

  bool _listening = false;
  bool _speechReady = false;
  String? _speechErr; // 마지막 음성 인식 오류(원인 안내용)

  bool get isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final e = widget.edit!;
      _textCtrl.text = e.title;
      _dateOverride = e.dateKey;
      _prioOverride = e.priority == 0 ? null : e.priority;
      _dateTouched = e.dateKey != null;
      _prioTouched = e.priority != 0;
    } else if (widget.initialDateKey != null) {
      _dateOverride = widget.initialDateKey;
      _dateTouched = true;
    }
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          // 인식이 끝났을 때만 듣기 상태 해제.
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _speechErr = e.errorMsg;
            });
          }
        },
      );
    } catch (e) {
      _speechReady = false;
      _speechErr = '$e';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speech.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  ParsedTodo get _parsed => parseTodoInput(_textCtrl.text);
  String? get _effDate => _dateTouched ? _dateOverride : _parsed.dateKey;
  int get _effPriority => _prioTouched ? (_prioOverride ?? 0) : _parsed.priority;

  // ── 음성 입력 (마이크를 꾹 누르고 있는 동안 듣기) ──────────────
  Future<void> _startListen() async {
    if (_listening) return;
    if (!_speechReady) {
      await _initSpeech();
    }
    if (!_speechReady) {
      if (mounted) {
        final detail = _speechErr != null ? ' ($_speechErr)' : '';
        _snack(trf('음성 인식을 사용할 수 없어요. 설정에서 마이크·음성 인식 권한을 허용해 주세요.{0}', [detail]));
      }
      return;
    }
    setState(() => _listening = true);
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          partialResults: true,
          localeId: 'ko_KR',
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 10),
        ),
        onResult: (res) {
          if (!mounted) return;
          setState(() {
            _textCtrl.text = res.recognizedWords;
            _textCtrl.selection =
                TextSelection.collapsed(offset: _textCtrl.text.length);
            // 음성으로 채울 땐 파싱값을 다시 따르도록 override 해제.
            _dateTouched = false;
            _prioTouched = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _listening = false);
        _snack(trf('음성 인식을 시작하지 못했어요 ({0})', [e]));
      }
    }
  }

  Future<void> _stopListen() async {
    if (!_listening) return;
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _save() {
    final parsed = _parsed;
    final title = parsed.content.isNotEmpty ? parsed.content : _textCtrl.text.trim();
    if (title.isEmpty) {
      MascotToast.error(context, tr('할 일을 입력해주세요'));
      return;
    }
    final notifier = ref.read(todosProvider.notifier);
    if (isEdit) {
      notifier.update(
        widget.edit!.id,
        widget.edit!.copyWith(
          title: title,
          dateKey: _effDate,
          priority: _effPriority,
        ),
      );
    } else {
      notifier.add(TodoItem(
        id: const Uuid().v4(),
        title: title,
        dateKey: _effDate,
        priority: _effPriority,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }
    MascotToast.success(context, isEdit ? tr('할 일을 수정했어요') : tr('좋아요! 할 일을 추가했어요'));
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final initial =
        _effDate != null ? du.fromDateKey(_effDate!) : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: context.sh.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateOverride = du.toDateKey(picked);
        _dateTouched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final parsed = _parsed;
    final effDate = _effDate;
    final effPrio = _effPriority;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sh.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(isEdit ? tr('할 일 편집') : tr('할 일 추가'),
                    style: AppType.titleLarge.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: sh.ink)),
                const Spacer(),
                if (isEdit)
                  TextButton(
                    onPressed: () {
                      ref.read(todosProvider.notifier).remove(widget.edit!.id);
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: sh.danger, padding: EdgeInsets.zero),
                    child: Text(tr('삭제'), style: const TextStyle(fontSize: 13)),
                  ),
                // 항상 보이는 닫기(×) 버튼.
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: sh.inkSoft),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('닫기'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 제목 + 마이크 ──────────────────────────────────────
            Text(tr('할 일 (예: 내일 p1 빨래하기)'),
                style: AppType.labelMedium.copyWith(color: sh.inkSoft)),
            const SizedBox(height: Gap.xs),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 4),
              decoration: BoxDecoration(
                color: sh.card2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      autofocus: true,
                      style: AppType.bodyLarge.copyWith(color: sh.ink),
                      decoration: InputDecoration(
                        hintText: tr('내일 p1 빨래하기'),
                        hintStyle: TextStyle(color: sh.inkFaint),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  _MicButton(
                    listening: _listening,
                    sh: sh,
                    onStart: _startListen,
                    onStop: _stopListen,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                _listening
                    ? tr('듣고 있어요… 말한 뒤 손을 떼세요')
                    : tr('마이크를 꾹 누른 채로 말하고 떼면 입력돼요 (예: "내일 p1 빨래하기"). 첫 사용 시 권한 허용 필요'),
                style: AppType.bodySmall.copyWith(
                    color: _listening ? sh.accent : sh.inkFaint,
                    height: 1.3),
              ),
            ),
            if (parsed.content.isNotEmpty &&
                parsed.content != _textCtrl.text.trim())
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(trf('내용: {0}', [parsed.content]),
                    style: AppType.bodySmall.copyWith(color: sh.accent)),
              ),
            const SizedBox(height: 16),

            // ── 날짜 ──────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: sh.inkSoft),
                const SizedBox(width: 8),
                Text(tr('날짜'), style: AppType.bodyLarge.copyWith(color: sh.inkSoft)),
                const Spacer(),
                if (effDate != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _dateOverride = null;
                      _dateTouched = true;
                    }),
                    style: TextButton.styleFrom(
                        foregroundColor: sh.inkFaint, padding: EdgeInsets.zero),
                    child: Text(tr('지움'), style: const TextStyle(fontSize: 12)),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: effDate != null
                          ? sh.accent.withValues(alpha: 0.12)
                          : sh.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: effDate != null
                              ? sh.accent.withValues(alpha: 0.4)
                              : sh.ink.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      effDate ?? tr('날짜 없음'),
                      style: AppType.bodyLarge.copyWith(
                          color: effDate != null ? sh.accentInk : sh.inkFaint,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 우선순위 ──────────────────────────────────────────
            Text(tr('우선순위'), style: AppType.labelMedium.copyWith(color: sh.inkSoft)),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                for (final p in const [0, 1, 2, 3])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PrioChip(
                      priority: p,
                      selected: effPrio == p,
                      sh: sh,
                      onTap: () => setState(() {
                        _prioOverride = p;
                        _prioTouched = true;
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 저장/취소 ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: sh.inkSoft,
                        side: BorderSide(color: sh.ink.withValues(alpha: 0.12)),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: Text(tr('취소'),
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: sh.accent,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(isEdit ? tr('저장') : tr('추가'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 마이크 버튼 ────────────────────────────────────────────────────
class _MicButton extends StatelessWidget {
  final bool listening;
  final SurlapColors sh;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _MicButton(
      {required this.listening,
      required this.sh,
      required this.onStart,
      required this.onStop});

  @override
  Widget build(BuildContext context) {
    // 누르고 있는 동안 듣고, 떼면 멈춘다(push-to-talk).
    return Listener(
      onPointerDown: (_) => onStart(),
      onPointerUp: (_) => onStop(),
      onPointerCancel: (_) => onStop(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: listening ? sh.danger : sh.accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
          size: 20,
          color: listening ? Colors.white : sh.accent,
        ),
      ),
    );
  }
}

// ── 우선순위 칩 ────────────────────────────────────────────────────
class _PrioChip extends StatelessWidget {
  final int priority; // 0=없음
  final bool selected;
  final SurlapColors sh;
  final VoidCallback onTap;
  const _PrioChip(
      {required this.priority,
      required this.selected,
      required this.sh,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = todoPriorityColor(priority, sh);
    final label = priority == 0 ? tr('없음') : 'P$priority';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.16) : sh.card2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? c : sh.ink.withValues(alpha: 0.08),
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: AppType.labelMedium.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? c : sh.inkSoft)),
      ),
    );
  }
}
