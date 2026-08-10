import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/calendar/calendar_item.dart';
import 'package:surlap/core/calendar/calendar_repository.dart';
import 'package:surlap/core/calendar/period_times.dart';
import 'package:surlap/core/constants/storage_keys.dart';
import 'package:surlap/models/event_item.dart';
import 'package:surlap/providers/birthdays_provider.dart';
import 'package:surlap/providers/events_provider.dart';
import 'package:surlap/providers/filter_provider.dart';
import 'package:surlap/storage/local_store.dart';

/// 통합 캘린더 계층 계약 테스트.
///
/// 핵심 회귀 방지 대상: "캘린더를 OFF 하면 **모든** 뷰에서 사라진다"
/// (기존에는 화면마다 필터 적용 여부가 달랐다).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dateKey = '2026-08-10';
  const otherKey = '2026-08-11';

  Future<ProviderContainer> boot({
    Map<String, List<Map<String, dynamic>>> events = const {},
    List<String> hiddenCalendars = const [],
    List<Map<String, dynamic>> themes = const [],
    List<Map<String, dynamic>> birthdays = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'guest::${StorageKeys.events}': jsonEncode(events),
      'guest::${StorageKeys.themeFilter}': jsonEncode(hiddenCalendars),
      'guest::${StorageKeys.themes}': jsonEncode(themes),
      'guest::${StorageKeys.birthdays}': jsonEncode(birthdays),
    });
    await LocalStore.init();
    return ProviderContainer();
  }

  group('CalendarItem 변환', () {
    test('tm/te 가 있으면 시각이 붙고 종일이 아니다', () {
      final item = CalendarItem.fromEvent(
        const EventItem(t: '수학', tm: '11:00', te: '11:50'),
        day: DateTime(2026, 8, 10),
        source: CalendarSource.local,
        id: 'x',
      );
      expect(item.allDay, isFalse);
      expect(item.startAt, DateTime(2026, 8, 10, 11, 0));
      expect(item.endAt, DateTime(2026, 8, 10, 11, 50));
      expect(item.startHhmm, '11:00');
      expect(item.editable, isTrue);
    });

    test('tm 이 없으면 종일 항목이 되고 startAt 은 그 날 00:00', () {
      final item = CalendarItem.fromEvent(
        const EventItem(t: '개교기념일'),
        day: DateTime(2026, 8, 10),
        source: CalendarSource.schoolAcademic,
        id: 'x',
      );
      expect(item.allDay, isTrue);
      expect(item.startAt, DateTime(2026, 8, 10));
      expect(item.startHhmm, isNull);
      // 로컬이 아닌 소스는 편집 불가가 기본값
      expect(item.editable, isFalse);
    });

    test('isOngoingAt 은 시작 포함 종료 제외', () {
      final item = CalendarItem.fromEvent(
        const EventItem(t: '수학', tm: '11:00', te: '11:50'),
        day: DateTime(2026, 8, 10),
        source: CalendarSource.local,
        id: 'x',
      );
      expect(item.isOngoingAt(DateTime(2026, 8, 10, 11, 0)), isTrue);
      expect(item.isOngoingAt(DateTime(2026, 8, 10, 11, 49)), isTrue);
      expect(item.isOngoingAt(DateTime(2026, 8, 10, 11, 50)), isFalse);
      expect(item.isOngoingAt(DateTime(2026, 8, 10, 10, 59)), isFalse);
    });

    test('종료 시각이 없으면 한 교시 길이로 간주', () {
      final item = CalendarItem.fromEvent(
        const EventItem(t: '약속', tm: '15:00'),
        day: DateTime(2026, 8, 10),
        source: CalendarSource.local,
        id: 'x',
      );
      expect(
          item.isOngoingAt(
              DateTime(2026, 8, 10, 15, kPeriodMinutes - 1)),
          isTrue);
      expect(
          item.isOngoingAt(DateTime(2026, 8, 10, 15, kPeriodMinutes)), isFalse);
    });

    test('종일 항목은 겹침 판정에서 제외', () {
      final timed = CalendarItem.fromEvent(
        const EventItem(t: 'A', tm: '10:00', te: '12:00'),
        day: DateTime(2026, 8, 10),
        source: CalendarSource.local,
        id: 'a',
      );
      final allDay = CalendarItem.fromEvent(
        const EventItem(t: 'B'),
        day: DateTime(2026, 8, 10),
        source: CalendarSource.local,
        id: 'b',
      );
      expect(timed.overlaps(allDay), isFalse);
    });

    test('시간이 맞물리기만 하면 겹치지 않는다', () {
      CalendarItem at(String s, String e, String id) =>
          CalendarItem.fromEvent(EventItem(t: id, tm: s, te: e),
              day: DateTime(2026, 8, 10),
              source: CalendarSource.local,
              id: id);
      expect(at('10:00', '11:00', 'a').overlaps(at('11:00', '12:00', 'b')),
          isFalse);
      expect(at('10:00', '11:00', 'a').overlaps(at('10:59', '12:00', 'b')),
          isTrue);
    });
  });

  group('소스 규칙', () {
    test('편집 가능한 소스는 local 뿐', () {
      for (final s in CalendarSource.values) {
        expect(s.editable, s == CalendarSource.local, reason: '$s');
      }
    });

    test('충돌 검사는 시간을 점유하는 소스만 — 스포츠/생일/공휴일 제외', () {
      expect(CalendarSource.local.blocksTime, isTrue);
      expect(CalendarSource.schoolTimetable.blocksTime, isTrue);
      expect(CalendarSource.schoolAcademic.blocksTime, isTrue);
      expect(CalendarSource.shared.blocksTime, isTrue);
      expect(CalendarSource.sports.blocksTime, isFalse);
      expect(CalendarSource.birthday.blocksTime, isFalse);
      expect(CalendarSource.holiday.blocksTime, isFalse);
    });
  });

  group('교시 시각', () {
    test('1교시는 08:40, 4교시는 12:10에 끝난다', () {
      expect(periodTime(1), (8 * 60 + 40, 9 * 60 + 30));
      expect(periodTime(4), (11 * 60 + 40, 12 * 60 + 30));
    });

    test('5교시는 점심 뒤 13:30 시작', () {
      expect(periodTime(5).$1, 13 * 60 + 30);
      expect(lunchTime(), (12 * 60 + 30, 13 * 60 + 30));
    });

    test('hhmm 왕복', () {
      expect(hhmmToMinutes('07:05'), 7 * 60 + 5);
      expect(minutesToHhmm(7 * 60 + 5), '07:05');
      expect(hhmmToMinutes(''), isNull);
      expect(hhmmToMinutes(null), isNull);
      expect(hhmmToMinutes('abc'), isNull);
    });
  });

  group('Repository — 병합과 필터', () {
    test('로컬 일정이 CalendarItem 으로 나오고 시간 순 정렬된다', () async {
      final c = await boot(events: {
        dateKey: [
          {'t': '영어학원', 'tm': '14:00'},
          {'t': '준비물'},
          {'t': '수학', 'tm': '11:00', 'te': '11:50'},
        ],
      });
      addTearDown(c.dispose);

      final items = c.read(calendarItemsByDateProvider)[dateKey]!;
      expect(items.map((i) => i.title), ['준비물', '수학', '영어학원']);
      expect(items.first.allDay, isTrue); // 종일이 먼저
      expect(items.every((i) => i.source == CalendarSource.local), isTrue);
      expect(items.last.localIndex, 0); // 원본 배열 위치 보존
    });

    test('시간표 항목(tt)은 캘린더 병합에서 빠진다', () async {
      final c = await boot(events: {
        dateKey: [
          {'t': '수학', 'tt': true},
          {'t': '학원', 'tm': '17:00'},
        ],
      });
      addTearDown(c.dispose);

      final items = c.read(calendarItemsByDateProvider)[dateKey]!;
      expect(items.map((i) => i.title), ['학원']);
    });

    test('숨긴 캘린더는 통합 조회에서 사라진다', () async {
      final c = await boot(
        events: {
          dateKey: [
            {'t': '공부', 'tm': '09:00', 'th': 'study'},
            {'t': '학원', 'tm': '17:00', 'th': 'academy'},
          ],
        },
        themes: [
          {'id': 'study', 'name': '공부', 'color': '#3366ff'},
          {'id': 'academy', 'name': '학원', 'color': '#ff6633'},
        ],
        hiddenCalendars: ['study'],
      );
      addTearDown(c.dispose);

      final items = c.read(calendarItemsByDateProvider)[dateKey]!;
      expect(items.map((i) => i.title), ['학원']);
    });

    test('필터를 다시 켜면 복원된다', () async {
      final c = await boot(
        events: {
          dateKey: [
            {'t': '공부', 'tm': '09:00', 'th': 'study'},
          ],
        },
        themes: [
          {'id': 'study', 'name': '공부', 'color': '#3366ff'},
        ],
        hiddenCalendars: ['study'],
      );
      addTearDown(c.dispose);

      expect(c.read(calendarItemsByDateProvider)[dateKey], isNull);
      await c.read(filterProvider.notifier).toggle('study');
      expect(
          c.read(calendarItemsByDateProvider)[dateKey]!.map((i) => i.title),
          ['공부']);
    });

    test('테마 색이 CalendarItem.color 로 해석된다', () async {
      final c = await boot(
        events: {
          dateKey: [
            {'t': '공부', 'tm': '09:00', 'th': 'study'},
          ],
        },
        themes: [
          {'id': 'study', 'name': '공부', 'color': '#3366ff'},
        ],
      );
      addTearDown(c.dispose);

      final item = c.read(calendarItemsByDateProvider)[dateKey]!.single;
      expect(item.color, const Color(0xFF3366FF));
      expect(item.calendarId, 'study');
    });

    test('생일은 연/월/일이 맞는 날에 종일 항목으로 붙는다', () async {
      final c = await boot(
        events: {
          dateKey: [
            {'t': '아무거나', 'tm': '09:00'},
          ],
        },
        birthdays: [
          {'id': 'b1', 'name': '민수', 'month': 8, 'day': 10},
          {'id': 'b2', 'name': '지연', 'month': 8, 'day': 11},
        ],
      );
      addTearDown(c.dispose);

      final items = c.read(calendarItemsByDateProvider)[dateKey]!;
      final bdays =
          items.where((i) => i.source == CalendarSource.birthday).toList();
      expect(bdays.map((i) => i.title), ['민수']);
      expect(bdays.single.allDay, isTrue);
      expect(bdays.single.editable, isFalse);
    });

    test('생일 캘린더를 끄면 생일이 사라진다', () async {
      final c = await boot(
        events: {
          dateKey: [
            {'t': '아무거나', 'tm': '09:00'},
          ],
        },
        birthdays: [
          {'id': 'b1', 'name': '민수', 'month': 8, 'day': 10},
        ],
        hiddenCalendars: [birthdayThemeId],
      );
      addTearDown(c.dispose);

      final items = c.read(calendarItemsByDateProvider)[dateKey]!;
      expect(items.any((i) => i.source == CalendarSource.birthday), isFalse);
    });

    test('일정이 없는 날에도 하루 조회는 생일을 보여준다', () async {
      final c = await boot(
        birthdays: [
          {'id': 'b1', 'name': '민수', 'month': 8, 'day': 11},
        ],
      );
      addTearDown(c.dispose);

      // 통합 맵에는 그 날짜 자체가 없지만
      expect(c.read(calendarItemsByDateProvider)[otherKey], isNull);
      // 하루 조회는 보강한다
      final day = c.read(calendarDayProvider(otherKey));
      expect(day.map((i) => i.title), contains('민수'));
    });

    test('잘못된 날짜 키는 조용히 무시된다', () async {
      final c = await boot(events: {
        '__meta': [
          {'t': '무시'},
        ],
        dateKey: [
          {'t': '정상', 'tm': '09:00'},
        ],
      });
      addTearDown(c.dispose);

      final map = c.read(calendarItemsByDateProvider);
      expect(map.containsKey('__meta'), isFalse);
      expect(map[dateKey]!.single.title, '정상');
      expect(c.read(calendarDayProvider('not-a-date')), isEmpty);
    });
  });

  group('반복 일정', () {
    test('주간 반복은 앵커 + 전개분이 각각 나온다', () async {
      final anchor = DateTime.now().add(const Duration(days: 1));
      final anchorKey =
          '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}-${anchor.day.toString().padLeft(2, '0')}';
      final next = anchor.add(const Duration(days: 7));
      final nextKey =
          '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';

      final c = await boot(events: {
        anchorKey: [
          {
            't': '주간회의',
            'tm': '09:00',
            'rr': {'f': 'W'},
          },
        ],
      });
      addTearDown(c.dispose);

      final map = c.read(calendarItemsByDateProvider);
      expect(map[anchorKey]!.single.title, '주간회의');
      expect(map[anchorKey]!.single.editable, isTrue);

      final occurrence = map[nextKey]!.single;
      expect(occurrence.title, '주간회의');
      // 전개된 occurrence 는 앵커를 고쳐야 하므로 직접 편집 대상이 아니다
      expect(occurrence.editable, isFalse);
      expect(occurrence.metadata['recurringOccurrence'], isTrue);
      expect(occurrence.startAt.hour, 9);
    });
  });

  group('events 저장 포맷 보존', () {
    test('EventItem 왕복에서 tm/te/rr/id 가 유지된다', () {
      const e = EventItem(
        t: '수학',
        tm: '11:00',
        te: '11:50',
        th: 'study',
        id: 'e1',
        createdAt: '2026-08-10T00:00:00.000',
        rr: {'f': 'W', 'i': 2},
      );
      final back = EventItem.fromJson(e.toJson());
      expect(back.t, e.t);
      expect(back.tm, e.tm);
      expect(back.te, e.te);
      expect(back.th, e.th);
      expect(back.id, e.id);
      expect(back.createdAt, e.createdAt);
      expect(back.rr, e.rr);
    });
  });
}
