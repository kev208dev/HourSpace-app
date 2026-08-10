import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/constants/storage_keys.dart';
import 'package:surlap/models/event_item.dart';
import 'package:surlap/providers/events_provider.dart';
import 'package:surlap/storage/local_store.dart';
import 'package:surlap/supabase/events_sync.dart';
import 'package:surlap/utils/notification_ids.dart';

/// 사용자 데이터를 잃게 만들던 결함들에 대한 회귀 테스트.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> boot(
      Map<String, List<Map<String, dynamic>>> events) async {
    SharedPreferences.setMockInitialValues({
      'guest::${StorageKeys.events}': jsonEncode(events),
    });
    await LocalStore.init();
    return ProviderContainer();
  }

  group('일정 날짜 변경 (스펙 §25)', () {
    const from = '2026-08-10';
    const to = '2026-08-11';

    test('옛 날짜에서 빠지고 새 날짜에 들어간다 — 중복 없음', () async {
      final c = await boot({
        from: [
          {'t': '수학', 'tm': '11:00'},
        ],
      });
      addTearDown(c.dispose);

      final notifier = c.read(eventsProvider.notifier);
      await notifier.moveEvent(
          from, 0, to, const EventItem(t: '수학', tm: '11:00'));

      final state = c.read(eventsProvider);
      expect(state[from], isNull, reason: '비면 날짜 키 자체가 사라져야 한다');
      expect(state[to]!.map((e) => e.t), ['수학']);
    });

    test('같은 날 다른 일정은 건드리지 않는다', () async {
      final c = await boot({
        from: [
          {'t': '수학', 'tm': '11:00'},
          {'t': '영어', 'tm': '14:00'},
        ],
      });
      addTearDown(c.dispose);

      await c
          .read(eventsProvider.notifier)
          .moveEvent(from, 0, to, const EventItem(t: '수학', tm: '11:00'));

      final state = c.read(eventsProvider);
      expect(state[from]!.map((e) => e.t), ['영어']);
      expect(state[to]!.map((e) => e.t), ['수학']);
    });

    test('대상 날짜에 이미 일정이 있으면 뒤에 붙는다 — 덮어쓰지 않는다', () async {
      final c = await boot({
        from: [
          {'t': '수학', 'tm': '11:00'},
        ],
        to: [
          {'t': '기존 일정', 'tm': '09:00'},
        ],
      });
      addTearDown(c.dispose);

      await c
          .read(eventsProvider.notifier)
          .moveEvent(from, 0, to, const EventItem(t: '수학', tm: '11:00'));

      expect(c.read(eventsProvider)[to]!.map((e) => e.t),
          ['기존 일정', '수학']);
    });

    test('같은 날짜로 옮기면 제자리 수정', () async {
      final c = await boot({
        from: [
          {'t': '수학', 'tm': '11:00'},
          {'t': '영어', 'tm': '14:00'},
        ],
      });
      addTearDown(c.dispose);

      await c.read(eventsProvider.notifier).moveEvent(
          from, 0, from, const EventItem(t: '수학 보충', tm: '11:00'));

      expect(c.read(eventsProvider)[from]!.map((e) => e.t),
          ['수학 보충', '영어']);
    });

    test('범위를 벗어난 인덱스는 아무것도 바꾸지 않는다', () async {
      final c = await boot({
        from: [
          {'t': '수학', 'tm': '11:00'},
        ],
      });
      addTearDown(c.dispose);

      await c
          .read(eventsProvider.notifier)
          .moveEvent(from, 5, to, const EventItem(t: '엉뚱'));
      await c
          .read(eventsProvider.notifier)
          .moveEvent(from, -1, to, const EventItem(t: '엉뚱'));

      final state = c.read(eventsProvider);
      expect(state[from]!.map((e) => e.t), ['수학']);
      expect(state[to], isNull);
    });

    test('시각·반복 규칙이 이동 후에도 보존된다', () async {
      final c = await boot({
        from: [
          {
            't': '수학',
            'tm': '11:00',
            'te': '11:50',
            'rr': {'f': 'W'},
          },
        ],
      });
      addTearDown(c.dispose);

      final original = c.read(eventsProvider)[from]!.single;
      await c.read(eventsProvider.notifier).moveEvent(from, 0, to, original);

      final moved = c.read(eventsProvider)[to]!.single;
      expect(moved.tm, '11:00');
      expect(moved.te, '11:50');
      expect(moved.rr, {'f': 'W'});
    });
  });

  group('클라우드 동기화 무손실 (스펙 §24)', () {
    setUp(EventsSync.resetPayloadSupportForTest);

    test('payload 왕복에서 tm/te/rr/id/created_at 가 살아남는다', () {
      const e = EventItem(
        t: '수학',
        tm: '11:00',
        te: '11:50',
        th: 'study',
        id: 'e1',
        createdAt: '2026-08-10T00:00:00.000',
        rr: {'f': 'W', 'i': 2, 'u': '2026-12-31'},
      );
      final row = EventsSync.itemToRow('2026-08-10', e, 0, 'u1');
      final back = EventsSync.rowToItem(row);

      expect(back.tm, '11:00', reason: '예전 스키마에서는 시각이 통째로 사라졌다');
      expect(back.te, '11:50');
      expect(back.rr, {'f': 'W', 'i': 2, 'u': '2026-12-31'});
      expect(back.id, 'e1');
      expect(back.createdAt, '2026-08-10T00:00:00.000');
      expect(back.themeIds, ['study']);
    });

    test('다중 캘린더(th 리스트)도 보존된다', () {
      const e = EventItem(t: '스터디', tm: '19:00', th: ['study', 'club']);
      final back =
          EventsSync.rowToItem(EventsSync.itemToRow('2026-08-10', e, 0, 'u1'));
      expect(back.themeIds, ['study', 'club']);
    });

    test('레거시 컬럼도 계속 채워 웹 클라이언트 호환을 유지한다', () {
      const e = EventItem(t: '수학', tm: '11:00', th: 'study');
      final row = EventsSync.itemToRow('2026-08-10', e, 3, 'u1');
      expect(row['title'], '수학');
      expect(row['theme_id'], 'study');
      expect(row['position'], 3);
      expect(row['date'], '2026-08-10');
      expect(row['user_id'], 'u1');
    });

    test('payload 없는 구버전 행은 레거시 컬럼으로 복원된다', () {
      final back = EventsSync.rowToItem({
        'date': '2026-08-10',
        'title': '옛 일정',
        'is_timetable': false,
        'theme_id': 'study',
        'position': 0,
      });
      expect(back.t, '옛 일정');
      expect(back.themeIds, ['study']);
      expect(back.tm, isNull);
    });

    test('payload 컬럼이 없는 서버로는 payload 없이 보낸다', () {
      const e = EventItem(t: '수학', tm: '11:00');
      final row = EventsSync.itemToRow('2026-08-10', e, 0, 'u1',
          includePayload: false);
      expect(row.containsKey('payload'), isFalse);
      expect(row['title'], '수학');
    });
  });

  group('백업 대상 키 (스펙 §23)', () {
    test('사용자가 만든 계정 데이터가 전부 포함된다', () {
      for (final k in StorageKeys.accountKeys) {
        expect(StorageKeys.backupKeys, contains(k), reason: k);
      }
    });

    test('할 일·생일·스포츠 구독·기록 템플릿·직접 입력 시간표가 들어 있다', () {
      expect(StorageKeys.backupKeys, contains(StorageKeys.todos));
      expect(StorageKeys.backupKeys, contains(StorageKeys.birthdays));
      expect(
          StorageKeys.backupKeys, contains(StorageKeys.sportsSubscriptions));
      expect(StorageKeys.backupKeys, contains(StorageKeys.recordTemplates));
      expect(
          StorageKeys.backupKeys, contains(StorageKeys.recordTemplateRanges));
      expect(StorageKeys.backupKeys, contains(StorageKeys.timetableWeekly));
    });

    test('자격증명과 재요청 가능한 캐시는 백업하지 않는다', () {
      for (final k in [
        StorageKeys.savedAuthId,
        StorageKeys.savedAuthPw,
        StorageKeys.neisCache,
        StorageKeys.neisAcademic,
        StorageKeys.sportsEventsCache,
        StorageKeys.sharedThemeEvents,
      ]) {
        expect(StorageKeys.backupKeys, isNot(contains(k)), reason: k);
      }
    });

    test('할 일이 클라우드 동기화 대상에 들어 있다', () {
      expect(StorageKeys.userDataKeys, contains(StorageKeys.todos));
    });
  });

  group('알림 ID 대역 (스펙 §22)', () {
    test('모든 계통의 대역이 서로 겹치지 않는다', () {
      const bases = {
        'sports': NotificationIds.sportsBase,
        'event': NotificationIds.eventBase,
        'briefing': NotificationIds.briefingBase,
        'birthday': NotificationIds.birthdayBase,
        'birthdayAhead': NotificationIds.birthdayAheadBase,
        'themeShare': NotificationIds.themeShareBase,
      };
      final entries = bases.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final a = entries[i], b = entries[j];
          final overlap = a.value <= b.value + NotificationIds.mask &&
              b.value <= a.value + NotificationIds.mask;
          expect(overlap, isFalse, reason: '${a.key} 와 ${b.key} 대역이 겹친다');
        }
      }
    });

    test('forKey 는 항상 자기 대역 안에 든다', () {
      for (final key in ['a', '생일-민수', 'e1|11:00', '']) {
        final id = NotificationIds.forKey(NotificationIds.birthdayBase, key);
        expect(NotificationIds.isInRange(id, NotificationIds.birthdayBase),
            isTrue);
        expect(NotificationIds.isInRange(id, NotificationIds.eventBase),
            isFalse);
      }
    });

    test('forKey 는 같은 키에 대해 같은 ID를 준다', () {
      expect(
        NotificationIds.forKey(NotificationIds.eventBase, 'e1|11:00'),
        NotificationIds.forKey(NotificationIds.eventBase, 'e1|11:00'),
      );
    });

    test('같은 생일이라도 당일과 D-N 은 서로 다른 ID', () {
      expect(
        NotificationIds.forKey(NotificationIds.birthdayBase, 'b1'),
        isNot(NotificationIds.forKey(NotificationIds.birthdayAheadBase, 'b1')),
      );
    });
  });
}
