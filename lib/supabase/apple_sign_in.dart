// Apple 로그인 — 플랫폼마다 방식이 다르다.
//
// ── 왜 갈라지나 ───────────────────────────────────────────────────────────
// iOS·macOS 에서는 OS 가 직접 인증 시트를 띄운다. 브라우저를 거치지 않으니
// 앱 밖으로 나갔다 돌아오는 왕복이 없고, 취소·실패를 그 자리에서 알 수 있다.
// App Store 심사도 이쪽을 기대한다.
//
// 웹·Android 에는 그 시트가 없다. Supabase 의 OAuth 리다이렉트로 처리한다.
// 이때는 Apple Developer 의 **Services ID** 와 client secret 이 필요한데,
// 둘 다 Supabase 대시보드에만 넣는다(클라이언트 코드는 알 필요가 없다).
//
// ── nonce ────────────────────────────────────────────────────────────────
// 재생 공격(같은 id_token 을 가로채 다시 제출)을 막는다. 절차:
//   1. 원본 nonce 를 난수로 만든다.
//   2. Apple 에는 SHA-256 **해시**를 준다 → Apple 이 id_token 의 nonce 클레임에 박는다.
//   3. Supabase 에는 **원본**을 준다 → 서버가 해시해서 토큰 클레임과 대조한다.
// 원본을 Apple 에 주거나 해시를 Supabase 에 주면 대조가 어긋나 로그인이 실패한다.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 사용자가 Apple 시트를 스스로 닫았다. 오류가 아니므로 조용히 넘긴다.
class AppleSignInCancelled implements Exception {
  const AppleSignInCancelled();
  @override
  String toString() => 'AppleSignInCancelled';
}

/// 이 기기·OS 가 네이티브 Apple 로그인을 지원하지 않는다.
class AppleSignInUnsupported implements Exception {
  const AppleSignInUnsupported();
  @override
  String toString() => 'AppleSignInUnsupported';
}

class AppleSignIn {
  /// 네이티브 시트를 쓰는 플랫폼인지.
  ///
  /// 웹은 dart:io 가 없어 defaultTargetPlatform 이 브라우저의 OS 를 흉내내
  /// iOS 로 나올 수 있다. kIsWeb 을 먼저 본다.
  static bool get usesNativeSheet =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @visibleForTesting
  static String hashNonce(String raw) =>
      sha256.convert(utf8.encode(raw)).toString();

  /// 네이티브 시트로 로그인하고 Supabase 세션을 만든다.
  ///
  /// 성공하면 supabase_flutter 가 세션을 저장하고 onAuthStateChange 가 울린다.
  /// 이후 처리(스코프 전환·클라우드 pull·provider invalidate)는 기존
  /// AccountScope 경로가 그대로 맡는다 — Google 과 완전히 같은 길이다.
  static Future<void> signInNative(SupabaseClient client) async {
    if (!usesNativeSheet) throw const AppleSignInUnsupported();
    if (!await SignInWithApple.isAvailable()) {
      throw const AppleSignInUnsupported();
    }

    final rawNonce = client.auth.generateRawNonce();

    final AuthorizationCredentialAppleID cred;
    try {
      cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashNonce(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AppleSignInCancelled();
      }
      rethrow;
    } on SignInWithAppleNotSupportedException {
      throw const AppleSignInUnsupported();
    }

    final idToken = cred.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Apple 이 ID 토큰을 주지 않았습니다');
    }

    await client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    await _saveNameOnce(client, cred);
  }

  /// Apple 은 이름을 **맨 처음 인가 때 한 번만** 준다. 재로그인부터는 빈 값이라
  /// 그때 저장하지 않으면 영영 못 받는다(사용자가 설정에서 앱 인가를 지우고
  /// 다시 로그인해야 한다).
  ///
  /// 그래서 받은 즉시 user_metadata.nickname 에 넣는다 — userDisplayName 이
  /// 읽는 자리다. 이미 이름이 있으면 덮어쓰지 않는다.
  ///
  /// 실패해도 로그인 자체는 성공이므로 예외를 밖으로 내보내지 않는다.
  static Future<void> _saveNameOnce(
      SupabaseClient client, AuthorizationCredentialAppleID cred) async {
    final name = [cred.givenName, cred.familyName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (name.isEmpty) return;

    final existing = client.auth.currentUser?.userMetadata?['nickname'];
    if (existing is String && existing.trim().isNotEmpty) return;

    try {
      await client.auth.updateUser(UserAttributes(data: {'nickname': name}));
    } catch (e) {
      debugPrint('[AppleSignIn] 이름 저장 실패(로그인은 성공): $e');
    }
  }
}
