import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../models/day_template.dart';
import '../providers/day_widget_provider.dart';
import '../widgets/ui_kit.dart';
import '../widgets/app_toast.dart';

Future<void> showDayTemplateManagerModal(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const DayTemplateManagerModal(),
    );

// 추천 프리셋 (원본 PRESET_DAY_TEMPLATES)
const _presets = [
  (name: '수험생 데일리', fields: [
    (type: 'number', label: '순공시간', unit: '시간', options: <String>[]),
    (type: 'number', label: '푼 문항수', unit: '문항', options: <String>[]),
    (type: 'check',  label: '오늘 공부', unit: '', options: ['국어','수학','영어','탐구']),
    (type: 'rating', label: '컨디션', unit: '', options: <String>[]),
  ]),
  (name: '심플 기록', fields: [
    (type: 'number', label: '순공시간', unit: '시간', options: <String>[]),
    (type: 'line',   label: '한줄일기', unit: '', options: <String>[]),
  ]),
  (name: '공부 + 회고', fields: [
    (type: 'number', label: '순공시간', unit: '시간', options: <String>[]),
    (type: 'number', label: '푼 문항수', unit: '문항', options: <String>[]),
    (type: 'memo',   label: '잘한 점', unit: '', options: <String>[]),
    (type: 'memo',   label: '내일 목표', unit: '', options: <String>[]),
  ]),
  (name: '습관 트래커', fields: [
    (type: 'check',  label: '오늘 습관', unit: '', options: ['운동','독서','일찍 자기','물 2L']),
    (type: 'rating', label: '기분', unit: '', options: <String>[]),
    (type: 'line',   label: '메모', unit: '', options: <String>[]),
  ]),
  (name: '건강 루틴', fields: [
    (type: 'timerange', label: '수면', unit: '', options: <String>[]),
    (type: 'counter',   label: '물', unit: '잔', options: <String>[]),
    (type: 'check',     label: '오늘 챙김', unit: '', options: ['운동','영양제','스트레칭']),
    (type: 'slider',    label: '컨디션', unit: '', options: <String>[]),
  ]),
  (name: '인강 트래커', fields: [
    (type: 'line',     label: '강의명', unit: '', options: <String>[]),
    (type: 'progress', label: '진도', unit: '%', options: <String>[]),
    (type: 'counter',  label: '들은 강의', unit: '개', options: <String>[]),
    (type: 'mood',     label: '이해도', unit: '', options: <String>[]),
  ]),
];

class DayTemplateManagerModal extends ConsumerWidget {
  const DayTemplateManagerModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final templates = ref.watch(dayTemplatesProvider);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        color: sh.card,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(children: [
                Text('일별 위젯 템플릿',
                    style: AppType.cardTitle.copyWith(fontWeight: FontWeight.w700, color: sh.ink)),
                const SizedBox(width: Gap.xs + 2),
                Text('날짜에 표시할 위젯을 만들고 적용 범위를 정하세요',
                    style: AppType.label.copyWith(color: sh.inkSoft)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Divider(color: sh.border, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 추천 시안
                  _PresetsSection(sh: sh, ref: ref),
                  Divider(color: sh.border, height: 24),
                  // 내 템플릿
                  if (templates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SurlapEmptyState(
  icon: Icons.dashboard_customize_rounded,
                        title: '아직 만든 위젯이 없어요',
                        description: '추천 시안에서 가져오거나 새로 만들어보세요',
                      ),
                    )
                  else
                    ...templates.asMap().entries.map((e) => _TemplateCard(
                          template: e.value,
                          index: e.key,
                          sh: sh,
                          ref: ref,
                          onEdit: () => _openEditor(context, ref, sh, e.key),
                        )),
                  const SizedBox(height: 12),
                  // "+ 새 템플릿" 버튼 — ListView 안에 1개만
                  FilledButton.icon(
                    onPressed: () => _openEditor(context, ref, sh, null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ 새 템플릿'),
                    style: FilledButton.styleFrom(
                      backgroundColor: sh.accent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.card)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, SurlapColors sh, int? index) {
    final existing = index != null ? ref.read(dayTemplatesProvider)[index] : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DayTemplateEditorPage(
          template: existing,
          onSave: (tpl) {
            if (existing != null) {
              ref.read(dayTemplatesProvider.notifier).update(tpl);
            } else {
              ref.read(dayTemplatesProvider.notifier).add(tpl);
            }
          },
          onDelete: existing != null
              ? () => ref.read(dayTemplatesProvider.notifier).delete(existing.id)
              : null,
        ),
      ),
    );
  }
}

class _PresetsSection extends StatefulWidget {
  final SurlapColors sh;
  final WidgetRef ref;
  const _PresetsSection({required this.sh, required this.ref});

  @override
  State<_PresetsSection> createState() => _PresetsSectionState();
}

class _PresetsSectionState extends State<_PresetsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final sh = widget.sh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('추천 시안', style: AppType.label.copyWith(fontWeight: FontWeight.w700,
              color: sh.inkSoft)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(foregroundColor: sh.accent, padding: EdgeInsets.zero),
            child: Text(_open ? '접기 ▴' : '펼치기 ▾', style: const TextStyle(fontSize: 12)),
          ),
        ]),
        if (_open)
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, childAspectRatio: 2.0,
            crossAxisSpacing: Gap.sm, mainAxisSpacing: Gap.sm,
            children: _presets.map((p) {
              return _PresetCard(preset: p, sh: sh, onAdd: () {
                _addPreset(p);
              });
            }).toList(),
          ),
      ],
    );
  }

  void _addPreset(({String name, List<({String type, String label, String unit, List<String> options})> fields}) p) {
    String uid() => 'f_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final tpl = DayTemplate(
      id: 'tpl_${const Uuid().v4().replaceAll('-', '').substring(0, 8)}',
      name: p.name,
      fields: p.fields.map((f) => DayField(
        id: uid(),
        type: DayFieldTypeExt.fromKey(f.type),
        label: f.label,
        unit: f.unit.isEmpty ? null : f.unit,
        options: f.options.isEmpty ? null : f.options,
      )).toList(),
      scope: const DayTemplateScope(mode: 'all'),
      enabled: true,
    );
    widget.ref.read(dayTemplatesProvider.notifier).add(tpl);
    AppToast.success(context, '"${p.name}" 위젯을 가져왔어요');
  }
}

