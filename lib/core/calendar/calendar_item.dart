import 'package:flutter/material.dart';

import '../../models/event_item.dart';
import 'period_times.dart';

/// 캘린더에 올라오는 데이터의 출처.
///
/// 기존 코드는 이 구분을 `EventItem`의 직렬화 제외 bool 플래그
/// (`academic` / `birthday` / `sport`)와 sentinel 테마 id(`__academic__`,
/// `__birthday__`, `holidays`)로 흩어서 표현했다. 이 enum이 그 표현을 대체한다.
enum CalendarSource {
  /// 사용자가 만든 일정 — 유일하게 편집 가능한 소스.
  local,

  /// NEIS 시간표 / 직접 입력한 주간 시간표.
  schoolTimetable,

  /// NEIS 학사일정.
  schoolAcademic,

  /// 구독 중인 공유 캘린더.
  shared,

  /// 스포츠 구독 경기.
  sports,

  /// 생일.
  birthday,

  /// 공휴일.
  holiday,
}

extension CalendarSourceX on CalendarSource {
  /// 사용자가 이 소스의 항목을 직접 수정/삭제할 수 있는가.
  bool get editable => this == CalendarSource.local;

  /// 일정 충돌 검사에 참여하는가.
  ///
  /// 스포츠·생일·공휴일은 "그날 그런 일이 있다"는 정보일 뿐 사용자를 물리적으로
  /// 묶어두지 않으므로 기본 제외한다(스펙 §12).
  bool get blocksTime =>
      this == CalendarSource.local ||
      this == CalendarSource.schoolTimetable ||
      this == CalendarSource.schoolAcademic ||
      this == CalendarSource.shared;

  /// 화면에 붙는 소스 배지 문구.
  String get badgeLabel => switch (this) {
        CalendarSource.local => '개인',
        CalendarSource.schoolTimetable => '학교',
        CalendarSource.schoolAcademic => '학교',
        CalendarSource.shared => '공유',
        CalendarSource.sports => '스포츠',
        CalendarSource.birthday => '생일',
        CalendarSource.holiday => '공휴일',
      };
}

/// 모든 캘린더 뷰가 공유하는 단일 표시 모델.
///
/// **저장 모델이 아니다.** 로컬 일정의 저장 포맷은 계속 [EventItem]
/// (웹 localStorage 호환)이고, [CalendarItem]은 그 위에 얹는 읽기 전용 뷰
/// 모델이다. 쓰기는 [event]/[dateKey]를 통해 원래 경로로 돌아간다.
@immutable
class CalendarItem {
  /// 소스 안에서 안정적인 식별자. 로컬은 `local:{dateKey}#{index}`,
  /// 반복 전개분은 `recur:{anchorKey}#{index}@{dateKey}` 형태.
  final String id;

  final String title;

  /// 시작 시각. 종일 항목은 그 날 00:00.
  final DateTime startAt;

  /// 종료 시각. 없으면 null(시점 일정 또는 종일).
  final DateTime? endAt;

  final bool allDay;

  final CalendarSource source;

  /// 원본 참조 — 로컬은 저장된 dateKey, 공유는 테마 id, 스포츠는 구독 id 등.
  final String? sourceId;

  /// 이 항목이 속한 캘린더(=기존 테마) id. 필터 ON/OFF의 단위.
  final String? calendarId;

  final bool editable;

  final Color? color;

  /// 반복 규칙(기존 `EventItem.rr`). 전개된 occurrence에는 붙이지 않는다.
  final Map<String, dynamic>? recurrenceRule;

  /// 소스별 부가 정보(스포츠 이모지/로고, 교시 번호 등).
  final Map<String, dynamic> metadata;

  final String? createdAt;
  final String? updatedAt;

  /// 로컬 편집 경로용 원본. [source]가 local일 때만 채워진다.
  final EventItem? event;

  /// 로컬 저장 배열에서의 위치. [source]가 local일 때만 유효.
  final int? localIndex;

  const CalendarItem({
    required this.id,
    required this.title,
    required this.startAt,
    required this.source,
    this.endAt,
    this.allDay = false,
    this.sourceId,
    this.calendarId,
    bool? editable,
    this.color,
    this.recurrenceRule,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
    this.event,
    this.localIndex,
  }) : editable = editable ?? (source == CalendarSource.local);

