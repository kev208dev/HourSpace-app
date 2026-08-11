import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surlap/supabase/apple_sign_in.dart';

/// Apple 로그인의 플랫폼 분기와 nonce 처리.
///
/// 실제 로그인은 OS 시트와 Apple 서버가 필요해 단위 테스트로 확인할 수 없다.
/// 대신 틀리면 조용히 로그인만 실패하는 두 가지를 못 박는다.
void main() {
  group('플랫폼 분기', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('iOS·macOS 만 네이티브 시트를 쓴다', () {
      for (final p in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = p;
        expect(AppleSignIn.usesNativeSheet, isTrue, reason: '$p');
      }
    });

    test('나머지는 OAuth 리다이렉트로 간다', () {
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = p;
        expect(AppleSignIn.usesNativeSheet, isFalse, reason: '$p');
      }
    });
  });

  group('nonce', () {
    // Apple 에는 해시를, Supabase 에는 원본을 준다. 둘이 뒤바뀌면 서버가
    // id_token 의 nonce 클레임과 대조에 실패해 로그인이 거절된다.
    test('SHA-256 을 소문자 16진수로 낸다', () {
      expect(
        AppleSignIn.hashNonce('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('같은 입력은 같은 해시 — 서버 대조가 성립한다', () {
      expect(AppleSignIn.hashNonce('surlap'), AppleSignIn.hashNonce('surlap'));
    });

    test('해시는 원본과 다르다 — 원본을 그대로 넘기지 않는다', () {
      const raw = 'surlap';
      expect(AppleSignIn.hashNonce(raw), isNot(raw));
      expect(AppleSignIn.hashNonce(raw).length, 64);
    });
  });
}