class _PresetCard extends StatelessWidget {
  final ({String name, List<dynamic> fields}) preset;
  final SurlapColors sh;
  final VoidCallback onAdd;
  const _PresetCard({required this.preset, required this.sh, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sh.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(preset.name, style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: sh.ink)),
          const SizedBox(height: 2),
          Expanded(child: Text(
            preset.fields.map((f) => f.label).join(' · '),
            style: TextStyle(fontSize: 10, color: sh.inkSoft),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          )),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sh.accentBg, borderRadius: BorderRadius.circular(20)),
              child: Text('+ 가져오기',
                  style: TextStyle(fontSize: 10, color: sh.accentInk, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final DayTemplate template;
  final int index;
  final SurlapColors sh;
  final WidgetRef ref;
  final VoidCallback onEdit;
  const _TemplateCard({required this.template, required this.index,
      required this.sh, required this.ref, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: sh.border),
      ),
      child: Row(children: [
        // 활성화 토글
        Switch(
          value: template.enabled,
          onChanged: (v) => ref.read(dayTemplatesProvider.notifier)
              .update(DayTemplate(
                id: template.id, name: template.name,
                fields: template.fields, scope: template.scope, enabled: v)),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(template.name, style: AppType.body.copyWith(
                fontWeight: FontWeight.w600, color: sh.ink)),
            Text(
              template.fields.map((f) => f.label).join(' · '),
              style: AppType.label.copyWith(color: sh.inkSoft),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            Text(_scopeLabel(template.scope),
                style: TextStyle(fontSize: 10, color: sh.inkFaint)),
          ]),
        ),
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 18, color: sh.inkSoft),
          onPressed: onEdit,
        ),
      ]),
    );
  }

  String _scopeLabel(DayTemplateScope s) {
    switch (s.mode) {
      case 'all': return '전체 날짜';
      case 'weekdays': return '특정 요일';
      case 'range': return '${s.start} ~ ${s.end}';
      case 'days': return '특정 날짜 ${s.days?.length ?? 0}개';
      default: return '';
    }
  }
}

// 템플릿 편집 화면
class DayTemplateEditorPage extends StatefulWidget {
  final DayTemplate? template;
  final void Function(DayTemplate) onSave;
  final VoidCallback? onDelete;

  const DayTemplateEditorPage({
    super.key, this.template,
    required this.onSave, this.onDelete,
  });

  @override
  State<DayTemplateEditorPage> createState() => _DayTemplateEditorPageState();
}

class _DayTemplateEditorPageState extends State<DayTemplateEditorPage> {
  late TextEditingController _nameCtrl;
  late List<DayField> _fields;
  late DayTemplateScope _scope;

