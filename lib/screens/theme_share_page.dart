import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../modals/theme_manager_modal.dart';
import '../widgets/ui_kit.dart';
import 'sports/sports_subscription_section.dart';

/// 공유 및 구독 화면 — 상단 세그먼트 2개: 캘린더 공유 / 스포츠 구독.
class ThemeSharePage extends ConsumerStatefulWidget {
  const ThemeSharePage({super.key});

  @override
  ConsumerState<ThemeSharePage> createState() => _ThemeSharePageState();
}

class _ThemeSharePageState extends ConsumerState<ThemeSharePage> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 상단 세그먼트("캘린더 공유" | "스포츠 구독") ──
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
          child: SurlapSegmentedControl(
            index: _segment,
            onChanged: (i) => setState(() => _segment = i),
            segments: [
              surlapSegment(tr('캘린더 공유')),
              surlapSegment(tr('스포츠 구독')),
            ],
            expand: true,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _segment,
            children: [
              // 세그먼트1 — 캘린더 공유(테마 관리)
              ListView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 120),
                children: const [ThemeManagerBody()],
              ),
              // 세그먼트2 — 스포츠 구독
              ListView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 120),
                children: const [SportsSubscriptionSection()],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
