import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/category_colors.dart';
import '../i18n/strings.dart';
import '../core/theme/design_tokens.dart';
import '../models/calendar_theme.dart';
import '../models/shared_theme_payload.dart';
import '../providers/themes_provider.dart';
import '../providers/events_provider.dart';
import '../supabase/auth_service.dart';
import '../supabase/theme_share_service.dart';
import '../widgets/mascot/mascot.dart';
import '../widgets/mascot/mascot_feedback.dart';
import 'share_code_modal.dart';
import '../providers/shared_theme_events_provider.dart';
import '../providers/filter_provider.dart';

Future<void> showThemeManagerModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ThemeManagerModal(),
  );
}

class ThemeManagerModal extends ConsumerWidget {
  const ThemeManagerModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: BoxDecoration(
          color: sh.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 그랩 핸들
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sh.ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('공유 캘린더'),
                            style: AppType.titleLarge.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: sh.ink)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: sh.inkSoft, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: sh.border, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
                child: const ThemeManagerBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 테마(카테고리) 관리 본문 — 모달/테마 탭 양쪽에서 인라인으로 재사용.
class ThemeManagerBody extends ConsumerWidget {
  const ThemeManagerBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final themes = ref.watch(themesProvider);

    final local =
        themes.where((t) => t.shareCode == null).toList();
    final owned = themes
        .where((t) => t.shareCode != null && t.shareRole == 'owner')
        .toList();
    final subbed = themes
        .where((t) => t.shareCode != null && t.shareRole == 'subscriber')
        .toList();

