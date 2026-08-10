import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../supabase/auth_service.dart';

/// [startWithForm]=true 면 Google/선택 화면을 건너뛰고 바로 아이디·비번 폼을 연다.
/// (플로팅 로그인 다이얼로그에서 '아이디로 로그인'으로 진입할 때 사용)
Future<void> showLoginModal(BuildContext context,
        {bool startWithForm = false}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LoginModal(startWithForm: startWithForm),
    );

class LoginModal extends ConsumerStatefulWidget {
  final bool startWithForm;
  const LoginModal({super.key, this.startWithForm = false});
  @override ConsumerState<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends ConsumerState<LoginModal> {
  final _idCtrl  = TextEditingController();
  final _pwCtrl  = TextEditingController();
  String? _error;
  bool _loading = false;
  // startWithForm 으로 진입하면 선택 화면을 건너뛰고 폼부터 표시.
  late bool _showForm = widget.startWithForm;

  @override void dispose() { _idCtrl.dispose(); _pwCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    // Google OAuth는 리다이렉트 복귀로 세션이 생긴다 — 성공 시 모달 자동 종료
    // (안 닫으면 스피너가 계속 떠 무한 로그인처럼 보임).
    ref.listen(authProvider, (prev, next) {
      // 로그아웃→로그인 '전환'에만 닫는다(토큰 리프레시 등 비-null 재방출엔 무반응).
      if (prev == null && next != null && mounted) Navigator.of(context).pop();
    });
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color: sh.card,
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 항상 보이는 닫기(×) 버튼.
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: sh.inkSoft),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '닫기',
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/mascot/splash_icon.png', height: 30),
                const SizedBox(width: 8),
                Text('Surlap',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.025 * 22,
                        color: sh.ink,
                        height: 1.0)),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(tr('사용 방식을 선택해주세요'),
                style: AppType.body.copyWith(color: sh.inkSoft)),
            const SizedBox(height: 28),
            if (!_showForm) ...[
              // ── Apple 로그인 (iOS only, App Store 4.8 요구사항) ──
              if (!kIsWeb && Platform.isIOS) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _signInApple,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.card)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.apple, size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(tr('Apple로 로그인'),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // ── Google 로그인 ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : _signInGoogle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: sh.ink,
                    side: BorderSide(color: sh.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.card)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoogleLogo(),
                      const SizedBox(width: 10),
                      Text(tr('Google로 로그인'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── 구분선 ──
              Row(children: [
                Expanded(child: Divider(color: sh.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: Text(tr('또는'),
                      style: AppType.caption.copyWith(color: sh.inkFaint)),
                ),
                Expanded(child: Divider(color: sh.border)),
              ]),
              const SizedBox(height: 8),
              // ── 아이디 로그인 ──
              SizedBox(width: double.infinity,
                child: FilledButton(
                  onPressed: () => setState(() => _showForm = true),
                  child: Text(tr('아이디로 로그인')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: sh.inkSoft, side: BorderSide(color: sh.border)),
                  child: Text(tr('로그인 없이 사용')),
                ),
              ),
            ] else ...[
              if (_error != null)
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: Gap.md),
                  decoration: BoxDecoration(
                    color: sh.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.small)),
                  child: Text(_error!,
                      style: AppType.body.copyWith(color: sh.danger)),
                ),
              TextField(
                controller: _idCtrl,
                decoration: InputDecoration(
                    labelText: tr('아이디'),
                    hintText: tr('처음이면 새 아이디 등록'),
                    hintStyle: TextStyle(color: sh.inkFaint)),
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: tr('비밀번호'), hintText: tr('4자 이상')),
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => setState(() { _showForm = false; _error = null; }),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: sh.inkSoft, side: BorderSide(color: sh.border)),
                  child: Text(tr('뒤로')),
                )),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr('확인')),
                )),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _signInGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).signInGoogle();
      // OAuth는 리다이렉트 방식이라 여기서 pop 불필요 (페이지 이동됨)
      // 모달은 열어두고 리다이렉트 대기
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _signInApple() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).signInApple();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _submit() async {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (id.isEmpty || pw.isEmpty) {
      setState(() => _error = tr('아이디와 비밀번호를 입력해주세요'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // 먼저 로그인 시도, 실패하면 회원가입
      try {
        await ref.read(authProvider.notifier).signInWithId(id, pw);
      } catch (_) {
        await ref.read(authProvider.notifier).signUpWithId(id, pw);
      }
      if (mounted) { Navigator.pop(context); }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }
}

/// Google 'G' 로고 (SVG 재현)
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;

    // 파란색 부분
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -0.52, 2.62, false,
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = 4 * s,
    );
    // 빨간색
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      2.09, 1.05, false,
      Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = 4 * s,
    );
    // 노란색
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      3.14, 0.52, false,
      Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = 4 * s,
    );
    // 초록색
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      3.66, 0.52, false,
      Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = 4 * s,
    );
    // 흰 가로선 (G의 수평 부분)
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width * 0.92, size.height * 0.5),
      Paint()..color = const Color(0xFF4285F4)..strokeWidth = 3.5 * s..strokeCap = StrokeCap.round,
    );
    // 중심 흰 원 (구멍)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.32,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}

