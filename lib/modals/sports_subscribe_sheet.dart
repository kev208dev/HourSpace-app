import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../models/sports.dart';
import '../sports/sports_catalog.dart';
import '../providers/sports_provider.dart';
import '../widgets/sport_logo.dart';
import '../i18n/strings.dart';

/// 스포츠 구독 흐름 — 종목 → 리그/대회 → 팀/선수 → 구독.
Future<void> showSportsSubscribeSheet(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SportsSubscribeSheet(),
    );

class _SportsSubscribeSheet extends ConsumerStatefulWidget {
  const _SportsSubscribeSheet();
  @override
  ConsumerState<_SportsSubscribeSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_SportsSubscribeSheet> {
  SportInfo? _sport;
  SportLeague? _league;

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final step = _sport == null ? 0 : (_league == null ? 1 : 2);
    final titles = ['종목 선택', '리그·대회 선택', '팀·대회 선택'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Container(
          decoration: BoxDecoration(
            color: sh.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: sh.ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  if (step > 0)
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_league != null) {
                          _league = null;
                        } else {
                          _sport = null;
                        }
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 22, color: sh.inkSoft),
                      ),
                    ),
                  Text(titles[step],
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
                    tooltip: '닫기',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(child: _body(sh, step)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(SurlapColors sh, int step) {
    if (step == 0) {
      return GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (final s in kSports)
            _Tile(
              emoji: s.emoji,
              label: tr(s.label),
              sub: s.gamesSupported ? null : tr('곧 지원'),
              sh: sh,
              onTap: () => setState(() {
                _sport = s;
                if (s.leagues.length == 1) _league = s.leagues.first;
              }),
            ),
        ],
      );
    }
    if (step == 1) {
      return ListView(
        children: [
          for (final l in _sport!.leagues)
            _Row(
              label: tr(l.name),
              sh: sh,
              onTap: () => setState(() => _league = l),
            ),
        ],
      );
    }
    // step 2 — 팀/대회
    final teams = teamsForLeague(_league!.id);
    return ListView(
      children: [
        for (final t in teams) _teamRow(sh, t),
      ],
    );
  }

  Widget _teamRow(SurlapColors sh, SportTeam t) {
    final id = '${_sport!.kind.name}:${_league!.id}:${t.id}';
    final already = ref.watch(sportsSubscriptionsProvider
        .select((subs) => subs.any((s) => s.id == id)));
    final color = Color(pickSportColor(id));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sh.card2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            SportLogo(logoUrl: t.logo, emoji: _sport!.emoji, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr(t.name),
                  style: AppType.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700, color: sh.ink)),
            ),
            already
                ? Row(
                    children: [
                      Icon(Icons.check_rounded, size: 16, color: sh.accent),
                      const SizedBox(width: 4),
                      Text('구독중',
                          style: AppType.bodySmall.copyWith(color: sh.accent)),
                    ],
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: sh.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final sub = SportSubscription(
                        id: id,
                        sport: _sport!.kind.name,
                        leagueId: _league!.id,
                        leagueName: _league!.name,
                        teamId: t.id,
                        teamName: t.name,
                        emoji: _sport!.emoji,
                        color: pickSportColor(id),
                      );
                      final nav = Navigator.of(context);
                      await ref
                          .read(sportsSubscriptionsProvider.notifier)
                          .subscribe(sub);
                      if (mounted) nav.pop();
                    },
                    child: const Text('구독',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String emoji, label;
  final String? sub;
  final SurlapColors sh;
  final VoidCallback onTap;
  const _Tile(
      {required this.emoji,
      required this.label,
      this.sub,
      required this.sh,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: sh.card2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: AppType.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700, color: sh.ink)),
            ),
            if (sub != null)
              Text(sub!,
                  style: AppType.bodySmall.copyWith(color: sh.inkFaint)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final SurlapColors sh;
  final VoidCallback onTap;
  const _Row({required this.label, required this.sh, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: sh.card2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AppType.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700, color: sh.ink)),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: sh.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
