import 'package:flutter_test/flutter_test.dart';
import 'package:surlap/models/user_type.dart';

/// 학교 연결 (핸드오프 F1 · spec §12).
///
/// 학교를 먼저 고르면 학교 종류에서 사용자 유형을 유추한다.
/// 초등 1–6학년, 중·고 1–3학년.
void main() {
  group('학교 종류 → 사용자 유형 유추', () {
    test('초·중·고를 각각 알아본다', () {
      expect(inferUserType('초등학교'), UserType.elementary);
      expect(inferUserType('중학교'), UserType.middle);
      expect(inferUserType('고등학교'), UserType.high);
    });

    test('NEIS 가 주는 긴 표기도 처리한다', () {
      expect(inferUserType('사립 초등학교'), UserType.elementary);
      expect(inferUserType('공립 고등학교'), UserType.high);
    });

    test('판단이 서지 않으면 null — 사용자가 직접 고르게 둔다', () {
      expect(inferUserType('각종학교'), isNull);
      expect(inferUserType(''), isNull);
      expect(inferUserType('대학교'), isNull);
    });
  });

  group('급식·시간표 사용 여부', () {
    test('초·중·고만 NEIS 기능을 쓴다', () {
      expect(UserType.elementary.usesMeal, isTrue);
      expect(UserType.middle.usesMeal, isTrue);
      expect(UserType.high.usesMeal, isTrue);
    });

    test('일반·대학생은 쓰지 않는다', () {
      expect(UserType.general.usesMeal, isFalse);
      expect(UserType.university.usesMeal, isFalse);
    });
  });
}
