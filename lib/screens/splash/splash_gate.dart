import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../supabase/auth_service.dart';
import '../../storage/local_store.dart';
import '../../core/constants/storage_keys.dart';
import '../main_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'splash_screen.dart';

/// 앱 진입점 게이트.
///
/// 스플래시를 표시하는 동안 (1) auth 정착(세션 복원 + 자동 로그인 시도)과
/// (2) 최소 표시 시간을 함께 기다린 뒤, 부드러운 fade 로 [MainShell] 로 전환한다.
///
/// 로그인 modal 은 여기서 띄우지 않는다 — MainShell 진입 후 overlay 로 표시된다
/// (기존 MainShell 로직 유지). 캘린더/시간표/Supabase 데이터 로직은 건드리지 않고,
/// auth 로딩 상태만 읽어 전환 타이밍에 활용한다.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key});

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> {
  // 스플래시는 초기화가 끝날 때까지만 보인다. 예전에는 브랜드 애니메이션을
  // 다 보여주려고 3.1초를 고정으로 기다렸는데, 매번 앱 진입이 3초씩 늦어졌다
  // (스펙 §29). 애니메이션은 초기화와 동시에 돌고, 화면이 홱 깜빡이지 않을
  // 만큼만 최소 시간을 둔다.
  static const _minSplash = Duration(milliseconds: 450);

  bool _ready = false;
  // 온보딩 완료(또는 이미 시청) 여부. 미시청 첫 실행이면 false.
  bool _onboardingDone = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _finishOnboarding() {
    LocalStore.instance.setBool(StorageKeys.hasSeenOnboarding, true);
    if (mounted) setState(() => _onboardingDone = true);
  }

  Future<void> _bootstrap() async {
    // authProvider 를 읽어 notifier 를 구성 → 세션 복원/자동 로그인 파이프라인 시작.
    // (auth 상태 변화 시 데이터 pull/invalidate 는 기존 AccountScope 로직이 처리)
    final auth = ref.read(authProvider.notifier);

    // 최소 표시 시간과 auth(자동 로그인) 정착을 함께 대기.
    // ensureAutoLogin 은 1회만 실행되며, 세션이 이미 있으면 즉시 완료된다.
    await Future.wait<void>([
      Future<void>.delayed(_minSplash),
      auth.ensureAutoLogin(),
    ]);

    if (!mounted) return;
    // 온보딩을 이미 본 사용자면 바로 통과.
    final seen =
        LocalStore.instance.getBool(StorageKeys.hasSeenOnboarding) ?? false;
    setState(() {
      _ready = true;
      _onboardingDone = seen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_ready) {
      child = const SplashScreen(key: ValueKey('splash'));
    } else if (!_onboardingDone) {
      // 첫 실행: 소개 → 학교 연결 → Today. 언어는 기기 로케일을 따르고,
      // 로그인은 클라우드·공유가 필요한 순간에 요구한다(스펙 §28).
      child = OnboardingScreen(
        key: const ValueKey('onboarding'),
        onDone: _finishOnboarding,
      );
    } else {
      child = const MainShell(key: ValueKey('main'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: child,
    );
  }
}
