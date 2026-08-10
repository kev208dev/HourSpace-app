import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart' as du;

/// 하단 내비게이션의 5개 탭 — 디자인 핸드오프의 NAV 정의 그대로.
///
///   home    홈       ph-house
///   cal     캘린더    ph-calendar-blank  → 월 보기
///   todos   할 일     ph-check-square
///   shared  공유      ph-share-network
///   profile 내 정보   ph-user-circle
///
/// 학교(NEIS)는 전용 탭이 아니라 프로필 하위 진입점이다.
enum AppTab { home, calendar, todos, shared, profile }

/// 캘린더 탭 안의 보기 방식. 별도 화면이 아니라 같은 화면의 모드다.
enum CalendarViewMode { month, threeDay, day }

extension AppTabX on AppTab {
  String get label => switch (this) {
        AppTab.home => '홈',
        AppTab.calendar => '캘린더',
        AppTab.todos => '할 일',
        AppTab.shared => '공유',
        AppTab.profile => '내 정보',
      };
}

extension CalendarViewModeX on CalendarViewMode {
  String get label => switch (this) {
        CalendarViewMode.month => '월',
        CalendarViewMode.threeDay => '3일',
        CalendarViewMode.day => '하루',
      };
}

class ViewState {
  final AppTab tab;
  final CalendarViewMode calendarMode;

  /// 월간 그리드가 보고 있는 연·월.
  final int viewYear;
  final int viewMonth;

  /// 선택된 날짜 'YYYY-MM-DD'. 항상 값이 있다 — 아젠다·3일·하루 뷰의 기준.
  final String selectedDay;

  /// 탭 전환 애니메이션 방향 계산용.
  final AppTab? prevTab;

  const ViewState({
    this.tab = AppTab.home,
    this.calendarMode = CalendarViewMode.month,
    required this.viewYear,
    required this.viewMonth,
    required this.selectedDay,
    this.prevTab,
  });

  ViewState copyWith({
    AppTab? tab,
    CalendarViewMode? calendarMode,
    int? viewYear,
    int? viewMonth,
    String? selectedDay,
    AppTab? prevTab,
  }) =>
      ViewState(
        tab: tab ?? this.tab,
        calendarMode: calendarMode ?? this.calendarMode,
        viewYear: viewYear ?? this.viewYear,
        viewMonth: viewMonth ?? this.viewMonth,
        selectedDay: selectedDay ?? this.selectedDay,
        prevTab: prevTab ?? this.prevTab,
      );

  /// 슬라이드 방향: 1=왼쪽(뒤 탭으로), -1=오른쪽(앞 탭으로), 0=없음.
  int get slideDirection {
    if (prevTab == null || prevTab == tab) return 0;
    return tab.index > prevTab!.index ? 1 : -1;
  }
}

class ViewNotifier extends Notifier<ViewState> {
  @override
  ViewState build() {
    final now = DateTime.now();
    return ViewState(
      viewYear: now.year,
      viewMonth: now.month,
      selectedDay: du.toDateKey(now),
    );
  }

  void setTab(AppTab tab) {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab, prevTab: state.tab);
  }

  void setCalendarMode(CalendarViewMode mode) =>
      state = state.copyWith(calendarMode: mode);

  /// 날짜 선택 — 탭·보기 방식은 그대로 두고 기준 날짜만 바꾼다.
  /// 월간 뷰에서 다른 달의 날짜를 고르면 보고 있는 달도 따라간다.
  void selectDay(String dateKey) {
    final d = du.fromDateKey(dateKey);
    state = state.copyWith(
      selectedDay: dateKey,
      viewYear: d.year,
      viewMonth: d.month,
    );
  }

  /// 특정 날짜를 하루 보기로 연다(검색 결과 탭 등).
  void openDay(String dateKey) {
    final d = du.fromDateKey(dateKey);
    state = state.copyWith(
      tab: AppTab.calendar,
      calendarMode: CalendarViewMode.day,
      selectedDay: dateKey,
      viewYear: d.year,
      viewMonth: d.month,
      prevTab: state.tab,
    );
  }

  /// 특정 날짜를 3일 보기로 연다(월간 그리드에서 주 단위로 파고들 때).
  void openThreeDay(String dateKey) {
    final d = du.fromDateKey(dateKey);
    state = state.copyWith(
      tab: AppTab.calendar,
      calendarMode: CalendarViewMode.threeDay,
      selectedDay: dateKey,
      viewYear: d.year,
      viewMonth: d.month,
      prevTab: state.tab,
    );
  }

  void goToToday() {
    final now = DateTime.now();
    state = state.copyWith(
      viewYear: now.year,
      viewMonth: now.month,
      selectedDay: du.toDateKey(now),
    );
  }

  void prevMonth() {
    var m = state.viewMonth - 1;
    var y = state.viewYear;
    if (m < 1) {
      m = 12;
      y--;
    }
    state = state.copyWith(viewYear: y, viewMonth: m);
  }

  void nextMonth() {
    var m = state.viewMonth + 1;
    var y = state.viewYear;
    if (m > 12) {
      m = 1;
      y++;
    }
    state = state.copyWith(viewYear: y, viewMonth: m);
  }

  /// 현재 보기 방식 기준으로 한 칸 앞/뒤(월간=한 달, 3일=3일, 하루=하루).
  void step(int direction) {
    switch (state.calendarMode) {
      case CalendarViewMode.month:
        direction > 0 ? nextMonth() : prevMonth();
      case CalendarViewMode.threeDay:
        _shiftSelected(3 * direction);
      case CalendarViewMode.day:
        _shiftSelected(direction);
    }
  }

  void _shiftSelected(int days) {
    final d = du.fromDateKey(state.selectedDay).add(Duration(days: days));
    selectDay(du.toDateKey(d));
  }

  void prevYear() => state = state.copyWith(viewYear: state.viewYear - 1);
  void nextYear() => state = state.copyWith(viewYear: state.viewYear + 1);

  void setYearMonth(int year, int month) =>
      state = state.copyWith(viewYear: year, viewMonth: month);
}

final viewProvider =
    NotifierProvider<ViewNotifier, ViewState>(ViewNotifier.new);