  static const _typeLabels = {
    DayFieldType.number: '숫자',   DayFieldType.line: '한줄',
    DayFieldType.memo: '메모',      DayFieldType.check: '체크',
    DayFieldType.rating: '평점',    DayFieldType.tags: '태그',
    DayFieldType.progress: '진행바', DayFieldType.counter: '카운터',
    DayFieldType.mood: '기분',      DayFieldType.slider: '슬라이더',
    DayFieldType.timerange: '시간구간',
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template?.name ?? '');
    _fields = List.from(widget.template?.fields ?? []);
    _scope = widget.template?.scope ?? const DayTemplateScope(mode: 'all');
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  void _addField(DayFieldType type) {
    setState(() {
      _fields.add(DayField(
        id: 'f_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
        type: type,
        label: _typeLabels[type] ?? '',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        title: Text(widget.template == null ? '템플릿 만들기' : '템플릿 편집',
            style: AppType.cardTitle.copyWith(color: sh.ink, fontWeight: FontWeight.w700)),
        actions: [
          if (widget.onDelete != null)
            TextButton(
              onPressed: () {
                widget.onDelete?.call();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: sh.danger),
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(foregroundColor: sh.accent),
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 이름
          _Card(sh: sh, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('이름', sh),
              TextField(controller: _nameCtrl,
                  decoration: InputDecoration(
                      hintText: '예: 학습 트래커',
                      hintStyle: TextStyle(color: sh.inkFaint),
                      border: InputBorder.none, isDense: true,
                      contentPadding: EdgeInsets.zero),
                  style: TextStyle(fontSize: 15, color: sh.ink)),
            ],
          )),
          const SizedBox(height: 12),
          // 표시 날짜 (적용 범위)
          _Card(sh: sh, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('표시 날짜', sh),
              const SizedBox(height: 8),
              _ScopeSelector(scope: _scope, sh: sh,
                  onChanged: (s) => setState(() => _scope = s)),
            ],
          )),
          const SizedBox(height: 12),
          // 위젯 필드
          _Card(sh: sh, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('위젯 필드', sh),
              const SizedBox(height: 8),
              if (_fields.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('아래 버튼으로 위젯을 추가하세요',
                      style: TextStyle(color: sh.inkFaint, fontSize: 13))),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: true,
                  itemCount: _fields.length,
                  onReorderItem: (old, nw) {
                    setState(() {
                      final item = _fields.removeAt(old);
                      _fields.insert(nw, item);
                    });
                  },
                  itemBuilder: (_, i) => _FieldEditor(
                    key: ValueKey(_fields[i].id),
                    field: _fields[i],
                    sh: sh,
                    typeLabel: _typeLabels[_fields[i].type] ?? '',
                    onChanged: (f) => setState(() => _fields[i] = f),
                    onDelete: () => setState(() => _fields.removeAt(i)),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: DayFieldType.values.map((t) => GestureDetector(
                  onTap: () => _addField(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sh.accentBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('+ ${_typeLabels[t]}',
                        style: TextStyle(fontSize: 11, color: sh.accentInk,
                            fontWeight: FontWeight.w600)),
                  ),
                )).toList(),
              ),
            ],
          )),
        ],
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { return; }
    final tpl = DayTemplate(
      id: widget.template?.id ??
          'tpl_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      name: name,
      fields: _fields,
      scope: _scope,
      enabled: widget.template?.enabled ?? true,
    );
    widget.onSave(tpl);
    Navigator.pop(context);
  }
}

class _ScopeSelector extends StatelessWidget {
  final DayTemplateScope scope;
  final SurlapColors sh;
  final ValueChanged<DayTemplateScope> onChanged;
  const _ScopeSelector({required this.scope, required this.sh, required this.onChanged});

