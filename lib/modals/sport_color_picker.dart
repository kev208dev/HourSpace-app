import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../sports/sports_catalog.dart';

/// 구독 표시 색 선택 시트. 선택한 ARGB 반환(취소 시 null).
Future<int?> showSportColorPicker(BuildContext context, int current) =>
    showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SportColorPicker(current: current),
    );

class _SportColorPicker extends StatelessWidget {
  final int current;
  const _SportColorPicker({required this.current});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
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
              Text('달력 표시 색',
                  style: AppType.titleMedium
                      .copyWith(fontWeight: FontWeight.w800, color: sh.ink)),
              const Spacer(),
              // 항상 보이는 닫기(×) 버튼.
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '닫기',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final c in kSportColors)
                GestureDetector(
                  onTap: () => Navigator.pop(context, c),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == current
                            ? sh.ink.withValues(alpha: 0.9)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: c == current
                        ? const Icon(Icons.check_rounded,
                            size: 22, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
