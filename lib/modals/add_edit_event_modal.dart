import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/date_utils.dart' as du;
import '../core/utils/event_parser.dart';
import '../i18n/dates.dart' as i18nd;
import '../i18n/strings.dart';
import '../models/event_item.dart';
import '../models/calendar_theme.dart';
import '../providers/events_provider.dart';
import '../providers/themes_provider.dart';
import '../core/calendar/calendar_item.dart';
import '../core/calendar/calendar_repository.dart';
import '../core/calendar/period_times.dart';
import '../widgets/source_badge.dart';
import '../widgets/app_toast.dart';

/// 날짜·인덱스가 있으면 편집, 없으면 추가.
Future<void> showAddEditEventModal(
  BuildContext context, {
  required String dateKey,
  int? editIndex,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddEditEventModal(
      dateKey: dateKey,
      editIndex: editIndex,
    ),
  );
}

class AddEditEventModal extends ConsumerStatefulWidget {
  final String dateKey;
  final int? editIndex;

  const AddEditEventModal({
    super.key,
    required this.dateKey,
    this.editIndex,
  });

  @override
  ConsumerState<AddEditEventModal> createState() => _AddEditEventModalState();
}

class _AddEditEventModalState extends ConsumerState<AddEditEventModal> {
  // 자연어 토큰("내일", "오후 3시" 등) 감지 시 입력창 안에서 빨갛게 강조.
  final _TokenHighlightController _textCtrl = _TokenHighlightController();
  late String _dateKey;

  /// 편집 시작 시점의 날짜 — 저장 키이자 [widget.editIndex] 가 가리키는 배열.
  /// 사용자가 날짜를 바꿔도 원본을 찾으려면 이 값이 필요하다.
  late String _originalDateKey;
  String? _startTime;
  String? _endTime;
  final Set<String> _selectedThemes = {};
  ParsedEvent? _suggestion;
  String? _recurFreq; // null | 'W' | 'M' | 'Y'
  String? _recurUntil; // YYYY-MM-DD or null
  bool _conflictAcknowledged = false;
  // 사용자가 직접 날짜/시간을 만졌으면 true. _save() 자동 적용 시 덮어쓰지 않도록.
  bool _dateUserSet = false;
  bool _startUserSet = false;
  bool _endUserSet = false;

  bool get isEdit => widget.editIndex != null;

  /// 입력할 때마다 자연어를 해석해 날짜·시각에 **바로 반영**한다(스펙 §11).
  ///
  /// 예전에는 해석 결과를 칩으로 띄우고 사용자가 "적용"을 눌러야 반영됐다.
  /// 자연어가 부가 기능처럼 느껴졌다. 이제 해석은 기본이고, 아래 필드를 직접
  /// 만지면(_dateUserSet 등) 그 필드는 더 이상 덮어쓰지 않는다.
  void _onTitleChanged(String raw) {
    if (isEdit) {
      setState(() => _suggestion = null);
      return;
    }
    final p = parseEventInput(raw);
    setState(() {
      if (p.dateKey != null && !_dateUserSet) _dateKey = p.dateKey!;
      if (p.tm != null && !_startUserSet) _startTime = p.tm;
      if (p.te != null && !_endUserSet) _endTime = p.te;
      // 무엇을 알아들었는지 보여줄 게 있을 때만 요약을 남긴다.
      _suggestion = (p.dateKey != null || p.tm != null) ? p : null;
    });
  }

