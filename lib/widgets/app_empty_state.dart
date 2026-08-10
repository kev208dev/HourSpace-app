import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';

/// 마스코트 없이 안내와 다음 행동에 집중하는 공통 빈 상태.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionText;
  final VoidCallback? onAction;
  final double iconSize;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionText,
    this.onAction,
    this.iconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Semantics(
      container: true,
      label: [title, ?message].join('. '),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.xl,
            vertical: Gap.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sh.accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: iconSize, color: sh.accent),
              ),
              const SizedBox(height: Gap.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppType.titleMedium.copyWith(
                  color: sh.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppType.bodyMedium.copyWith(color: sh.inkSoft),
                ),
              ],
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: Gap.lg),
                FilledButton.tonal(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, kMinTouch),
                  ),
                  child: Text(actionText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const AppNote({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: kMinTouch),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: sh.border, width: Borders.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: sh.accent),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              text,
              style: AppType.bodyMedium.copyWith(color: sh.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