  static const _modes = [
    ('all', '전체 날짜'),
    ('weekdays', '특정 요일'),
    ('range', '날짜 범위'),
    ('days', '특정 날짜'),
  ];
  static const _dowNames = ['일','월','화','수','목','금','토'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6, runSpacing: 6,
          children: _modes.map((m) {
            final sel = scope.mode == m.$1;
            return GestureDetector(
              onTap: () => onChanged(DayTemplateScope(mode: m.$1)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? sh.accentBg : sh.card2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? sh.accent : sh.border),
                ),
                child: Text(m.$2, style: TextStyle(fontSize: 12,
                    color: sel ? sh.accentInk : sh.ink,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
              ),
            );
          }).toList(),
        ),
        if (scope.mode == 'weekdays') ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: List.generate(7, (i) {
              final sel = scope.weekdays?.contains(i) ?? false;
              return GestureDetector(
                onTap: () {
                  final next = List<int>.from(scope.weekdays ?? []);
                  if (sel) { next.remove(i); } else { next.add(i); }
                  onChanged(DayTemplateScope(mode: 'weekdays', weekdays: next));
                },
                child: Container(
                  width: 36, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? sh.accentBg : sh.card2,
                    shape: BoxShape.circle,
                    border: Border.all(color: sel ? sh.accent : sh.border),
                  ),
                  child: Text(_dowNames[i], style: TextStyle(fontSize: 12,
                      color: sel ? sh.accentInk : sh.ink,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _FieldEditor extends StatefulWidget {
  final DayField field;
  final SurlapColors sh;
  final String typeLabel;
  final ValueChanged<DayField> onChanged;
  final VoidCallback onDelete;
  const _FieldEditor({super.key, required this.field, required this.sh,
      required this.typeLabel, required this.onChanged, required this.onDelete});
  @override State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late TextEditingController _labelCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _optCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.field.label);
    _unitCtrl  = TextEditingController(text: widget.field.unit ?? '');
    _optCtrl   = TextEditingController(text: (widget.field.options ?? []).join(', '));
  }
  @override void dispose() { _labelCtrl.dispose(); _unitCtrl.dispose(); _optCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sh = widget.sh;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: sh.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
            decoration: BoxDecoration(
              color: sh.accentBg, borderRadius: BorderRadius.circular(Radii.small)),
            child: Text(widget.typeLabel,
                style: TextStyle(fontSize: 10, color: sh.accentInk, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(child: TextField(
            controller: _labelCtrl,
            style: AppType.body.copyWith(color: sh.ink),
            decoration: InputDecoration(
                hintText: '라벨',
                hintStyle: TextStyle(color: sh.inkFaint),
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero),
            onChanged: (_) => _emit(),
          )),
          const SizedBox(width: 4),
          ReorderableDragStartListener(
            index: 0,
            child: Icon(Icons.drag_handle_rounded, color: sh.inkFaint, size: 18)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Icons.close_rounded, color: sh.danger, size: 18)),
        ]),
        // 타입별 옵션
        if (widget.field.type == DayFieldType.number ||
            widget.field.type == DayFieldType.progress ||
            widget.field.type == DayFieldType.counter ||
            widget.field.type == DayFieldType.slider) ...[
          const SizedBox(height: 6),
          Row(children: [
            Text('단위: ', style: TextStyle(fontSize: 11, color: sh.inkSoft)),
            SizedBox(width: 80, child: TextField(
              controller: _unitCtrl,
              style: TextStyle(fontSize: 12, color: sh.ink),
              decoration: InputDecoration(
                hintText: '시간, 개...',
                hintStyle: TextStyle(color: sh.inkFaint),
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero),
              onChanged: (_) => _emit(),
            )),
          ]),
        ],
        if (widget.field.type == DayFieldType.check) ...[
          const SizedBox(height: 6),
          Row(children: [
            Text('항목(쉼표 구분): ', style: TextStyle(fontSize: 11, color: sh.inkSoft)),
            Expanded(child: TextField(
              controller: _optCtrl,
              style: TextStyle(fontSize: 12, color: sh.ink),
              decoration: InputDecoration(
                hintText: '운동, 독서, ...',
                hintStyle: TextStyle(color: sh.inkFaint),
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero),
              onChanged: (_) => _emit(),
            )),
          ]),
        ],
      ]),
    );
  }

  void _emit() {
    final opts = _optCtrl.text.isNotEmpty
        ? _optCtrl.text.split(RegExp(r'\s*,\s*')).where((s) => s.isNotEmpty).toList()
        : null;
    widget.onChanged(DayField(
      id: widget.field.id,
      type: widget.field.type,
      label: _labelCtrl.text,
      design: widget.field.design,
      unit: _unitCtrl.text.isNotEmpty ? _unitCtrl.text : null,
      options: opts,
      max: widget.field.max,
      levels: widget.field.levels,
      target: widget.field.target,
      step: widget.field.step,
      sliderMin: widget.field.sliderMin,
      sliderMax: widget.field.sliderMax,
    ));
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final SurlapColors sh;
  const _Card({required this.child, required this.sh});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: sh.card,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: sh.border),
    ),
    child: child,
  );
}

class _Label extends StatelessWidget {
  final String text; final SurlapColors sh;
  const _Label(this.text, this.sh);
  @override Widget build(BuildContext context) => Text(text,
    style: AppType.label.copyWith(fontWeight: FontWeight.w700,
        color: sh.inkSoft));
}
