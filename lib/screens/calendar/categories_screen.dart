import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/calendar/calendar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../models/calendar_theme.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/birthdays_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/holidays_provider.dart';
import '../../providers/sports_provider.dart';
import '../../providers/themes_provider.dart';
import '../../supabase/theme_share_service.dart';
import '../../widgets/app_toast.dart';

/// 캘린더 카테고리 (핸드오프 C6 · spec §10).
///
/// 네 묶음으로 나눈다: 내 카테고리 · 내가 공유 중 · 구독 중 · 생성된 항목.
/// 눈 아이콘으로 켜고 끄며, 숨김은 통합 계층을 통해 **모든 화면에 동일하게**
/// 반영된다(목업 시점에는 월 보기에만 적용됐다).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final themes = ref.watch(themesProvider);
    final local = themes
        .where((t) => t.shareCode == null && !isSystemCalendarTheme(t.id))
        .toList();
    final owned = themes
        .where((t) => t.shareCode != null && t.shareRole == 'owner')
        .toList();
    final subscribed = themes
        .where((t) => t.shareCode != null && t.shareRole == 'subscriber')
        .toList();
    final sports = ref.watch(sportsSubscriptionsProvider);
    final hasAcademic = ref.watch(academicScheduleProvider).isNotEmpty;
    final hasBirthday = ref.watch(birthdaysProvider).isNotEmpty;

    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        backgroundColor: sh.bg,
        elevation: 0,
        title: Text(tr('캘린더 카테고리'),
            style: AppType.title.copyWith(color: sh.ink)),
        actions: [
          IconButton(
            tooltip: tr('카테고리 추가'),
            icon: Icon(Icons.add_rounded, color: sh.ink),
            onPressed: () => _addCategory(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
        children: [
          _GroupLabel(tr('내 카테고리')),
          if (local.isEmpty)
            _Empty(tr('아직 만든 카테고리가 없습니다.'))
          else
            for (final t in local)
              _CategoryRow(
                theme: t,
                editable: true,
                onEdit: () => _renameCategory(context, ref, t),
                onDelete: () => _deleteCategory(context, ref, t),
              ),
          const _NoneFilterRow(),
          if (owned.isNotEmpty) ...[
            _GroupLabel(tr('내가 공유 중 · 계정 필요')),
            for (final t in owned)
              _CategoryRow(theme: t, badge: tr('소유'), sub: _codeLabel(t)),
          ],
          if (subscribed.isNotEmpty) ...[
            _GroupLabel(tr('구독 중 · 읽기 전용')),
            for (final t in subscribed)
              _CategoryRow(theme: t, sub: tr('읽기 전용')),
          ],
          _GroupLabel(tr('생성된 항목')),
          _GeneratedRow(
            id: timetableCalendarId,
            name: tr('시간표'),
            color: sh.accent,
          ),
          if (hasAcademic)
            _GeneratedRow(
              id: academicThemeId,
              name: tr('학사일정'),
              color: sh.academicColor,
            ),
          if (hasBirthday)
            _GeneratedRow(
              id: birthdayThemeId,
              name: tr('생일'),
              color: sh.birthdayColor,
            ),
          _GeneratedRow(
            id: holidayThemeId,
            name: tr('공휴일'),
            color: sh.accent2,
          ),
          for (final s in sports)
            _GeneratedRow(
              id: s.id,
              name: '${s.emoji} ${s.teamName.isEmpty ? s.leagueName : s.teamName}',
              color: Color(s.color),
            ),
        ],
      ),
    );
  }

  static String _codeLabel(CalendarTheme t) =>
      t.shareCode == null ? '' : trf('코드 {0}', [t.shareCode!]);

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, tr('새 카테고리'), '');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(themesProvider.notifier).add(CalendarTheme(
          id: 'th_${const Uuid().v4().replaceAll('-', '').substring(0, 8)}',
          name: name.trim(),
          color: '#1B4DFF',
        ));
  }

  Future<void> _renameCategory(
      BuildContext context, WidgetRef ref, CalendarTheme t) async {
    final name = await _promptName(context, tr('이름 바꾸기'), t.name);
    if (name == null || name.trim().isEmpty) return;
    await ref.read(themesProvider.notifier).update(t.copyWith(name: name.trim()));
  }

  Future<void> _deleteCategory(
      BuildContext context, WidgetRef ref, CalendarTheme t) async {
    final sh = context.sh;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sh.card,
        title: Text(trf('"{0}" 삭제', [t.name]),
            style: AppType.number.copyWith(color: sh.ink)),
        content: Text(tr('이 카테고리를 붙여 둔 일정은 지워지지 않고 카테고리만 떨어집니다.'),
            style: AppType.body.copyWith(color: sh.inkBody)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('취소'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: sh.danger),
            child: Text(tr('삭제')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // 공유 중이면 서버 공유 행까지 함께 내린다 — 로컬만 지우면 구독자에게 계속 보인다.
    final code = t.shareCode;
    if (code != null && t.shareRole == 'owner') {
      final removed = await ThemeShareService.deleteShare(code);
      if (!removed && context.mounted) {
        AppToast.error(context, tr('공유를 내리지 못했어요. 네트워크를 확인해 주세요'));
        return;
      }
    }
    await ref.read(themesProvider.notifier).delete(t.id);
  }

  Future<String?> _promptName(
      BuildContext context, String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    final sh = context.sh;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sh.card,
        title: Text(title, style: AppType.number.copyWith(color: sh.ink)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppType.body.copyWith(color: sh.ink),
          decoration: InputDecoration(hintText: tr('카테고리 이름')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('취소'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(tr('저장')),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm),
        child: Text(text,
            style: AppType.label
                .copyWith(color: context.sh.ink.withValues(alpha: 0.45))),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Text(text,
            style: AppType.body
                .copyWith(color: context.sh.ink.withValues(alpha: 0.42))),
      );
}

/// 카테고리 한 줄 — 12px 스와치 · 이름 · (편집/삭제) · 눈 토글.
class _CategoryRow extends ConsumerWidget {
  final CalendarTheme theme;
  final bool editable;
  final String? badge;
  final String? sub;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryRow({
    required this.theme,
    this.editable = false,
    this.badge,
    this.sub,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final hidden = ref.watch(filterProvider).contains(theme.id);

    return Opacity(
      opacity: hidden ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorValue,
                borderRadius: BorderRadius.circular(Radii.swatch),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(theme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.button.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: sh.ink)),
                  if (sub != null && sub!.isNotEmpty)
                    Text(sub!,
                        style: AppType.label.copyWith(
                            fontWeight: FontWeight.w400,
                            color: sh.ink.withValues(alpha: 0.45))),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: sh.accentBg,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(badge!,
                    style: AppType.micro.copyWith(color: sh.accentInk)),
              ),
              const SizedBox(width: 8),
            ],
            if (editable) ...[
              _MiniIcon(
                  icon: Icons.edit_outlined, onTap: onEdit, sh: sh),
              _MiniIcon(
                  icon: Icons.delete_outline_rounded, onTap: onDelete, sh: sh),
            ],
            _EyeToggle(id: theme.id, hidden: hidden),
          ],
        ),
      ),
    );
  }
}

