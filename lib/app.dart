import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'i18n/app_lang.dart';
import 'i18n/strings.dart' as i18n;
import 'providers/locale_provider.dart';
import 'home_widget/widget_bridge.dart';
import 'providers/color_preset_provider.dart';
import 'providers/events_provider.dart';
import 'providers/event_notify_provider.dart';
import 'providers/briefing_notify_provider.dart';
import 'providers/themes_provider.dart';
import 'providers/todos_provider.dart';
import 'providers/birthdays_provider.dart';
import 'providers/filter_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/neis_cache_provider.dart';
import 'providers/academic_schedule_provider.dart';
import 'providers/shared_theme_events_provider.dart';
import 'providers/sports_provider.dart';
import 'screens/splash/splash_gate.dart';
import 'supabase/theme_share_service.dart';

/// 넓은 화면에서 앱을 가둘 최대 폭(논리 픽셀). 큰 휴대폰 기준.
const double _kMobileMaxWidth = 480;

/// 딥링크 등 어디서든 스낵바를 띄우기 위한 전역 messenger key.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SurlapApp extends ConsumerStatefulWidget {
  const SurlapApp({super.key});

  @override
  ConsumerState<SurlapApp> createState() => _SurlapAppState();
}

class _SurlapAppState extends ConsumerState<SurlapApp>
    with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  Timer? _widgetTick;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    WidgetsBinding.instance.addObserver(this);
    // 할 일/일정/테마/생일/필터 변경 시 홈 위젯 자동 갱신.
    ref.listenManual(todosProvider, (_, _) => _syncWidget());
    ref.listenManual(eventsProvider, (_, _) => _syncWidget());
    ref.listenManual(themesProvider, (_, _) => _syncWidget());
    ref.listenManual(birthdaysProvider, (_, _) => _syncWidget());
    ref.listenManual(filterProvider, (_, _) => _syncWidget());
    ref.listenManual(recurringProvider, (_, _) => _syncWidget());
    // 위젯이 통합 계층을 쓰게 되면서 학교·공유·스포츠 데이터도 위젯에 뜬다.
    // 그 소스들이 갱신될 때도 위젯을 다시 그려야 앱과 어긋나지 않는다.
    ref.listenManual(neisCacheProvider, (_, _) => _syncWidget());
    ref.listenManual(academicScheduleProvider, (_, _) => _syncWidget());
    ref.listenManual(sharedThemeEventsProvider, (_, _) => _syncWidget());
    ref.listenManual(sportsEventsProvider, (_, _) => _syncWidget());
    // 첫 프레임 후 홈 위젯 초기 동기화
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWidget());
    // 1분마다 위젯 갱신 — 진행 교시·남은시간이 실시간 반영되도록.
    _widgetTick = Timer.periodic(const Duration(minutes: 1), (_) => _syncWidget());
    // 일정 알림 notifier를 깨워 events 변경 listen + 초기 재스케줄 트리거.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventNotifyProvider.notifier).reschedule();
      ref.read(briefingNotifyProvider.notifier).reschedule();
    });
  }

  void _syncWidget() {
    WidgetBridge.sync(ref).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱 복귀 시 위젯 갱신 (날짜 변경/타 기기 동기화 반영)
    if (state == AppLifecycleState.resumed) _syncWidget();
  }

  Future<void> _initDeepLinks() async {
    // 앱이 링크로 처음 실행된 경우
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (_) {}
    // 앱 실행 중 들어오는 링크
    _sub = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _widgetTick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// `surlap://theme/CODE` 또는 `https://kev208dev.github.io/Surlap/theme/CODE`
  void _handleUri(Uri uri) {
    // Google OAuth 콜백(surlap://login-callback). 세션 복원은 supabase_flutter가
    // 자동 처리하므로 여기선 손대지 않는다. 단, error 가 실려오면(redirect URL 미등록 등)
    // 조용히 무한 로그인처럼 보이므로 사유를 표면화한다.
    if (uri.host == 'login-callback') {
      final err = uri.queryParameters['error_description'] ??
          uri.queryParameters['error'];
      if (err != null && err.isNotEmpty) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('로그인 실패: ${Uri.decodeComponent(err)}')),
        );
      }
      return;
    }
    String? code;
    if (uri.scheme == ThemeShareService.scheme && uri.host == 'theme') {
      if (uri.pathSegments.isNotEmpty) code = uri.pathSegments.first;
    } else {
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs[segs.length - 2] == 'theme') {
        code = segs.last;
      }
    }
    if (code == null || code.trim().isEmpty) return;
    _subscribeToCode(code.toUpperCase().trim());
  }

  Future<void> _subscribeToCode(String code) async {
    final messenger = scaffoldMessengerKey.currentState;
    void snack(String m) =>
        messenger?.showSnackBar(SnackBar(content: Text(m)));
    try {
      final theme = await ThemeShareService.fetchByCode(code);
      if (theme == null) {
        snack('캘린더를 찾을 수 없어요: $code');
        return;
      }
      final existing = ref.read(themesProvider);
      if (existing.any((t) => t.shareCode == theme.shareCode)) {
        snack('이미 구독 중인 캘린더예요: ${theme.name}');
        return;
      }
      await ref
          .read(themesProvider.notifier)
          .add(theme.copyWith(shareRole: 'subscriber'));
      snack('캘린더 "${theme.name}" 구독 완료');
    } catch (e) {
      snack('링크 처리 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = ref.watch(colorPresetProvider);
    // 언어 변경 시 트리 전체가 리빌드되며 currentLang이 갱신 → 모든 tr() 재평가.
    final lang = ref.watch(localeProvider);
    i18n.currentLang = lang;
    return MaterialApp(
      title: 'Surlap',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: buildTheme(preset),
      locale: lang.locale,
      supportedLocales: AppLang.values.map((l) => l.locale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashGate(),
      builder: _mobileFrame,
    );
  }

  /// 넓은 화면에서 앱 폭을 휴대폰 기준으로 묶는다.
  ///
  /// 웹 프리뷰를 데스크톱 브라우저에서 열면 레이아웃이 화면 끝까지 늘어나
  /// 실제 모바일 화면과 전혀 다르게 보인다. 앱 자체의 디자인·정보구조는
  /// 건드리지 않고, 최상단에서 폭만 제한한다. 모바일 폭에서는 아무 영향이 없다.
  static Widget _mobileFrame(BuildContext context, Widget? child) {
    if (child == null) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _kMobileMaxWidth) return child;
    final sh = Theme.of(context).extension<SurlapColors>();
    return ColoredBox(
      color: sh?.card2 ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: ClipRect(
          child: SizedBox(width: _kMobileMaxWidth, child: child),
        ),
      ),
    );
  }
}
