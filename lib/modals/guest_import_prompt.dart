import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../supabase/account_scope.dart';
import '../supabase/guest_migration.dart';

/// 로그인 직후 "게스트로 쓰던 데이터를 가져올까요?" (스펙 §26)
///
/// 예전에는 로그인하면 저장 스코프만 바뀌어서, 게스트로 만든 일정·할 일이
/// 지워지지는 않았지만 화면에서 통째로 사라졌다. 사용자 입장에서는 데이터가
/// 날아간 것과 같다. 이제 명시적으로 묻는다.
Future<void> maybeShowGuestImportPrompt(
    BuildContext context, WidgetRef ref) async {
  if (!GuestMigration.shouldAsk()) return;
  final summary = GuestMigration.summarize();
  if (summary.isEmpty) return;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _GuestImportDialog(summary: summary),
  );
  if (!context.mounted) return;

  if (result == true) {
    final copied = await GuestMigration.importToCurrentAccount();
    AccountScope.invalidateAccountProviders(ref.invalidate);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(trf('기존 데이터를 가져왔어요 ({0}개 항목)', [copied]))),
    );
  } else {
    // "새로 시작"을 골라도 게스트 원본은 지우지 않는다 — 로그아웃하면 그대로 있다.
    await GuestMigration.markAsked();
  }
}

class _GuestImportDialog extends StatelessWidget {
  final GuestDataSummary summary;
  const _GuestImportDialog({required this.summary});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return AlertDialog(
      backgroundColor: sh.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card)),
      title: Text(
        trf('기존 데이터 {0}개를 계정으로 가져올까요?', [summary.itemCount]),
        style: AppType.titleMedium.copyWith(color: sh.ink),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.events > 0) _line(sh, tr('일정'), summary.events),
          if (summary.todos > 0) _line(sh, tr('할 일'), summary.todos),
          if (summary.birthdays > 0) _line(sh, tr('생일'), summary.birthdays),
          if (summary.otherKeys > 0)
            _line(sh, tr('캘린더·시간표·기록 설정'), summary.otherKeys),
          const SizedBox(height: Gap.md),
          Text(
            tr('가져오지 않아도 로그아웃하면 다시 볼 수 있어요.'),
            style: AppType.bodySmall.copyWith(color: sh.inkFaint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('새로 시작')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr('가져오기')),
        ),
      ],
    );
  }

  Widget _line(SurlapColors sh, String label, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppType.bodyLarge.copyWith(color: sh.inkSoft)),
            ),
            Text('$count',
                style: AppType.number.copyWith(color: sh.ink)),
          ],
        ),
      );
}