/// 생성된 항목(시간표·학사·생일·공휴일·스포츠) — 켜고 끄기만 된다.
class _GeneratedRow extends ConsumerWidget {
  final String id;
  final String name;
  final Color color;
  const _GeneratedRow(
      {required this.id, required this.name, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final hidden = ref.watch(filterProvider).contains(id);
    return Opacity(
      opacity: hidden ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(Radii.swatch),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.button.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: sh.ink)),
            ),
            Text(tr('자동 생성'),
                style: AppType.caption
                    .copyWith(color: sh.ink.withValues(alpha: 0.42))),
            _EyeToggle(id: id, hidden: hidden),
          ],
        ),
      ),
    );
  }
}

/// 카테고리 없는 일정을 숨기는 전용 필터.
class _NoneFilterRow extends ConsumerWidget {
  const _NoneFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    const id = '__none__';
    final hidden = ref.watch(filterProvider).contains(id);
    return Opacity(
      opacity: hidden ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                border: Border.all(
                    color: sh.ink.withValues(alpha: 0.45),
                    style: BorderStyle.solid),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr('카테고리 없음'),
                  style: AppType.button.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: sh.ink.withValues(alpha: 0.62))),
            ),
            Text(tr('숨김 전용 필터'),
                style: AppType.caption.copyWith(color: sh.accent)),
            _EyeToggle(id: id, hidden: hidden),
          ],
        ),
      ),
    );
  }
}

class _EyeToggle extends ConsumerWidget {
  final String id;
  final bool hidden;
  const _EyeToggle({required this.id, required this.hidden});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        tooltip: tr(hidden ? '보이기' : '숨기기'),
        onPressed: () => ref.read(filterProvider.notifier).toggle(id),
        icon: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 17,
            color: context.sh.accent),
      );
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final SurlapColors sh;
  const _MiniIcon({required this.icon, required this.onTap, required this.sh});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: sh.ink.withValues(alpha: 0.45)),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: EdgeInsets.zero,
      );
}
