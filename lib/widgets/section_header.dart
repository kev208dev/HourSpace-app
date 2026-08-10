import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';

/// 섹션 제목 한 줄 — 제목 + (선택) 우측 수치 + (선택) 액션 링크.
///
/// 화면마다 조금씩 다른 제목 줄을 만들지 않기 위한 단일 컴포넌트.
class SectionHeader extends StatelessWidget {
  final String title;

  /// 제목 오른쪽에 붙는 짧은 수치(예: `2/5`).
  final String? trailing;

  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Row(
        children: [
          Text(
            title,
            style: AppType.cardTitle
                .copyWith(color: sh.ink, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          if (trailing != null)
            Text(trailing!,
                style: AppType.number.copyWith(color: sh.inkSoft)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: Gap.sm),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                minimumSize: const Size(0, kMinTouch),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: AppType.sub),
            ),
          ],
        ],
      ),
    );
  }
}
