import 'package:flutter_test/flutter_test.dart';
import 'package:surlap/supabase/auth_service.dart';

/// 로그인은 이메일이 아니라 **아이디** 기반이다(핸드오프 A5 · spec §2).
///
/// 사용자가 보는 것은 끝까지 아이디이고, `<id>@cal-id.local` 로 바꾸는 것은
/// Supabase 에 넘기기 위한 내부 사정일 뿐이다. 화면에 이메일을 요구하거나
/// 보여주면 안 된다.
void main() {
  group('아이디 규칙', () {
    test('영문·숫자·밑줄 4~20자만 통과', () {
      expect(isValidId('surlap'), isTrue);
      expect(isValidId('sur_lap_2026'), isTrue);
      expect(isValidId('a1b2'), isTrue);
      expect(isValidId('A_Z_09'), isTrue);
    });

    test('너무 짧거나 길면 거부', () {
      expect(isValidId('abc'), isFalse);
      expect(isValidId('a' * 21), isFalse);
    });

    test('허용되지 않는 문자는 거부', () {
      expect(isValidId('surlap!'), isFalse);
      expect(isValidId('sur lap'), isFalse);
      expect(isValidId('서랩계정'), isFalse);
      expect(isValidId('user@mail.com'), isFalse,
          reason: '이메일을 아이디로 받지 않는다');
      expect(isValidId(''), isFalse);
    });
  });

  group('내부 이메일 변환', () {
    test('아이디를 소문자로 낮춰 합성 도메인을 붙인다', () {
      expect(idToEmail('Surlap'), 'surlap@cal-id.local');
      expect(idToEmail('  spaced  '), 'spaced@cal-id.local');
    });

    test('합성 이메일은 다시 아이디로 되돌아온다', () {
      expect(emailToId('surlap@cal-id.local'), 'surlap');
    });

    test('합성 도메인 판별', () {
      expect(isSyntheticEmail('surlap@cal-id.local'), isTrue);
      expect(isSyntheticEmail('me@gmail.com'), isFalse);
    });

    test('표시 이름은 합성 이메일을 아이디로 되돌려 보여준다', () {
      // 실제 User 객체 없이도 변환 규칙 자체를 고정해 둔다.
      expect(emailToId(idToEmail('minsu_01')), 'minsu_01');
    });

    test('외부 이메일은 그대로 둔다 — 소셜 로그인을 붙였을 때를 대비', () {
      expect(emailToId('me@gmail.com'), 'me@gmail.com');
    });
  });
}
