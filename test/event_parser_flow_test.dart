import 'package:flutter_test/flutter_test.dart';
import 'package:surlap/core/utils/event_parser.dart';

/// 자연어 우선 일정 입력(스펙 §11).
///
/// 파서가 알아듣는 범위를 고정해 둔다 — 모달은 입력할 때마다 이 결과를
/// 날짜·시각 필드에 바로 반영한다.
void main() {
  final base = DateTime(2026, 8, 10); // 월요일

  test('"내일 7시 수학학원" → 날짜 + 시각 + 제목', () {
    final p = parseEventInput('내일 7시 수학학원', now: base);
    expect(p.dateKey, '2026-08-11');
    expect(p.tm, isNotNull);
    expect(p.title, contains('수학학원'));
  });

  test('"금요일 7시 친구랑 영화" → 그 주 금요일', () {
    final p = parseEventInput('금요일 7시 친구랑 영화', now: base);
    expect(p.dateKey, '2026-08-14');
    expect(p.title, contains('영화'));
  });

  test('시작~종료 범위를 알아듣는다', () {
    final p = parseEventInput('내일 9시-10시 스터디', now: base);
    expect(p.tm, isNotNull);
    expect(p.te, isNotNull);
    expect(p.title, contains('스터디'));
  });

  test('날짜·시각 토큰이 없으면 제목만 남는다', () {
    final p = parseEventInput('장보기', now: base);
    expect(p.dateKey, isNull);
    expect(p.tm, isNull);
    expect(p.title, '장보기');
  });

  test('빈 입력은 아무것도 만들지 않는다', () {
    final p = parseEventInput('   ', now: base);
    expect(p.dateKey, isNull);
    expect(p.tm, isNull);
    expect(p.title.trim(), isEmpty);
  });

  test('해석해도 제목에서 날짜·시각 토큰은 빠진다', () {
    final p = parseEventInput('내일 오후 3시 치과', now: base);
    expect(p.title, isNot(contains('내일')));
    expect(p.title, isNot(contains('3시')));
    expect(p.title, contains('치과'));
  });
}
