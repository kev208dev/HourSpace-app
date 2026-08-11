import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../supabase/apple_sign_in.dart';
import '../../supabase/auth_service.dart';
import '../../supabase/supabase_client.dart';
import '../../widgets/app_toast.dart';

/// 로그인 · 계정 만들기 · 게스트 (핸드오프 A5 · spec §2).
///
/// 계정 없이도 로컬 기능은 전부 쓸 수 있다. 계정은 클라우드 동기화와 공유
/// 캘린더에만 필요하다.
///
/// **이메일이 아니라 아이디로 로그인한다.** 입력한 아이디는 내부에서만
/// `<id>@cal-id.local` 로 바뀌어 Supabase 에 전달되고, 화면에서는 끝까지
/// 아이디로만 다룬다.
Future<void> showLoginScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

class LoginScreen extends ConsumerStatefulWidget {
  /// 첫 실행 흐름에서 "건너뛰기"를 노출할지.
  final bool showSkip;
  final VoidCallback? onDone;

  const LoginScreen({super.key, this.showSkip = false, this.onDone});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthTab { signIn, signUp }

/// Supabase 대시보드(Authentication → Providers)에서 실제로 켜 둔 provider.
///
/// 꺼진 provider 를 눌러도 서버가 오류를 주긴 하지만, 그건 왕복 한 번을 쓰고
/// 나서야 "안 된다"를 알려준다. 여기 플래그로 미리 걸러 즉시 안내한다.
/// **대시보드에서 켤 때 이 값도 같이 true 로 바꿔야 한다.**
const _kGoogleEnabled = true;
const _kKakaoEnabled = false; // 카카오 앱 미등록

/// Apple — 대시보드 Authentication → Providers → Apple 설정 완료.
/// Client IDs 에 앱 번들 ID(두 대소문자 형태)와 Services ID 가,
/// Secret Key 에 client secret JWT 가 들어 있다. 자세한 값은
/// `docs/apple-signin-setup.md` 참고.
const _kAppleEnabled = true;

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  _AuthTab _tab = _AuthTab.signIn;
  bool _obscure = true;
  bool _busy = false;
  String? _idError;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  bool get _idValid => isValidId(_idCtrl.text.trim());
  bool get _canSubmit =>
      !_busy && _idValid && _pwCtrl.text.length >= 6 && sb != null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _busy = true);
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    try {
      final auth = ref.read(authProvider.notifier);
      if (_tab == _AuthTab.signIn) {
        await auth.signInWithId(id, pw);
      } else {
        await auth.signUpWithId(id, pw);
      }
      if (!mounted) return;
      _finish();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('invalid login')) return tr('아이디 또는 비밀번호가 맞지 않습니다.');
    if (s.contains('already registered') || s.contains('already exists')) {
      return tr('이미 쓰고 있는 아이디입니다.');
    }
    return tr('처리하지 못했습니다. 잠시 후 다시 시도해 주세요.');
  }

  /// 한 번만 닫는다. 네이티브 로그인은 await 가 끝난 자리와 authProvider 리스너
  /// 양쪽에서 성공을 알게 되는데, 그대로 두면 화면이 두 번 pop 돼 뒤에 있던
  /// 화면까지 사라진다.
  bool _finished = false;

  void _finish() {
    if (_finished) return;
    _finished = true;
    if (widget.onDone != null) {
      widget.onDone!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// 아직 준비되지 않은 provider — 왕복 없이 그 자리에서 안내한다.
  void _notReady(String label) =>
      AppToast.show(context, trf('{0} 로그인은 준비 중입니다.', [label]));

  /// 소셜 로그인 — 리다이렉트 방식이라 결과는 콜백으로 돌아온다.
  ///
  /// Supabase 대시보드에서 해당 provider 를 켜 두지 않았으면 서버가 오류를
  /// 주므로, 그 사실을 그대로 안내한다.
  Future<void> _social(String label, Future<void> Function() run) async {
    if (sb == null) {
      AppToast.error(context, tr('서버 설정이 없어 소셜 로그인을 쓸 수 없습니다.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await run();
      // 네이티브 시트(Apple/iOS)는 여기서 이미 세션이 생겼다. 리다이렉트
      // 방식은 아직인데, 그건 _closeWhenSignedIn 이 세션이 생기는 순간 닫는다.
      if (mounted && ref.read(authProvider) != null) _finish();
    } on AppleSignInCancelled {
      // 사용자가 시트를 닫았다. 오류가 아니므로 아무것도 띄우지 않는다.
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, _socialMessage(label, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 소셜 로그인 실패 안내 — 사용자가 할 수 있는 일이 다르므로 구분한다.
  String _socialMessage(String label, Object e) {
    if (e is AppleSignInUnsupported) {
      return tr('이 기기에서는 Apple 로그인을 쓸 수 없습니다.');
    }
    final s = e.toString().toLowerCase();
    if (s.contains('not enabled') ||
        s.contains('unsupported provider') ||
        s.contains('provider is not enabled')) {
      return trf('{0} 로그인이 아직 켜져 있지 않습니다.', [label]);
    }
    if (s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('clientexception') ||
        s.contains('network')) {
      return tr('네트워크에 연결하지 못했습니다. 연결을 확인해 주세요.');
    }
    return trf('{0} 로그인에 실패했습니다.', [label]);
  }

  /// 로그인 화면이 떠 있는 동안 세션이 생기면 스스로 닫는다.
  ///
  /// 리다이렉트 방식(Android 의 Google·Apple)은 signInWithOAuth 가 브라우저를
  /// 띄우자마자 반환한다. 세션은 한참 뒤 딥링크로 들어온다. 그래서 await 만
  /// 믿으면 로그인이 끝났는데도 이 화면이 그대로 남아 있게 된다.
  /// (웹은 페이지 자체가 다시 로드되므로 이 경로를 타지 않는다.)
  void _closeWhenSignedIn() {
    ref.listen<User?>(authProvider, (prev, next) {
      if (prev == null && next != null && mounted) _finish();
    });
  }

  @override
  Widget build(BuildContext context) {
    _closeWhenSignedIn();
    final sh = context.sh;
    final noSupabase = sb == null;

    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        backgroundColor: sh.bg,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: sh.ink),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (widget.showSkip)
            TextButton(
              onPressed: _finish,
              child: Text(tr('건너뛰기'),
                  style: AppType.button.copyWith(color: sh.inkSoft)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
        children: [
          Text(tr('시작하기'),
              style: AppType.display.copyWith(
                  fontSize: 30, fontWeight: FontWeight.w700, color: sh.ink)),
          const SizedBox(height: Gap.sm),
          Text(
            tr('계정 없이도 모든 로컬 기능을 쓸 수 있습니다. 계정은 클라우드 동기화와 공유 캘린더에만 필요합니다.'),
            style: AppType.body.copyWith(
                fontSize: 14, height: 1.6,
                color: sh.ink.withValues(alpha: 0.62)),
          ),
          if (noSupabase) ...[
            const SizedBox(height: Gap.lg),
            _WarnBanner(
              text: tr('서버 설정이 없어 로그인·회원가입·공유 캘린더를 사용할 수 없습니다. '
                  '게스트로 계속하면 앱의 나머지 기능은 그대로 동작합니다.'),
            ),
          ],
          const SizedBox(height: Gap.lg),
          _Tabs(
            current: _tab,
            onPick: (t) => setState(() {
              _tab = t;
              _idError = null;
            }),
          ),
          const SizedBox(height: Gap.lg),
          _FieldLabel(tr('아이디')),
          _IdField(
            controller: _idCtrl,
            enabled: !noSupabase,
            error: _idError,
            onChanged: (_) => setState(() {
              _idError = _idCtrl.text.isEmpty || _idValid
                  ? null
                  : tr('영문·숫자·밑줄 4–20자로 지어 주세요.');
            }),
          ),
          const SizedBox(height: Gap.md),
          _FieldLabel(tr('비밀번호')),
          _PasswordField(
            controller: _pwCtrl,
            obscure: _obscure,
            enabled: !noSupabase,
            onToggle: () => setState(() => _obscure = !_obscure),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              child: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: sh.onAccent),
                    )
                  : Text(
                      _tab == _AuthTab.signIn ? tr('로그인') : tr('계정 만들기'),
                      style: AppType.button.copyWith(fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          const _OrDivider(),
          const SizedBox(height: Gap.md),
          // Apple 은 전 플랫폼에 노출한다. iOS·macOS 는 OS 시트로, 웹·Android 는
          // Supabase OAuth 리다이렉트로 같은 계정에 도달한다.
          //
          // 다른 소셜 버튼과 함께 둘 때는 Apple 버튼을 맨 위에 두라는 것이
          // Apple 의 요구사항이다. 그래서 Google 보다 앞에 온다.
          _AppleButton(
            pending: !_kAppleEnabled,
            onTap: _busy
                ? null
                : () => _kAppleEnabled
                    ? _social('Apple',
                        ref.read(authProvider.notifier).signInApple)
                    : _notReady('Apple'),
          ),
          const SizedBox(height: Gap.sm),
          _SocialButton(
            icon: Icons.g_mobiledata_rounded,
            label: tr('Google로 계속'),
            pending: !_kGoogleEnabled,
            onTap: _busy
                ? null
                : () => _kGoogleEnabled
                    ? _social('Google',
                        ref.read(authProvider.notifier).signInGoogle)
                    : _notReady('Google'),
          ),
          const SizedBox(height: Gap.sm),
          _SocialButton(
            icon: Icons.chat_bubble_rounded,
            label: tr('카카오로 계속'),
            pending: !_kKakaoEnabled,
            onTap: _busy
                ? null
                : () => _kKakaoEnabled
                    ? _social(tr('카카오'),
                        ref.read(authProvider.notifier).signInKakao)
                    : _notReady(tr('카카오')),
          ),
          const SizedBox(height: Gap.md),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: sh.accent,
              ),
              child: Text(tr('게스트로 계속'),
                  style: AppType.button.copyWith(fontSize: 14.5)),
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            tr('게스트로 만든 데이터는 기기에만 남습니다. 나중에 로그인하면 계정으로 가져올지 물어봅니다.'),
            style: AppType.caption.copyWith(
                height: 1.6, color: sh.ink.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final _AuthTab current;
  final ValueChanged<_AuthTab> onPick;
  const _Tabs({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final items = [
      (_AuthTab.signIn, tr('로그인')),
      (_AuthTab.signUp, tr('계정 만들기')),
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: sh.border),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(items[i].$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(
                      color: items[i].$1 == current
                          ? sh.accent
                          : Colors.transparent,
                      border: i == 0
                          ? null
                          : Border(left: BorderSide(color: sh.border)),
                    ),
                    child: Text(items[i].$2,
                        style: AppType.body.copyWith(
                            fontSize: 13.5,
                            color: items[i].$1 == current ? sh.bg : sh.ink)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppType.sub.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.sh.ink.withValues(alpha: 0.60))),
      );
}

/// 아이디 입력 — 이메일이 아니다. 내부 변환 도메인은 회색으로 덧붙여 보여준다.
class _IdField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? error;
  final ValueChanged<String> onChanged;

  const _IdField({
    required this.controller,
    required this.enabled,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: sh.card2,
            border: Border.all(color: error == null ? sh.border : sh.danger),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  onChanged: onChanged,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  style: AppType.body.copyWith(fontSize: 14, color: sh.ink),
                  decoration: InputDecoration(
                    hintText: tr('영문·숫자·밑줄 4–20자'),
                    hintStyle: TextStyle(
                        color: sh.ink.withValues(alpha: Alpha.placeholder)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(error!,
                style: AppType.sub
                    .copyWith(fontSize: 12, height: 1.5, color: sh.danger)),
          ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.enabled,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: sh.card2,
        border: Border.all(color: sh.border),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              obscureText: obscure,
              onChanged: onChanged,
              style: AppType.body.copyWith(fontSize: 14, color: sh.ink),
              decoration: InputDecoration(
                hintText: tr('6자 이상'),
                hintStyle: TextStyle(
                    color: sh.ink.withValues(alpha: Alpha.placeholder)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 16,
                color: sh.ink.withValues(alpha: 0.45)),
            tooltip: tr(obscure ? '비밀번호 보기' : '비밀번호 가리기'),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: sh.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
          child: Text(tr('또는'),
              style: AppType.label
                  .copyWith(color: sh.ink.withValues(alpha: 0.45))),
        ),
        Expanded(child: Container(height: 1, color: sh.border)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;

  /// 아직 켜지지 않은 provider. 누를 수는 있게 두되(안내를 띄운다) 흐리게
  /// 보이고 "준비 중" 꼬리표를 단다.
  final bool pending;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final ink = sh.ink.withValues(alpha: pending ? 0.42 : 1.0);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(
          pending ? trf('{0} · 준비 중', [label]) : label,
          style: AppType.button.copyWith(fontSize: 14.5),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          side: BorderSide(color: sh.border),
          foregroundColor: ink,
          backgroundColor: sh.card,
        ),
      ),
    );
  }
}

/// Apple 로그인 버튼.
///
/// Apple 의 버튼 가이드라인은 (1) 공식 Apple 로고, (2) 배경과 확실히 대비되는
/// 검정 또는 흰색 바탕, (3) "Apple로 계속하기" 같은 정해진 문구, (4) 로고와
/// 글자의 비율 유지를 요구한다. 모서리 반경과 너비는 앱에 맞춰도 된다.
///
/// 그래서 색만 Apple 규격(밝은 테마=검정 / 어두운 테마=흰색)으로 두고,
/// 높이·반경·타이포는 옆의 [_SocialButton] 과 똑같이 맞춰 같은 계층으로 보이게 한다.
class _AppleButton extends StatelessWidget {
  final bool pending;
  final VoidCallback? onTap;

  const _AppleButton({required this.onTap, this.pending = false});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    // 어두운 배경 위에서는 검정 버튼이 묻힌다 — Apple 이 흰색 변형을 두는 이유다.
    final bg = sh.dark ? Colors.white : Colors.black;
    final fg = sh.dark ? Colors.black : Colors.white;
    final alpha = pending ? 0.45 : 1.0;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.apple, size: 19, color: fg.withValues(alpha: alpha)),
        label: Text(
          pending ? tr('Apple로 계속하기 · 준비 중') : tr('Apple로 계속하기'),
          style: AppType.button
              .copyWith(fontSize: 14.5, color: fg.withValues(alpha: alpha)),
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          backgroundColor: bg.withValues(alpha: pending ? 0.55 : 1.0),
          disabledBackgroundColor: bg.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _WarnBanner extends StatelessWidget {
  final String text;
  const _WarnBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.accent2Bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline_rounded,
                size: 16, color: sh.accent2Ink),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(text,
                style: AppType.sub
                    .copyWith(height: 1.55, color: sh.accent2Ink)),
          ),
        ],
      ),
    );
  }
}
