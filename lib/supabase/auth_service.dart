// auth.js 대응 — 아이디는 '<id>@cal-id.local' 이메일로 합성.
// Supabase Dashboard에서 이메일 확인 비활성화 필요.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/storage_keys.dart';
import '../storage/local_store.dart';
import 'supabase_client.dart';
import 'account_scope.dart';

const _idDomain = 'cal-id.local';

String idToEmail(String id) => '${id.toLowerCase().trim()}@$_idDomain';
bool isSyntheticEmail(String email) => email.endsWith('@$_idDomain');
String emailToId(String email) =>
    isSyntheticEmail(email) ? email.substring(0, email.length - _idDomain.length - 1) : email;
bool isValidId(String id) => RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(id);

String userDisplayName(User? u) {
  if (u == null) { return ''; }
  final email = u.email ?? '';
  if (isSyntheticEmail(email)) { return emailToId(email); }
  return u.userMetadata?['nickname'] as String? ?? email;
}

class AuthNotifier extends Notifier<User?> {
  @override
  User? build() {
    sb?.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      state = user;
      // 계정 스코프 전환 + pull + provider invalidate 단일 처리
      AccountScope.applyAuth(ref, user);
    });
    final current = sb?.auth.currentUser;
    // 세션 복원이 아직 끝나지 않았을 수 있으니 1회 확인한다.
    if (current == null) {
      Future.microtask(ensureAutoLogin);
    }
    return current;
  }

  // 자동 로그인을 앱 프로세스당 1회만 실행하고 그 future를 캐시한다.
  // 스플래시(SplashGate)가 같은 future를 await 해 전환 타이밍을 맞출 수 있다.
  Future<void>? _autoLoginOnce;

  /// 자동 로그인 1회 실행 후 그 future 반환(이미 실행됐으면 동일 future).
  /// 세션이 이미 복원돼 있으면 [tryAutoLogin] 이 즉시 반환한다.
  Future<void> ensureAutoLogin() => _autoLoginOnce ??= tryAutoLogin();

  // ── 자동 로그인 ────────────────────────────────────────────────
  //
  // 예전에는 비밀번호를 base64 로 인코딩해 SharedPreferences 에 저장하고 앱 시작
  // 시 그걸로 다시 로그인했다. base64 는 암호화가 아니라 기기에서 평문을 그대로
  // 복원할 수 있다. supabase_flutter 가 이미 세션(리프레시 토큰)을 영속화하고
  // 앱 시작 시 복원하므로 비밀번호 보관은 애초에 필요 없다.
  //
  // 저장 자체를 없애고, 예전 버전에서 남은 값은 앱 시작 시 1회 지운다.

  /// 예전 버전이 저장해 둔 자격증명 제거(1회성 정리).
  static Future<void> purgeLegacyCredentials() async {
    final ls = LocalStore.instance;
    if (ls.getString(StorageKeys.savedAuthPw) == null &&
        ls.getString(StorageKeys.savedAuthId) == null) {
      return;
    }
    await ls.remove(StorageKeys.savedAuthPw);
    await ls.remove(StorageKeys.savedAuthId);
    debugPrint('[Auth] 예전 버전이 저장한 로컬 자격증명을 삭제했습니다');
  }

  Future<void> _clearCredentials() => purgeLegacyCredentials();

  /// 앱 시작 시: supabase_flutter 가 세션을 복원할 때까지 기다린다.
  ///
  /// 세션 복원은 `Supabase.initialize` 가 비동기로 처리하므로, 이 시점에
  /// `currentUser` 가 아직 null 일 수 있다. onAuthStateChange 가 뒤이어
  /// 상태를 채운다.
  Future<void> tryAutoLogin() async {
    await purgeLegacyCredentials();
    if (state != null) return;
    final restored = sb?.auth.currentSession?.user;
    if (restored != null) state = restored;
  }

  Future<void> signInWithId(String id, String password) async {
    final client = sb;
    if (client == null) { throw Exception('Supabase 클라이언트가 없습니다'); }
    if (!isValidId(id)) { throw Exception('아이디는 4~20자 영문/숫자/_'); }
    try {
      final res = await client.auth.signInWithPassword(
          email: idToEmail(id), password: password);
      state = res.user;
      // 스코프 전환 + 데이터 pull + invalidate 는 onAuthStateChange→AccountScope 처리
    } catch (e, st) {
      debugPrint('[Auth] signInWithId 실패: ${e.runtimeType} → $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> signUpWithId(String id, String password) async {
    final client = sb;
    if (client == null) { throw Exception('Supabase 클라이언트가 없습니다'); }
    if (!isValidId(id)) { throw Exception('아이디는 4~20자 영문/숫자/_'); }
    try {
      final res = await client.auth.signUp(
          email: idToEmail(id), password: password,
          data: {'id': id});
      state = res.user;
      // 신규 계정은 빈 데이터로 시작(게스트 데이터는 guest 스코프에 보존).
      // 스코프 전환/invalidate 는 AccountScope 가 처리.
    } catch (e, st) {
      debugPrint('[Auth] signUpWithId 실패: ${e.runtimeType} → $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // 소셜 로그인(Google · 카카오 · Apple)은 화면에 버튼만 먼저 올려 두고
  // 실제 연동은 아직 붙이지 않았다. 붙일 때 이 자리에 provider 별 진입점을
  // 추가하고 login_screen 의 _notReady 를 대체한다.

  Future<void> signOut() async {
    await _clearCredentials(); // 자동 로그인 비활성화
    await sb?.auth.signOut();
    state = null;
  }

  /// 회원 탈퇴 — 서버 RPC(delete_account)가 auth 사용자와 연결 데이터를 삭제한다.
  /// Apple App Store 요구사항: 계정 생성이 가능한 앱은 앱 내 탈퇴를 제공해야 함.
  Future<void> deleteAccount() async {
    final client = sb;
    if (client == null) throw StateError('Supabase 미연결');
    await client.rpc('delete_account');
    await _clearCredentials();
    await client.auth.signOut();
    state = null;
  }

  bool get isLoggedIn => state != null;
  String get displayName => userDisplayName(state);
}

final authProvider = NotifierProvider<AuthNotifier, User?>(AuthNotifier.new);
