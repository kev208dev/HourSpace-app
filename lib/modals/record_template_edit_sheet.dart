import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../models/record_template.dart';
import '../providers/record_templates_provider.dart';
import '../widgets/record_glyph.dart';
import '../i18n/strings.dart';

/// 새 템플릿 만들기 / 커스텀 템플릿 편집.
/// [base] 가 있으면 그 값으로 시작(복제/편집), 없으면 빈 새 템플릿.
/// [editingId] 가 있으면 update, 없으면 add(새 id 생성).
Future<RecordTemplate?> showRecordTemplateEditSheet(
  BuildContext context, {
  RecordTemplate? base,
  String? editingId,
}) =>
    showModalBottomSheet<RecordTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(base: base, editingId: editingId),
    );

class _EditSheet extends ConsumerStatefulWidget {
  final RecordTemplate? base;
  final String? editingId;
  const _EditSheet({this.base, this.editingId});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late String _emoji;
  late final TextEditingController _name;
  late final TextEditingController _primaryLabel;
  late final TextEditingController _unit;
  late final TextEditingController _tagsLabel;
  late bool _hasTags;
  late bool _hasMemo;

  @override
  void initState() {
    super.initState();
    final b = widget.base;
    _emoji = b?.emoji ?? kRecordIconIds.first;
    _name = TextEditingController(text: b?.name ?? '');
    _primaryLabel = TextEditingController(text: b?.primaryLabel ?? '');
    _unit = TextEditingController(text: b?.primaryUnit ?? '');
    _tagsLabel = TextEditingController(text: b?.tagsLabel ?? '태그');
    _hasTags = b?.hasTags ?? false;
    _hasMemo = b?.hasMemo ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _primaryLabel.dispose();
    _unit.dispose();
    _tagsLabel.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _primaryLabel.text.trim().isNotEmpty;

  Future<void> _save() async {
    final notifier = ref.read(recordTemplatesProvider.notifier);
    final tpl = RecordTemplate(
      id: widget.editingId ?? 'rec-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      emoji: _emoji,
      primaryLabel: _primaryLabel.text.trim(),
      primaryUnit: _unit.text.trim(),
      hasTags: _hasTags,
      tagsLabel: _tagsLabel.text.trim().isEmpty ? '태그' : _tagsLabel.text.trim(),
      hasMemo: _hasMemo,
      isPreset: false,
    );
    if (widget.editingId != null) {
      await notifier.update(tpl);
    } else {
      await notifier.add(tpl);
    }
    if (mounted) Navigator.pop(context, tpl);
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
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
                  Text(widget.editingId != null ? tr('템플릿 편집') : tr('새 템플릿'),
                      style: AppType.titleMedium.copyWith(
                          fontWeight: FontWeight.w800, color: sh.ink)),
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
              const SizedBox(height: 16),

              _label(tr('아이콘'), sh),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final id in kRecordIconIds)
                    GestureDetector(
                      onTap: () => setState(() => _emoji = id),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _emoji == id
                              ? sh.accent.withValues(alpha: 0.16)
                              : sh.card2,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              width: _emoji == id ? 1.5 : 1,
                              color: _emoji == id
                                  ? sh.accent
                                  : sh.ink.withValues(alpha: 0.06)),
                        ),
                        child: Icon(kRecordIcons[id],
                            size: 23,
                            color: _emoji == id ? sh.accent : sh.inkSoft),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              _label(tr('이름'), sh),
              const SizedBox(height: 8),
              _field(_name, tr('예: 집중 독서'), sh, onChanged: (_) => setState(() {})),
              const SizedBox(height: 18),

              _label(tr('대표 숫자 항목'), sh),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field(_primaryLabel, tr('라벨 (예: 읽은 페이지)'), sh,
                        onChanged: (_) => setState(() {})),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(_unit, tr('단위 (예: p)'), sh),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 태그 on/off
              _ToggleRow(
                label: tr('태그 항목'),
                value: _hasTags,
                sh: sh,
                onChanged: (v) => setState(() => _hasTags = v),
              ),
              if (_hasTags)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: _field(_tagsLabel, tr('태그 라벨 (예: 책 제목)'), sh),
                ),
              // 메모 on/off
              _ToggleRow(
                label: tr('한 줄 메모'),
                value: _hasMemo,
                sh: sh,
                onChanged: (v) => setState(() => _hasMemo = v),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _valid ? sh.accent : sh.ink.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _valid ? _save : null,
                  child: Text(tr('저장'),
                      style: const TextStyle(
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

  Widget _field(TextEditingController c, String hint, SurlapColors sh,
      {ValueChanged<String>? onChanged}) {
    // 단일 컨테이너만 — 내부 Center/하위 박스 없이 평면화. 이중 가두리 인상 제거.
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: c,
        style: AppType.bodyLarge.copyWith(color: sh.ink),
        onChanged: onChanged,
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: TextStyle(color: sh.inkFaint),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final SurlapColors sh;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.label,
      required this.value,
      required this.sh,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppType.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600, color: sh.ink)),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: sh.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