  /// 'YYYY-MM-DD' — 이 항목이 걸리는 날짜.
  String get dateKey =>
      '${startAt.year}-${_pad(startAt.month)}-${_pad(startAt.day)}';

  /// 시각이 있는 항목인가(종일이 아님).
  bool get hasTime => !allDay;

  /// 'HH:MM' 시작 표기. 종일이면 null.
  String? get startHhmm =>
      allDay ? null : '${_pad(startAt.hour)}:${_pad(startAt.minute)}';

  /// 'HH:MM' 종료 표기. 없으면 null.
  String? get endHhmm => endAt == null
      ? null
      : '${_pad(endAt!.hour)}:${_pad(endAt!.minute)}';

  /// [at] 시점에 진행 중인가. 종료가 없으면 시작 후 [kPeriodMinutes]분 동안으로 본다.
  bool isOngoingAt(DateTime at) {
    if (allDay) return false;
    final end =
        endAt ?? startAt.add(const Duration(minutes: kPeriodMinutes));
    return !at.isBefore(startAt) && at.isBefore(end);
  }

  /// [other]와 시간이 겹치는가. 둘 중 하나라도 종일이면 겹침으로 보지 않는다.
  bool overlaps(CalendarItem other) {
    if (allDay || other.allDay) return false;
    final aEnd = endAt ?? startAt.add(const Duration(minutes: kPeriodMinutes));
    final bEnd = other.endAt ??
        other.startAt.add(const Duration(minutes: kPeriodMinutes));
    return startAt.isBefore(bEnd) && other.startAt.isBefore(aEnd);
  }

  CalendarItem copyWith({
    String? id,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    CalendarSource? source,
    String? sourceId,
    String? calendarId,
    bool? editable,
    Color? color,
    Map<String, dynamic>? recurrenceRule,
    Map<String, dynamic>? metadata,
    String? createdAt,
    String? updatedAt,
    EventItem? event,
    int? localIndex,
  }) =>
      CalendarItem(
        id: id ?? this.id,
        title: title ?? this.title,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        allDay: allDay ?? this.allDay,
        source: source ?? this.source,
        sourceId: sourceId ?? this.sourceId,
        calendarId: calendarId ?? this.calendarId,
        editable: editable ?? this.editable,
        color: color ?? this.color,
        recurrenceRule: recurrenceRule ?? this.recurrenceRule,
        metadata: metadata ?? this.metadata,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        event: event ?? this.event,
        localIndex: localIndex ?? this.localIndex,
      );

  /// [EventItem] → [CalendarItem]. `day`는 이 항목이 표시될 날짜.
  ///
  /// 시각 파싱은 여기 한 곳에서만 한다 — 화면마다 `tm`을 직접 자르던 코드를
  /// 이 변환으로 대체한다.
  factory CalendarItem.fromEvent(
    EventItem e, {
    required DateTime day,
    required CalendarSource source,
    required String id,
    String? sourceId,
    Color? color,
    int? localIndex,
    Map<String, dynamic> metadata = const {},
  }) {
    final startMin = hhmmToMinutes(e.tm);
    final endMin = hhmmToMinutes(e.te);
    final base = DateTime(day.year, day.month, day.day);
    return CalendarItem(
      id: id,
      title: e.t,
      startAt: startMin == null
          ? base
          : base.add(Duration(minutes: startMin)),
      endAt: endMin == null ? null : base.add(Duration(minutes: endMin)),
      allDay: startMin == null,
      source: source,
      sourceId: sourceId,
      calendarId: e.themeIds.isEmpty ? null : e.themeIds.first,
      color: color,
      recurrenceRule: e.rr,
      metadata: metadata,
      createdAt: e.createdAt,
      event: source == CalendarSource.local ? e : null,
      localIndex: source == CalendarSource.local ? localIndex : null,
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

/// 종일 먼저, 그 다음 시작 시각 오름차순. 같으면 제목순.
int compareCalendarItems(CalendarItem a, CalendarItem b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  final t = a.startAt.compareTo(b.startAt);
  if (t != 0) return t;
  return a.title.compareTo(b.title);
}
