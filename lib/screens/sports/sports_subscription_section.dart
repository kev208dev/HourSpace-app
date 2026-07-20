import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../models/sports.dart';
import '../../core/constants/sports_config.dart';
import '../../sports/sports_catalog.dart';
import '../../providers/sports_provider.dart';
import '../../modals/sports_subscribe_sheet.dart';
import '../../modals/sport_color_picker.dart';
import '../../i18n/strings.dart';
import '../../widgets/sport_logo.dart';

/// 테마 관리 탭의 "스포츠 구독" 섹션.
/// 구독한 팀 목록 + 알림 주기 + 해제 + 새 구독 추가.
class SportsSubscriptionSection extends ConsumerWidget {
  const SportsSubscriptionSection({super.key});

  static const _reminderCycle = [0, 10, 30, 60]; // 분

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final subs = ref.watch(sportsSubscriptionsProvider);
    final notifier = ref.read(sportsSubscriptionsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 데이터 소스(BallDontLie) API 키 미설정 안내 — 키 없으면 경기가 안 옴.
        if (!hasSportsApiKey)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: sh.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sh.danger.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: sh.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '스포츠 API 키가 없어 경기 일정이 안 와요.\n'
                    '빌드 시 --dart-define=BALLDONTLIE_API_KEY=키 를 넣어주세요.',
                    style: AppType.bodySmall.copyWith(
                        color: sh.ink, height: 1.35),
                  ),
                ),
              ],
            ),
          ),

        if (subs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: sh.card2.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('아직 구독한 팀이 없어요.',
                style: AppType.bodyLarge.copyWith(color: sh.inkSoft)),
          )
        else
          ...subs.map((s) => _subTile(context, ref, sh, notifier, s)),

        const SizedBox(height: 10),
        // 구독 추가
        InkWell(
          onTap: () => showSportsSubscribeSheet(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: sh.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sh.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 20, color: sh.accent),
                const SizedBox(width: 6),
                Text('스포츠 구독 추가',
                    style: AppType.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800, color: sh.accent)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _subTile(
    BuildContext context,
    WidgetRef ref,
    SurlapColors sh,
    SportsSubscriptionsNotifier notifier,
    SportSubscription s,
  ) {
    final color = Color(s.color);
    final reminderLabel =
        s.reminderMinutes <= 0 ? '알림 끔' : '${s.reminderMinutes}분 전';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // 색 스와치 — 탭하면 색 선택, 고르면 달력에 바로 반영.
          GestureDetector(
            onTap: () async {
              final picked = await showSportColorPicker(context, s.color);
              if (picked != null) notifier.setColor(s.id, picked);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: sh.ink.withValues(alpha: 0.15), width: 2),
              ),
              child: Icon(Icons.edit_rounded,
                  size: 11, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
          const SizedBox(width: 10),
          SportLogo(
              logoUrl: teamLogoUrl(s.leagueId, s.teamId),
              emoji: s.emoji,
              size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(s.teamName),
                    style: AppType.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700, color: sh.ink)),
                // 미지원 종목(e스포츠·F1 등)은 경기 소스가 없음을 명시.
                sportInfo(s.kind).gamesSupported
                    ? Text(tr(s.leagueName),
                        style: AppType.bodySmall.copyWith(color: sh.inkSoft))
                    : Text(trf('{0} · 경기 소스 없음', [tr(s.leagueName)]),
                        style: AppType.bodySmall.copyWith(color: sh.danger)),
              ],
            ),
          ),
          // 알림 주기 토글
          GestureDetector(
            onTap: () {
              final idx = _reminderCycle.indexOf(s.reminderMinutes);
              final next =
                  _reminderCycle[(idx + 1) % _reminderCycle.length];
              notifier.setReminder(s.id, next);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: s.reminderMinutes > 0
                    ? sh.accent.withValues(alpha: 0.12)
                    : sh.ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    s.reminderMinutes > 0
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    size: 14,
                    color: s.reminderMinutes > 0 ? sh.accent : sh.inkFaint,
                  ),
                  const SizedBox(width: 4),
                  Text(reminderLabel,
                      style: AppType.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: s.reminderMinutes > 0
                              ? sh.accent
                              : sh.inkFaint)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: sh.inkFaint),
            onPressed: () => notifier.unsubscribe(s.id),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
