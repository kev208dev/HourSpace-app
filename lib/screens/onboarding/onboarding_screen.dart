import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../modals/neis_setup_modal.dart';
import '../../supabase/neis_service.dart' show NeisSchool;
import '../../widgets/mascot/mascot.dart';
import '../../widgets/surlap_logo.dart';

/// 첫 실행 — 두 걸음이면 끝난다(스펙 §28).
///
///   Surlap 소개 → 학교 연결(건너뛰기 가능) → Today
///
/// 예전에는 스플래시 → 언어 선택 → 소개 3장 → 사용자 유형 → 로그인 순으로
/// 다섯 화면을 지나야 앱을 볼 수 있었다. 언어는 기기 로케일을 따르고,
/// 로그인은 클라우드·공유가 필요할 때 요구한다.
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { intro, school }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.intro;

  Future<void> _connectSchool() async {
    await showNeisSetupModal(context);
    if (!mounted) return;
    // 연결에 성공했으면 곧장 Today 로 — 이 순간이 첫 성공 경험이다.
    if (NeisSchool.load() != null) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Scaffold(
      backgroundColor: sh.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: Motion.base,
          switchInCurve: Motion.curve,
          child: _step == _Step.intro
              ? _Intro(
                  key: const ValueKey('intro'),
                  onStart: () => setState(() => _step = _Step.school),
                )
              : _SchoolStep(
                  key: const ValueKey('school'),
                  onConnect: _connectSchool,
                  onSkip: widget.onDone,
                ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final VoidCallback onStart;
  const _Intro({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xxl, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const SurlapLogo(size: 44),
          const SizedBox(height: Gap.xl),
          Text(
            tr('학교와 일상을\n한 곳에서.'),
            style: AppType.headlineLarge.copyWith(
              fontSize: 34,
              height: 1.25,
              color: sh.ink,
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            tr('시간표·급식·학사일정이 자동으로 들어오는 학생용 캘린더'),
            style: AppType.bodyLarge.copyWith(color: sh.inkSoft),
          ),
          const Spacer(),
          const Center(
            child: MascotView(expression: MascotExpression.happy, size: 140),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(tr('시작하기')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolStep extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onSkip;

  const _SchoolStep({
    super.key,
    required this.onConnect,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xxl, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            tr('학교에 다니고 있나요?'),
            style: AppType.headlineLarge.copyWith(fontSize: 30, color: sh.ink),
          ),
          const SizedBox(height: Gap.md),
          Text(
            tr('학교와 학년·반을 알려주면\n시간표·급식·학사일정을 매일 자동으로 가져와요.'),
            style: AppType.bodyLarge.copyWith(color: sh.inkSoft, height: 1.5),
          ),
          const Spacer(),
          const Center(
            child:
                MascotView(expression: MascotExpression.thinking, size: 120),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConnect,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(tr('학교 검색')),
            ),
          ),
          const SizedBox(height: Gap.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(kMinTouch),
                foregroundColor: sh.inkSoft,
              ),
              child: Text(tr('나중에 할게요')),
            ),
          ),
        ],
      ),
    );
  }
}
