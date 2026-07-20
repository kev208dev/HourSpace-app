import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../models/record_template.dart';
import '../providers/day_widget_provider.dart';
import '../providers/record_templates_provider.dart';
import '../widgets/record_glyph.dart';

/// 기록 입력 바텀시트 — 그 날의 기록 템플릿 값을 빠르게 입력/수정.
/// 저장은 widgetValuesProvider 에 즉시 write-through → 달력 셀 바로 반영.
Future<void> showRecordEntrySheet(
        BuildContext context, String templateId, String dateKey) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _RecordEntrySheet(templateId: templateId, dateKey: dateKey),
    );

class _RecordEntrySheet extends ConsumerStatefulWidget {
  final String templateId;
  final String dateKey;
  const _RecordEntrySheet({required this.templateId, required this.dateKey});

  @override
  ConsumerState<_RecordEntrySheet> createState() => _RecordEntrySheetState();
}

class _RecordEntrySheetState extends ConsumerState<_RecordEntrySheet> {
  late double _primary;
  late List<String> _tags;
  late final TextEditingController _primaryCtrl;
  late final TextEditingController _memoCtrl;
  final _tagCtrl = TextEditingController();

  RecordTemplate get _tpl =>
      ref.read(recordTemplatesByIdProvider)[widget.templateId] ?? kPresetStudy;

  // 시간(h)은 0.5 단위, 그 외(p·분 등)는 1 단위.
  double get _step => _tpl.primaryUnit == 'h' ? 0.5 : 1;

  @override
  void initState() {
    super.initState();
    final vals = ref.read(widgetValuesProvider)[widget.dateKey]
            ?[widget.templateId] ??
        const {};
    _primary = (vals[kRecPrimary] as num?)?.toDouble() ?? 0;
    _tags =
        (vals[kRecTags] as List?)?.map((e) => e.toString()).toList() ?? [];
    _primaryCtrl =
        TextEditingController(text: _primary > 0 ? fmtMetric(_primary) : '');
    _memoCtrl =
        TextEditingController(text: (vals[kRecMemo] ?? '').toString());
  }

  @override
  void dispose() {
    _primaryCtrl.dispose();
    _memoCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _write(String fieldId, dynamic value) {
    ref
        .read(widgetValuesProvider.notifier)
        .setValue(widget.dateKey, widget.templateId, fieldId, value);
  }

  void _setPrimary(double v) {
    v = v.clamp(0, 100000);
    setState(() {
      _primary = v;
      _primaryCtrl.text = v > 0 ? fmtMetric(v) : '';
    });
    _write(kRecPrimary, v > 0 ? v : null);
  }

  void _saveTags() => _write(kRecTags, _tags.isEmpty ? null : _tags);

  void _addTag(String s) {
    s = s.trim();
    if (s.isEmpty || _tags.contains(s)) return;
    setState(() => _tags.add(s));
    _tagCtrl.clear();
    _saveTags();
  }

  void _removeTag(String s) {
    setState(() => _tags.remove(s));
    _saveTags();
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final tpl = _tpl;
    final d = DateTime.parse(widget.dateKey);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sh.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
        child: SingleChildScrollView(
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
                  recordGlyph(tpl.emoji, size: 22, color: sh.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tpl.name,
                            style: AppType.titleMedium.copyWith(
                                fontWeight: FontWeight.w800, color: sh.ink)),
                        Text('${d.month}월 ${d.day}일 기록',
                            style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
                      ],
                    ),
                  ),
                  // 항상 보이는 닫기(×) 버튼.
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: '닫기',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 대표 숫자
              _label(tpl.primaryLabel, sh),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StepBtn(
                      icon: Icons.remove_rounded,
                      sh: sh,
                      onTap: () => _setPrimary(_primary - _step)),
                  Expanded(
                    child: Container(
                      height: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: sh.card2,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: sh.ink.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IntrinsicWidth(
                            child: TextField(
                              controller: _primaryCtrl,
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              style: AppType.titleLarge.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: sh.accent),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(
                                    color: sh.inkFaint,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800),
                              ),
                              onChanged: (v) {
                                if (v.trim().isEmpty) {
                                  _primary = 0;
                                  _write(kRecPrimary, null);
                                  return;
                                }
                                final parsed = double.tryParse(v);
                                if (parsed == null) return;
                                _primary = parsed.clamp(0, 100000);
                                _write(kRecPrimary,
                                    _primary > 0 ? _primary : null);
                              },
                            ),
                          ),
                          if (tpl.primaryUnit.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(tpl.primaryUnit,
                                style:
                                    AppType.bodyLarge.copyWith(color: sh.inkSoft)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _StepBtn(
                      icon: Icons.add_rounded,
                      sh: sh,
                      onTap: () => _setPrimary(_primary + _step)),
                ],
              ),

              // 태그(선택)
              if (tpl.hasTags) ...[
                const SizedBox(height: 22),
                _label(tpl.tagsLabel, sh),
                const SizedBox(height: 8),
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in _tags)
                        _Chip(label: s, sh: sh, onRemove: () => _removeTag(s)),
                    ],
                  ),
                if (_tags.isNotEmpty) const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: sh.card2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sh.ink.withValues(alpha: 0.06)),
                        ),
                        child: TextField(
                          controller: _tagCtrl,
                          style: AppType.bodyLarge.copyWith(color: sh.ink),
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: '${tpl.tagsLabel} 추가',
                            hintStyle: TextStyle(color: sh.inkFaint),
                          ),
                          onSubmitted: _addTag,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StepBtn(
                        icon: Icons.add_rounded,
                        sh: sh,
                        onTap: () => _addTag(_tagCtrl.text)),
                  ],
                ),
              ],

              // 메모(선택)
              if (tpl.hasMemo) ...[
                const SizedBox(height: 22),
                _label('메모 (선택)', sh),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: sh.card2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
                  ),
                  child: TextField(
                    controller: _memoCtrl,
                    style: AppType.bodyLarge.copyWith(color: sh.ink),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '한 줄 메모...',
                      hintStyle: TextStyle(color: sh.inkFaint),
                    ),
                    onChanged: (v) => _write(
                        kRecMemo, v.trim().isEmpty ? null : v.trim()),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: sh.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('저장',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t, SurlapColors sh) => Text(t,
      style: AppType.labelMedium
          .copyWith(fontWeight: FontWeight.w700, color: sh.inkSoft));
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final SurlapColors sh;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.sh, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: sh.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, size: 24, color: sh.accent),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final SurlapColors sh;
  final VoidCallback onRemove;
  const _Chip(
      {required this.label, required this.sh, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sh.accent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppType.labelMedium.copyWith(
                    fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 4),
            const Icon(Icons.close_rounded, size: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
