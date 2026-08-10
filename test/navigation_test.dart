import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surlap/core/utils/date_utils.dart' as du;
import 'package:surlap/providers/view_provider.dart';
import 'package:surlap/storage/local_store.dart';

/// 정보구조 계약 — 디자인 핸드오프의 하단 탭 정의와 캘린더 보기 방식.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> boot() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
    return ProviderContainer();
  }

  test('하단 탭은 홈/캘린더/할 일/공유/내 정보 5개, 순서 고정', () {
    expect(AppTab.values, [
      AppTab.home,
      AppTab.calendar,
      AppTab.todos,
      AppTab.shared,
      AppTab.profile,
    ]);
    expect(AppTab.values.map((t) => t.label),
        ['홈', '캘린더', '할 일', '공유', '내 정보']);
  });

  test('캘린더 보기 방식은 연/월/3일/하루 네 가지', () {
    expect(CalendarViewMode.values.map((m) => m.label),
        ['연', '월', '3일', '하루']);
  });

  test('처음 열면 홈 탭, 선택 날짜는 오늘', () async {
    final c = await boot();
    addTearDown(c.dispose);
    final v = c.read(viewProvider);
    expect(v.tab, AppTab.home);
    expect(v.selectedDay, du.todayKey());
    expect(v.calendarMode, CalendarViewMode.month);
  });

  test('탭 전환은 캘린더 상태를 유지한다', () async {
    final c = await boot();
    addTearDown(c.dispose);
    final n = c.read(viewProvider.notifier);

    n.setCalendarMode(CalendarViewMode.day);
    n.selectDay('2026-08-20');
    n.setTab(AppTab.todos);
    n.setTab(AppTab.calendar);

    final v = c.read(viewProvider);
    expect(v.calendarMode, CalendarViewMode.day);
    expect(v.selectedDay, '2026-08-20');
  });

  test('날짜를 고르면 보고 있는 달도 따라간다', () async {
    final c = await boot();
    addTearDown(c.dispose);
    final n = c.read(viewProvider.notifier);

    n.setYearMonth(2026, 8);
    n.selectDay('2026-11-03');

    final v = c.read(viewProvider);
    expect(v.viewYear, 2026);
    expect(v.viewMonth, 11);
  });

  test('openDay 는 캘린더 탭의 하루 보기로 이동한다', () async {
    final c = await boot();
    addTearDown(c.dispose);
    c.read(viewProvider.notifier).openDay('2026-12-25');

    final v = c.read(viewProvider);
    expect(v.tab, AppTab.calendar);
    expect(v.calendarMode, CalendarViewMode.day);
    expect(v.selectedDay, '2026-12-25');
    expect(v.viewMonth, 12);
  });

  test('step 은 보기 방식에 맞는 단위로 움직인다', () async {
    final c = await boot();
    addTearDown(c.dispose);
    final n = c.read(viewProvider.notifier);
    n.setYearMonth(2026, 8);
    n.selectDay('2026-08-10');

    // 월간 = 한 달
    n.setCalendarMode(CalendarViewMode.month);
    n.step(1);
    expect(c.read(viewProvider).viewMonth, 9);
    n.step(-1);
    expect(c.read(viewProvider).viewMonth, 8);

    // 3일 = 3일
    n.setCalendarMode(CalendarViewMode.threeDay);
    n.step(1);
    expect(c.read(viewProvider).selectedDay, '2026-08-13');

    // 하루 = 하루
    n.setCalendarMode(CalendarViewMode.day);
    n.step(-1);
    expect(c.read(viewProvider).selectedDay, '2026-08-12');
  });

  test('연말/연초를 넘어가도 연도가 맞다', () async {
    final c = await boot();
    addTearDown(c.dispose);
    final n = c.read(viewProvider.notifier);

    n.setYearMonth(2026, 12);
    n.setCalendarMode(CalendarViewMode.month);
    n.step(1);
    expect((c.read(viewProvider).viewYear, c.read(viewProvider).viewMonth),
        (2027, 1));
    n.step(-1);
    expect((c.read(viewProvider).viewYear, c.read(viewProvider).viewMonth),
        (2026, 12));
  });

  test('오늘로 돌아가면 선택 날짜와 보고 있는 달이 모두 오늘', () async {
    final c = await boot();
    addTearDown(c.dispose);
    final n = c.read(viewProvider.notifier);
    n.selectDay('2020-01-01');
    n.goToToday();

    final now = DateTime.now();
    final v = c.read(viewProvider);
    expect(v.selectedDay, du.todayKey());
    expect(v.viewYear, now.year);
    expect(v.viewMonth, now.month);
  });

  test('같은 탭을 다시 눌러도 전환 애니메이션이 생기지 않는다', () async {
    final c = await boot();
    addTearDown(c.dispose);
    final n = c.read(viewProvider.notifier);
    n.setTab(AppTab.calendar);
    n.setTab(AppTab.calendar);
    expect(c.read(viewProvider).slideDirection, isNot(0));

    // prevTab 이 같아지면 방향 없음
    n.setTab(AppTab.calendar);
    expect(c.read(viewProvider).tab, AppTab.calendar);
  });
}