    final allEmpty = local.isEmpty && owned.isEmpty && subbed.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MascotEmptyState(
              expression: MascotExpression.neutral,
              title: tr('아직 만든 캘린더가 없어요'),
              message: tr('캘린더를 만들어 일정을 색으로 구분해요'),
              mascotSize: 92,
              showStars: false,
            ),
          ),
        if (local.isNotEmpty) ...[
          _GroupLabel(tr('내 카테고리'), sh),
          ...local.map((t) => _ThemeRow(
              key: ValueKey(t.id),
              theme: t, editable: true, ref: ref, sh: sh)),
        ],
        if (owned.isNotEmpty) ...[
          _GroupLabel(tr('공유 중 · 내가 공유'), sh),
          ...owned.map((t) => _ThemeRow(
              key: ValueKey(t.id),
              theme: t, editable: true, ref: ref, sh: sh,
              shareCode: t.shareCode)),
        ],
        if (subbed.isNotEmpty) ...[
          _GroupLabel(tr('구독 중'), sh),
          ...subbed.map((t) => _ThemeRow(
              key: ValueKey(t.id),
              theme: t, editable: false, ref: ref, sh: sh,
              shareCode: t.shareCode)),
        ],
        const SizedBox(height: 18),
        // ── primary: 새 캘린더 만들기(텍스트 CTA) + 가져오기(아이콘) ──
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _addTheme(ref),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(tr('새 공유일정 생성하기'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: sh.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 가져오기 — 아이콘 버튼.
            Tooltip(
              message: tr('공유 코드로 가져오기'),
              child: Semantics(
                button: true,
                label: tr('공유 코드로 가져오기'),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => _importTheme(context, ref, sh),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor:
                          sh.ink.withValues(alpha: sh.dark ? 0.04 : 0.02),
                      side:
                          BorderSide(color: sh.ink.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Icon(Icons.download_rounded,
                        size: 22, color: sh.inkSoft),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addTheme(WidgetRef ref) {
    final theme = CalendarTheme(
      id: 'th_${const Uuid().v4().replaceAll('-', '').substring(0, 8)}',
      name: '새 카테고리',
      color: '#5b9bd5',
    );
    ref.read(themesProvider.notifier).add(theme);
  }

  void _importTheme(BuildContext context, WidgetRef ref, SurlapColors sh) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sh.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('공유 코드 입력'), style: AppType.titleMedium.copyWith(color: sh.ink)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'XXXXXXXX',
            hintStyle: TextStyle(color: sh.inkFaint),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('취소'))),
          FilledButton(
            onPressed: () async {
              final code = ctrl.text.trim();
              Navigator.pop(ctx);
              if (code.isEmpty) return;
              try {
                final theme = await ThemeShareService.fetchByCode(code);
                if (theme == null) {
                  if (context.mounted) {
                    MascotToast.error(context, tr('해당 코드의 캘린더를 찾을 수 없어요'));
                  }
                  return;
                }
                // Subscribe: add with role='subscriber'
                final subTheme = theme.copyWith(shareRole: 'subscriber');
                ref.read(themesProvider.notifier).add(subTheme);
                if (context.mounted) {
                  MascotToast.success(context, trf('캘린더 "{0}" 가져왔어요', [theme.name]));
                }
              } catch (e) {
                if (context.mounted) {
                  MascotToast.error(context, tr('가져오기에 실패했어요'));
                }
              }
            },
            child: Text(tr('가져오기')),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  final SurlapColors sh;
  const _GroupLabel(this.text, this.sh);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, Gap.lg, 0, Gap.sm),
    child: Text(text,
        style: AppType.labelMedium.copyWith(
            fontWeight: FontWeight.w800, color: sh.inkSoft)),
  );
}


class _ThemeRow extends ConsumerStatefulWidget {
  final CalendarTheme theme;
  final bool editable;
  final WidgetRef ref;
  final SurlapColors sh;
  final String? shareCode;

  const _ThemeRow({
    super.key,
    required this.theme, required this.editable,
    required this.ref, required this.sh, this.shareCode,
  });

  @override
  ConsumerState<_ThemeRow> createState() => _ThemeRowState();
}

class _ThemeRowState extends ConsumerState<_ThemeRow> {
  late TextEditingController _nameCtrl;
  late Color _color;
  bool _editing = false;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.theme.name);
    _color = widget.theme.colorValue;
    // 편집 중 포커스 잃으면 저장 후 보기 모드로 복귀.
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) {
        _saveName(_nameCtrl.text);
        if (mounted) setState(() => _editing = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ThemeRow old) {
    super.didUpdateWidget(old);
    // 같은 행(ValueKey로 theme.id 고정)에서 테마 속성이 외부 변경되면 재동기화.
    if (old.theme.color != widget.theme.color) {
      _color = widget.theme.colorValue;
    }
    if (old.theme.name != widget.theme.name &&
        widget.theme.name != _nameCtrl.text) {
      _nameCtrl.text = widget.theme.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sh = widget.sh;
    final t = widget.theme;
    final subtitle = t.shareRole == 'owner'
        ? tr('내가 공유 중')
        : t.shareRole == 'subscriber'
            ? tr('구독 중 · 읽기 전용')
            : tr('공유 안 됨');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sh.ink.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _colorDot(sh),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(child: _nameField(sh)),
                      if (t.shareRole == 'subscriber')
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.lock_outline_rounded,
                              size: 16, color: sh.inkFaint),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 8, children: _actionChips(sh)),
          ),
        ],
      ),
    );
  }

  // 색상 원 — 큰 사이즈 + 글로우 + 흰 링으로 "탭 가능" 강조.
  Widget _colorDot(SurlapColors sh) {
    final dot = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _color.withValues(alpha: 0.40), blurRadius: 14),
        ],
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.22), width: 2),
      ),
    );
    if (!widget.editable) return dot;
    return GestureDetector(onTap: _pickColor, child: dot);
  }

  // 이름 — 평소엔 카드 제목 텍스트, 탭하면 편집 모드.
  Widget _nameField(SurlapColors sh) {
    final titleStyle = AppType.bodyLarge.copyWith(
        fontSize: 20, fontWeight: FontWeight.w800, color: sh.ink);
    if (_editing) {
      return TextField(
        controller: _nameCtrl,
        focusNode: _focus,
        autofocus: true,
        style: titleStyle,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: tr('캘린더 이름'),
          hintStyle: TextStyle(color: sh.inkFaint),
        ),
        onSubmitted: (v) {
          _saveName(v);
          setState(() => _editing = false);
        },
      );
    }
    final empty = widget.theme.name.trim().isEmpty;
    final title = Text(
      empty ? tr('캘린더 이름') : widget.theme.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: empty ? titleStyle.copyWith(color: sh.inkFaint) : titleStyle,
    );
    if (!widget.editable) return title;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _editing = true),
      child: title,
    );
  }

  // 상태별 액션 칩(라벨 + 약한 배경).
  List<Widget> _actionChips(SurlapColors sh) {
    final t = widget.theme;
    if (t.shareRole == 'subscriber') {
      return [
        _chip(Icons.refresh_rounded, tr('받기'), sh.inkSoft, _refreshSubscribed, sh),
        _chip(Icons.copy_rounded, tr('복제'), sh.accent, _duplicateToMine, sh),
        _chip(Icons.delete_outline_rounded, tr('구독 취소'), sh.danger, () => _delete(), sh),
      ];
    }
    final chips = <Widget>[];
    if (widget.shareCode != null) {
      chips.add(_chip(Icons.ios_share_rounded, tr('공유'), sh.accent,
          () => _shareLink(t.name, widget.shareCode!), sh));
    } else if (widget.editable) {
      chips.add(_chip(
          Icons.link_rounded, tr('공유'), sh.accent, () => _shareTheme(context), sh));
    }
    chips.add(_chip(Icons.delete_outline_rounded, tr('삭제'), sh.danger, () => _delete(), sh));
    return chips;
  }

  // 아이콘 버튼(라벨 없음). 접근성 위해 Tooltip + Semantics 유지.
  Widget _chip(IconData icon, String label, Color color, VoidCallback onTap,
      SurlapColors sh) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: sh.dark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  void _saveName(String name) {
    if (name.trim().isEmpty) { return; }
    final updated = widget.theme.copyWith(name: name.trim());
    ref.read(themesProvider.notifier).update(updated);
    _syncOwned(updated);
  }

  // owner가 소유 테마를 수정하면 클라우드 payload도 갱신(테마 + 일정).
  // 실제 업로드는 themeSharingProvider 가 themesProvider 변경을 듣고 디바운스 처리한다.
  void _syncOwned(CalendarTheme t) {
    if (t.shareCode != null && t.shareRole == 'owner') {
      final events = eventsForTheme(ref.read(eventsProvider), t.id);
      ThemeShareService.updateShare(t.shareCode!, t, events)
          .catchError((Object e) {
        debugPrint('[ThemeShare] 소유 테마 수정 동기화 실패: $e');
      });
    }
  }

  // 구독 테마의 최신 내용을 클라우드에서 다시 받아 반영(owner 수정 반영).
  Future<void> _refreshSubscribed() async {
    final code = widget.theme.shareCode;
    if (code == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final latest = await ThemeShareService.fetchByCode(code);
      if (latest == null) {
        messenger.showSnackBar(
            SnackBar(content: Text(tr('원본 캘린더를 찾을 수 없어요(삭제됨?)'))));
        return;
      }
      // id/역할/코드는 유지, 내용(이름·색·이미지)만 최신으로.
      ref.read(themesProvider.notifier).update(widget.theme.copyWith(
            name: latest.name,
            color: latest.color,
            image: latest.image,
          ));
      messenger.showSnackBar(
          SnackBar(content: Text(trf('"{0}" 최신 내용 반영됨', [latest.name]))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(trf('새로고침 실패: {0}', [e]))));
    }
  }

  // 구독 테마를 편집 가능한 내 로컬 테마로 복제.
  void _duplicateToMine() {
    final copy = CalendarTheme(
      id: 'th_${const Uuid().v4().replaceAll('-', '').substring(0, 8)}',
      name: '${widget.theme.name} (복사본)',
      color: widget.theme.color,
      image: widget.theme.image,
      // shareCode/shareRole 없음 → 내가 편집할 수 있는 로컬 테마
    );
    ref.read(themesProvider.notifier).add(copy);
    MascotToast.success(context, trf('"{0}" 내 캘린더로 복제했어요', [copy.name]));
  }

  void _pickColor() async {
    // 16색 카테고리 팔레트 — 다크/라이트 페어, 현재 brightness 변형 사용.
    final brightness = Theme.of(context).brightness;
    String hex(Color c) {
      final v = c.toARGB32() & 0xFFFFFF;
      return '#${v.toRadixString(16).padLeft(6, '0')}';
    }
    final palette = CategoryColors.palette;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final sh = context.sh;
        return AlertDialog(
          backgroundColor: sh.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr('색상 선택'), style: AppType.titleMedium.copyWith(color: sh.ink)),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 10, runSpacing: 10,
              children: palette.map((cc) {
                final c = cc.of(brightness);
                final selected = _color.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, hex(c)),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: sh.ink, width: 2.5)
                          : Border.all(color: c.withValues(alpha: 0.4), width: 1),
                      boxShadow: selected
                          ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (picked == null) { return; }
    setState(() => _color = Color(int.parse('FF${picked.replaceAll('#', '')}', radix: 16)));
    final updated = widget.theme.copyWith(color: picked);
    ref.read(themesProvider.notifier).update(updated);
    _syncOwned(updated);
  }

  Future<void> _delete() async {
    // 구독자/오너 둘 다 한 번 더 묻는다 — 실수 삭제로 동기화된 공유 데이터까지
    // 빠지는 사고 방지. 메시지는 역할에 맞춰 분기.
    final isSubscriber = widget.theme.shareRole == 'subscriber';
    final title = isSubscriber ? tr('구독 취소') : tr('삭제');
    final code = widget.theme.shareCode;
    final isSharedOwner = !isSubscriber && code != null && code.isNotEmpty;
    final msg = isSubscriber
        ? trf('"{0}" 공유달력 구독을 취소할까요?', [widget.theme.name])
        : isSharedOwner
            // 공유 중인 캘린더는 남에게도 영향을 준다 — 그 사실을 미리 알린다.
            ? trf('"{0}" 캘린더를 삭제할까요?\n공유가 내려가고 구독 중인 사람에게도 더 이상 보이지 않아요.',
                [widget.theme.name])
            : trf('"{0}" 캘린더를 삭제할까요?', [widget.theme.name]);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('취소')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.sh.danger),
            child: Text(title),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // 원격 정리를 먼저 한다 — 로컬만 지우면 서버 행과 캐시가 고아로 남는다.
    if (isSharedOwner) {
      final removed = await ThemeShareService.deleteShare(code);
      if (!removed && mounted) {
        // 서버에서 못 지웠으면 조용히 넘어가지 않는다 — 남에게는 계속 보인다.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('공유를 내리지 못했어요. 네트워크를 확인해 주세요'))),
        );
        return;
      }
    }
    if (isSubscriber) {
      // 구독 취소 — 받아 둔 일정 캐시도 함께 비운다.
      await ref
          .read(sharedThemeEventsProvider.notifier)
          .removeTheme(widget.theme.id);
    }
    ref.read(themesProvider.notifier).delete(widget.theme.id);
    // 이 캘린더의 필터 상태도 정리 — 지운 캘린더가 숨김 목록에 남지 않도록.
    final hidden = ref.read(filterProvider);
    if (hidden.contains(widget.theme.id)) {
      await ref.read(filterProvider.notifier).toggle(widget.theme.id);
    }
  }

  Future<void> _shareTheme(BuildContext context) async {
    // 로그인 안 된 경우: 예외 대신 친절한 안내.
    if (ref.read(authProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('로그인해야 이용할 수 있는 서비스입니다'))),
      );
      return;
    }
    try {
      final events = eventsForTheme(ref.read(eventsProvider), widget.theme.id);
      final code = await ThemeShareService.shareTheme(widget.theme, events);
      ref.read(themesProvider.notifier).update(
          widget.theme.copyWith(shareCode: code, shareRole: 'owner'));
      if (context.mounted) _shareLink(widget.theme.name, code);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('로그인해야 이용할 수 있는 서비스입니다'))),
        );
      }
    }
  }

  // 카톡/인스타 등 OS 공유 시트 — 메세지 + 링크(공유코드 포함).
  // 길게 누름 등 별도 진입은 share_code_modal(코드/링크 클립보드 복사)로 대비.
  void _shareLink(String name, String code) async {
    final link = ThemeShareService.httpsLinkForCode(code);
    final who = userDisplayName(ref.read(authProvider));
    final msg = trf('{0}님이 "{1}" 공유달력을 공유합니다.', [who, name]);
    try {
      await Share.share('$msg\n$link', subject: name);
    } catch (_) {
      // 공유 시트가 실패하면 코드/링크 복사 모달로 폴백.
      if (mounted) showShareCodeModal(context, name, code, link);
    }
  }
}
