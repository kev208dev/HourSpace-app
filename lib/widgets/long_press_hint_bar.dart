import 'package:flutter/material.dart';
import '../core/constants/storage_keys.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../storage/local_store.dart';

/// 달력 첫 진입 시 1회 노출되는 "꾹 눌러서 추가" 힌트 바.
/// 사용자가 닫거나 한 번 보면 LocalStore 플래그로 다시 안 뜬다.
class LongPressHintBar extends StatefulWidget {
  const LongPressHintBar({super.key});

  @override
  State<LongPressHintBar> createState() => _LongPressHintBarState();
}

class _LongPressHintBarState extends State<LongPressHintBar> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    final seen =
        LocalStore.instance.getBool(StorageKeys.longPressHintSeen) ?? false;
    if (!seen) _show = true;
  }

  void _dismiss() {
    LocalStore.instance.setBool(StorageKeys.longPressHintSeen, true);
    setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final sh = context.sh;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 10, Gap.md, 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
          decoration: BoxDecoration(
            color: sh.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sh.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 18, color: sh.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('Tip · 날짜를 꾹 눌러 일정·할 일·위젯을 빠르게 추가하세요.'),
                  style: AppType.label.copyWith(
                    color: sh.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('닫기'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: _dismiss,
                icon: Icon(Icons.close_rounded, size: 16, color: sh.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
