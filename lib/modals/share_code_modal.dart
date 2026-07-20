import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';

/// 테마 공유 — OS 공유창 대신 앱 자체 모달.
/// 공유 코드 + 링크를 각각 박스로 보여주고, 옆 버튼으로 클립보드에 직접 복사.
Future<void> showShareCodeModal(
        BuildContext context, String name, String code, String link) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareCodeModal(name: name, code: code, link: link),
    );

class _ShareCodeModal extends StatelessWidget {
  final String name;
  final String code;
  final String link;
  const _ShareCodeModal(
      {required this.name, required this.code, required this.link});

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
                Icon(Icons.ios_share_rounded, size: 20, color: sh.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(trf('"{0}" 공유', [name]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.titleMedium.copyWith(
                          fontWeight: FontWeight.w800, color: sh.ink)),
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
            const SizedBox(height: 4),
            Text(tr('코드나 링크를 복사해 친구에게 보내세요.'),
                style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
            const SizedBox(height: 18),

            _CopyField(label: tr('공유 코드'), value: code, mono: true, sh: sh),
            const SizedBox(height: 14),
            _CopyField(label: tr('링크'), value: link, mono: false, sh: sh),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _CopyField extends StatefulWidget {
  final String label;
  final String value;
  final bool mono;
  final SurlapColors sh;
  const _CopyField(
      {required this.label,
      required this.value,
      required this.mono,
      required this.sh});

  @override
  State<_CopyField> createState() => _CopyFieldState();
}

class _CopyFieldState extends State<_CopyField> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final sh = widget.sh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: AppType.labelMedium
                .copyWith(fontWeight: FontWeight.w700, color: sh.inkSoft)),
        const SizedBox(height: 6),
        Row(
          children: [
            // 읽기 전용 값 박스(코드는 모노스페이스).
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: sh.bg.withValues(alpha: sh.dark ? 0.5 : 1.0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sh.ink.withValues(alpha: 0.08)),
                ),
                child: SelectableText(
                  widget.value,
                  maxLines: 1,
                  style: TextStyle(
                    color: sh.ink,
                    fontSize: widget.mono ? 17 : 13.5,
                    fontWeight: widget.mono ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: widget.mono ? 2 : 0,
                    fontFamily: widget.mono ? 'monospace' : null,
                    fontFamilyFallback:
                        widget.mono ? const ['Courier', 'monospace'] : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 복사 버튼 — OS 공유창 없이 클립보드 직접 복사.
            GestureDetector(
              onTap: _copy,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _copied
                      ? sh.accent.withValues(alpha: 0.16)
                      : sh.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 17,
                      color: _copied ? sh.accent : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(_copied ? tr('복사됨') : tr('복사'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _copied ? sh.accent : Colors.white,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