  @override
  void initState() {
    super.initState();
    _dateKey = widget.dateKey;
    _originalDateKey = widget.dateKey;
    if (isEdit) {
      final item = ref.read(eventsProvider)[_originalDateKey]?[widget.editIndex!];
      if (item != null) {
        _textCtrl.text = item.t;
        _startTime = item.tm;
        _endTime = item.te;
        _selectedThemes.addAll(item.themeIds);
        final rr = item.rr;
        if (rr != null) {
          final f = rr['f']?.toString();
          if (f == 'W' || f == 'M' || f == 'Y') _recurFreq = f;
          _recurUntil = rr['u'] as String?;
        }
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    // 구독 테마도 일정에 "적용"은 가능(읽기 전용은 테마 관리에서만 적용).
    final themes = ref.watch(themesProvider);

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
            // 그랩 핸들
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
            // 제목
            Row(
              children: [
                Text(
                  isEdit ? tr('일정 편집') : tr('일정 추가'),
                  style: AppType.title.copyWith(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: sh.ink),
                ),
                const Spacer(),
                if (isEdit)
                  TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(
                        foregroundColor: sh.danger,
                        padding: EdgeInsets.zero),
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

            // 일정 내용
            _FieldRow(
              label: tr('무엇을 계획하고 있나요?'),
              sh: sh,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _textCtrl,
                    autofocus: true,
                    style: AppType.body.copyWith(color: sh.ink),
                    decoration: InputDecoration(
                      hintText: tr('예: 내일 7시 수학학원'),
                      hintStyle: TextStyle(color: sh.inkFaint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _onTitleChanged,
                    onSubmitted: (_) => _save(),
                  ),
                  if (!isEdit && _suggestion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _UnderstoodSummary(
                        dateKey: _dateKey,
                        start: _startTime,
                        end: _endTime,
                        sh: sh,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 날짜
            _FieldRow(
              label: tr('날짜'),
              sh: sh,
              child: GestureDetector(
                onTap: _pickDate,
                child: Text(
                  _dateKey,
                  style: AppType.body
                      .copyWith(color: sh.accent, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 시간
            _FieldRow(
              label: tr('시간 (선택)'),
              sh: sh,
              child: Row(
                children: [
                  _TimeBtn(
                    value: _startTime,
                    hint: '--:--',
                    sh: sh,
                    onTap: () => _pickTime(isStart: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('~', style: TextStyle(color: sh.inkSoft)),
                  ),
                  _TimeBtn(
                    value: _endTime,
                    hint: '--:--',
                    sh: sh,
                    onTap: () => _pickTime(isStart: false),
                  ),
                  if (_startTime != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _startTime = null; _endTime = null;
                        _startUserSet = true; _endUserSet = true;
                      }),
                      style: TextButton.styleFrom(
                          foregroundColor: sh.inkSoft,
                          padding: const EdgeInsets.only(left: 8)),
                      child: Text(tr('지움'), style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 반복 — 없음/매주/매월/매년 + 종료일(선택)
            _FieldRow(
              label: tr('반복'),
              sh: sh,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _RecurChip(
                        label: tr('없음'),
                        selected: _recurFreq == null,
                        sh: sh,
                        onTap: () => setState(() {
                          _recurFreq = null;
                          _recurUntil = null;
                        }),
                      ),
                      _RecurChip(
                        label: tr('매주'),
                        selected: _recurFreq == 'W',
                        sh: sh,
                        onTap: () => setState(() => _recurFreq = 'W'),
                      ),
                      _RecurChip(
                        label: tr('매월'),
                        selected: _recurFreq == 'M',
                        sh: sh,
                        onTap: () => setState(() => _recurFreq = 'M'),
                      ),
                      _RecurChip(
                        label: tr('매년'),
                        selected: _recurFreq == 'Y',
                        sh: sh,
                        onTap: () => setState(() => _recurFreq = 'Y'),
                      ),
                    ],
                  ),
                  if (_recurFreq != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.event_busy_outlined,
                            size: 16, color: sh.inkSoft),
                        const SizedBox(width: 6),
                        Text(tr('종료일'),
                            style: AppType.label.copyWith(color: sh.inkSoft)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _pickUntilDate,
                          child: Text(
                            _recurUntil ?? tr('무기한'),
                            style: AppType.body.copyWith(
                                color: _recurUntil != null
                                    ? sh.accent
                                    : sh.inkFaint,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_recurUntil != null)
                          TextButton(
                            onPressed: () =>
                                setState(() => _recurUntil = null),
                            style: TextButton.styleFrom(
                                foregroundColor: sh.inkSoft,
                                padding: const EdgeInsets.only(left: 8)),
                            child: Text(tr('지움'),
                                style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 캘린더(카테고리) 선택
            if (themes.isNotEmpty) ...[
              Text(tr('캘린더 (여러 개 선택 가능)'),
                  style: AppType.label.copyWith(color: sh.inkSoft)),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: themes.map((t) {
                  final on = _selectedThemes.contains(t.id);
                  return _ThemeChip(
                    theme: t,
                    selected: on,
                    onTap: () => setState(() {
                      if (on) {
                        _selectedThemes.remove(t.id);
                      } else {
                        _selectedThemes.add(t.id);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 저장/취소
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

  Future<void> _pickDate() async {
    final initial = du.fromDateKey(_dateKey);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: context.sh.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _dateKey = du.toDateKey(picked); _dateUserSet = true; });
  }

  Future<void> _pickUntilDate() async {
    final initial =
        _recurUntil != null ? du.fromDateKey(_recurUntil!) : du.fromDateKey(_dateKey);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: du.fromDateKey(_dateKey),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: context.sh.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _recurUntil = du.toDateKey(picked));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final cur = isStart ? _startTime : _endTime;
    TimeOfDay initial = TimeOfDay.now();
    if (cur != null) {
      final parts = cur.split(':');
      initial = TimeOfDay(
          hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: context.sh.accent),
        ),
        child: child!,
      ),
    );
    if (picked == null) { return; }
    final fmt =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) { _startTime = fmt; _startUserSet = true; }
      else { _endTime = fmt; _endUserSet = true; }
    });
  }

  void _save() async {
    var text = _textCtrl.text.trim();
    if (text.isEmpty) {
      AppToast.error(context, tr('제목을 입력해주세요'));
      return;
    }
    // 신규 추가 시: 본문에 "내일 5시" 같은 자연어 토큰이 남아 있고 사용자가
    // 날짜/시간을 직접 만지지 않았다면 그대로 적용. 직접 만진 값은 덮어쓰지 않음.
    if (!isEdit) {
      final p = parseEventInput(text);
      if (p.dateKey != null && !_dateUserSet) _dateKey = p.dateKey!;
      if (p.tm != null && !_startUserSet) _startTime = p.tm;
      if (p.te != null && !_endUserSet) _endTime = p.te;
      if (p.title.isNotEmpty) text = p.title;
    }

    // 충돌 감지 — 시작/종료 시각 둘 다 있을 때 + 미확정 상태일 때만 1회.
    if (!_conflictAcknowledged && _startTime != null && _endTime != null) {
      final conflicts = _findConflicts();
      if (conflicts.isNotEmpty) {
        final proceed = await _confirmConflict(conflicts);
        if (proceed != true) return;
        _conflictAcknowledged = true;
      }
    }

    final eventsNotifier = ref.read(eventsProvider.notifier);
    final ids = _selectedThemes.toList();
    final thVal = ids.isEmpty
        ? null
        : ids.length == 1
            ? ids.first
            : ids;

    final rrMap = _recurFreq == null
        ? null
        : <String, dynamic>{
            'f': _recurFreq,
            if (_recurUntil != null) 'u': _recurUntil,
          };

    if (isEdit) {
      final old =
          ref.read(eventsProvider)[_originalDateKey]?[widget.editIndex!];
      final updated = (old ?? EventItem(t: text)).copyWith(
        t: text,
        tm: _startTime,
        te: _endTime,
        th: thVal,
        rr: rrMap,
      );
      // 날짜가 바뀌었으면 옛 날짜에서 빼고 새 날짜에 넣는 것을 한 번에 처리한다.
      await eventsNotifier.moveEvent(
          _originalDateKey, widget.editIndex!, _dateKey, updated);
    } else {
      final item = EventItem(
        id: const Uuid().v4(),
        t: text,
        tm: _startTime,
        te: _endTime,
        th: thVal,
        rr: rrMap,
      );
      eventsNotifier.addEvent(_dateKey, item);
    }

    if (!mounted) return;
    AppToast.success(context, isEdit ? tr('일정을 수정했어요') : tr('일정을 추가했어요'));
    Navigator.pop(context);
  }

  /// 같은 날짜에서 시간이 겹치는 항목(자신 제외).
  ///
  /// 예전에는 내 로컬 일정만 봤다. 이제 통합 계층을 거쳐 학교 시간표·학사일정·
  /// 공유 캘린더까지 함께 본다(스포츠·생일·공휴일은 정보성이라 제외).
  List<CalendarItem> _findConflicts() {
    final startMin = hhmmToMinutes(_startTime);
    final endMin = hhmmToMinutes(_endTime);
    if (startMin == null || endMin == null || endMin <= startMin) return const [];

    final candidate = candidateFromEvent(
      EventItem(t: _textCtrl.text, tm: _startTime, te: _endTime),
      _dateKey,
    );
    final ignoreId = isEdit && _originalDateKey == _dateKey
        ? 'local:$_dateKey#${widget.editIndex}'
        : null;
    return conflictsFor(ref, candidate, ignoreId: ignoreId);
  }

  Future<bool?> _confirmConflict(List<CalendarItem> conflicts) {
    final sh = context.sh;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sh.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('시간 겹침'),
            style: AppType.cardTitle.copyWith(color: sh.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('이 시간 같은 날 일정과 겹쳐요:'),
                style: AppType.body.copyWith(color: sh.inkSoft)),
            const SizedBox(height: 8),
            ...conflicts.take(4).map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '• ${c.startHhmm}${c.endHhmm != null ? "~${c.endHhmm}" : ""}  ${c.title}',
                          style: AppType.body.copyWith(color: sh.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SourceBadge(source: c.source, color: c.color),
                    ],
                  ),
                )),
            if (conflicts.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(trf('외 {0}개', [conflicts.length - 4]),
                    style: AppType.caption.copyWith(color: sh.inkFaint)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: sh.accent),
            child: Text(tr('그래도 저장')),
          ),
        ],
      ),
    );
  }

  void _delete() {
    if (!isEdit) return;
    ref
        .read(eventsProvider.notifier)
        .deleteEvent(_originalDateKey, widget.editIndex!);
    Navigator.pop(context);
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;
  final SurlapColors sh;
  const _FieldRow({required this.label, required this.child, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label.copyWith(color: sh.inkSoft)),
        const SizedBox(height: Gap.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
          decoration: BoxDecoration(
            color: sh.card2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _TimeBtn extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final SurlapColors sh;
  const _TimeBtn(
      {required this.value, required this.hint,
       required this.onTap, required this.sh});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        decoration: BoxDecoration(
          color: value != null
              ? sh.accent.withValues(alpha: 0.12)
              : sh.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value != null
                  ? sh.accent.withValues(alpha: 0.5)
                  : sh.ink.withValues(alpha: 0.10)),
        ),
        child: Text(
          value ?? hint,
          style: AppType.body.copyWith(
              color: value != null ? sh.accentInk : sh.inkFaint,
              fontWeight: value != null ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final CalendarTheme theme;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeChip(
      {required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = theme.colorValue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle)),
            const SizedBox(width: Gap.xs),
            Text(tr(theme.name),
                style: AppType.caption.copyWith(
                    color: selected ? color : color.withValues(alpha: 0.8),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _RecurChip extends StatelessWidget {
  final String label;
  final bool selected;
  final SurlapColors sh;
  final VoidCallback onTap;
  const _RecurChip({
    required this.label,
    required this.selected,
    required this.sh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? sh.accent.withValues(alpha: 0.15)
              : sh.ink.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? sh.accent : Colors.transparent),
        ),
        child: Text(label,
            style: AppType.label.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? sh.accentInk : sh.inkSoft)),
      ),
    );
  }
}

/// "이해한 내용" — 자연어에서 알아들은 날짜·시각을 그대로 보여준다.
///
/// 예전에는 "이렇게 해석했어요, 적용하시겠어요?" 칩이었다. 이제 해석은 이미
/// 반영돼 있고 이 블록은 확인용이다. 틀렸으면 아래 날짜·시간 필드를 직접
/// 고치면 되고, 그 순간부터 자연어 해석이 그 필드를 덮어쓰지 않는다.
class _UnderstoodSummary extends StatelessWidget {
  final String dateKey;
  final String? start;
  final String? end;
  final SurlapColors sh;

  const _UnderstoodSummary({
    required this.dateKey,
    required this.start,
    required this.end,
    required this.sh,
  });

  @override
  Widget build(BuildContext context) {
    final date = du.fromDateKey(dateKey);
    final parts = <String>[
      '📅 ${i18nd.monthDay(date)}',
      if (start != null) '🕒 ${end == null ? start! : '$start~$end'}',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: sh.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sh.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: sh.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${tr('이해한 내용')} · ${parts.join('  ')}',
              style: AppType.caption.copyWith(
                  color: sh.accentInk, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 자연어 토큰("내일", "오후 3시", "월요일", "9시-10시" 등)이 입력 안에 있으면
/// 그 부분만 빨간색으로 칠해 사용자가 "감지됐다"는 걸 바로 알 수 있게 한다.
class _TokenHighlightController extends TextEditingController {
  static final RegExp _tokenRe = RegExp(
    // 상대 날짜
    r'(오늘|내일|낼|모레|글피|다음주|담주|이번주)'
    // 요일
    r'|([월화수목금토일])요일?'
    // M월 D일 / M/D
    r'|(\d{1,2}\s*월\s*\d{1,2}\s*일?)'
    r'|(\d{1,2}/\d{1,2})'
    // 시각/시간 범위 — "오후 3시", "3시 30분", "3:30", "9시-10시"
    r'|((?:오전|오후|아침|점심|저녁|밤)\s*)?\d{1,2}(?:시\s*\d{0,2}\s*(?:반|분)?|:\d{2})(?:\s*[-~]\s*(?:(?:오전|오후|아침|점심|저녁|밤)\s*)?\d{1,2}(?:시\s*\d{0,2}\s*(?:반|분)?|:\d{2}))?',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: text);
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    final highlight = (style ?? const TextStyle()).copyWith(
      color: const Color(0xFFE53935),
      fontWeight: FontWeight.w800,
    );
    for (final m in _tokenRe.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start), style: style));
      }
      spans.add(TextSpan(text: text.substring(m.start, m.end), style: highlight));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }
    return TextSpan(style: style, children: spans);
  }
}
