import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../supabase/auth_service.dart';
import '../../i18n/strings.dart';
import '../../modals/login_modal.dart';
import '../../widgets/app_toast.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

/// 전체화면 로그인 — 스플래시/온보딩과 같은 보라→블루 그라데이션 톤.
/// 기존 인증 로직(signInGoogle / 아이디 폼)을 그대로 재사용한다.
/// [onDone]: 로그인 성공 또는 "나중에 하기" 시 호출.
Future<void> showLoginScreen(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (routeCtx) => LoginScreen(
      showSkip: true,
      onDone: () => Navigator.of(routeCtx).maybePop(),
    ),
  ));
}

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  final bool showSkip;
  const LoginScreen({super.key, required this.onDone, this.showSkip = true});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).signInGoogle();
      // OAuth 리다이렉트 — 성공 시 authProvider 변화 → ref.listen이 onDone 호출.
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.error(context, tr('로그인에 실패했어요. 잠시 후 다시 시도해주세요'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 성공(세션 확보) 시 완료 콜백.
    ref.listen(authProvider, (prev, next) {
      if (next != null && mounted) widget.onDone();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF5A2DF4),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5A2DF4), Color(0xFF7C4DFF)],
            ),
          ),
          child: Stack(children: [
            Positioned(
              top: -110,
              right: -80,
              child: _glow(300, Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              bottom: -150,
              left: -110,
              child:
                  _glow(360, const Color(0xFF9B6BFF).withValues(alpha: 0.30)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // ── 마스코트 + 워드마크 + 헤드라인 ──
                    Icon(Icons.calendar_month_rounded, size: 56),
                    const SizedBox(height: 22),
                    Text('Surlap',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.025 * 30,
                            color: Colors.white,
                            height: 1.0)),
                    const SizedBox(height: 12),
                    Text(
                      tr('오늘의 시간을 정리해볼까요?'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('로그인하면 일정·시간표·캘린더가\n모든 기기에서 안전하게 동기화돼요'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.72)),
                    ),
                    const Spacer(flex: 3),
                    // ── 흰색 pill 메인 버튼 (Google) ──
                    _WhitePill(
                      label: tr('Google로 계속하기'),
                      loading: _loading,
                      onTap: _loading ? null : _google,
                    ),
                    const SizedBox(height: 12),
                    // ── 아이디로 로그인 (보조) ──
                    SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => showLoginModal(context,
                                startWithForm: true),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(tr('아이디로 로그인'),
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.92))),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ── 나중에 하기 (약한 액션) ──
                    if (widget.showSkip)
                      TextButton(
                        onPressed: widget.onDone,
                        child: Text(tr('나중에 하기'),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.55))),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.0)]),
        ),
      );
}

// ─── 흰색 pill 버튼 ──────────────────────────────────────────────
class _WhitePill extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _WhitePill(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.sh.accent),
                    )
                  : Text(label,
                      style: AppType.button.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.sh.accent)),
            ),
          ),
        ),
      ),
    );
  }
}
