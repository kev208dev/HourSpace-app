// 웹 localStorage 키와 완전히 동일하게 유지 — 절대 변경 금지.
abstract final class StorageKeys {
  static const events        = 'handwriting-calendar-events-v1';
  static const eventsMirror  = 'calendar-events-v1';
  static const themes        = 'calendar-themes-v1';
  static const colorPreset   = 'calendar-color-preset-v1';
  static const motto         = 'calendar-motto-v1';
  static const mottoIcon     = 'calendar-motto-icon-v1';
  static const starred       = 'calendar-starred-dates-v1';
  static const memos         = 'calendar-memos-v1';
  static const circles       = 'calendar-circles-v1';
  static const continuousView = 'calendar-continuous-view-v1';
  static const showTimetable = 'calendar-show-timetable-v1';
  static const weekStart     = 'calendar-week-start-v1';
  static const notifyEnabled = 'calendar-notify-enabled-v1';
  static const themeFilter   = 'calendar-theme-filter-v1';
  static const dayTemplates  = 'calendar-day-templates-v1';
  static const dayWidgetValues = 'calendar-day-widget-values-v1';
  // 기록 템플릿 적용 기간 — { id, templateId, start, end } 배열.
  static const recordTemplateRanges = 'calendar-record-template-ranges-v1';
  // 사용자 정의 기록 템플릿(프리셋 제외 — 커스텀만 저장).
  static const recordTemplates = 'calendar-record-templates-v1';
  // 기록 데이터 필드 마이그레이션(공부 studyHours→primary 등) 완료 플래그.
  static const recordMigratedV1 = 'calendar-record-migrated-v1';
  // 스포츠 구독 — { id, sport, leagueId, teamId, color, enabled, ... } 배열.
  static const sportsSubscriptions = 'calendar-sports-subscriptions-v1';
  // 스포츠 경기 일정 로컬 캐시(구독별). 재요청 가능 — 동기화 대상 아님.
  static const sportsEventsCache = 'calendar-sports-events-cache-v1';
  // 구독 중인 공유 테마의 일정 캐시(테마id별). 재수신 가능 — 동기화 대상 아님.
  static const sharedThemeEvents = 'calendar-shared-theme-events-v1';
  static const timetableTemplate  = 'calendar-timetable-template-v1';
  static const timetableOverrides = 'calendar-timetable-overrides-v1';
  // 시간표 직접 입력 — 요일(0=월..6=일)×시각으로 매주 반복 저장.
  static const timetableWeekly    = 'calendar-timetable-weekly-v1';
  // 할 일(Todo) — 일정과 분리된 별도 목록.
  static const todos         = 'calendar-todos-v1';
  // 온보딩 시청 여부 — 기기 설정값(계정 스코프 제외).
  static const hasSeenOnboarding = 'calendar-has-seen-onboarding-v1';
  // 앱 언어(ko/en/ja/zh/es) — 기기 설정값. null이면 아직 미선택(언어 선택 화면 표시).
  static const appLang       = 'calendar-app-lang-v1';
  // 테마 관리 활용 팁 — 처음 1회만 노출.
  static const themeTipSeen  = 'calendar-theme-tip-seen-v1';
  // 달력 길게 누르기 힌트 — 처음 1회만 노출.
  static const longPressHintSeen = 'calendar-longpress-hint-seen-v1';
  // 생일 알림 설정 — 기기 설정값.
  static const birthdayNotifyEnabled = 'calendar-bday-notify-enabled-v1';
  static const birthdayNotifyDaysBefore = 'calendar-bday-notify-days-v1';
  // 일정 알림 설정 — 기기 설정값.
  static const eventNotifyEnabled = 'calendar-event-notify-enabled-v1';
  static const eventNotifyLeadMinutes = 'calendar-event-notify-lead-v1';
  // 시간표 빈 교시 라벨(자습/공강 등) — 빈 문자열이면 표시 안 함.
  static const timetableEmptyLabel = 'calendar-timetable-empty-label-v1';
  // 오늘의 브리핑 알림.
  static const briefingEnabled = 'calendar-briefing-enabled-v1';
  static const briefingHour = 'calendar-briefing-hour-v1';
  static const cellDesign    = 'calendar-cell-design-v1';
  // 달력 한 칸 높이 배율 — 0.8 ~ 1.4. 1.0 기본. 1.0 미만은 자동 분배, 초과는 스크롤.
  static const monthCellHeightFactor = 'calendar-month-cell-height-v1';
  static const neisSchool    = 'calendar-neis-school-v1';
  // 사용자 유형(일반인/초·중·고·대) — 로그인 없이 기기에 저장. 온보딩에서 선택.
  static const userType      = 'calendar-user-type-v1';
  // NEIS 시간표/급식 로컬 캐시(주 단위). 재요청 가능하므로 동기화 대상 아님.
  static const neisCache     = 'calendar-neis-cache-v1';
  // NEIS 학사일정 로컬 캐시(연 단위). 재요청 가능 — 동기화 대상 아님.
  static const neisAcademic  = 'calendar-neis-academic-v1';
  static const birthdays     = 'calendar-birthdays-v1';
  static const userProfile   = 'calendar-user-profile-v2';
  static const backupConfig  = 'calendar-backup-config-v1';
  static const supabaseHashes = 'calendar_supabase_hashes_v1';

  // [폐기] 예전 버전이 자동 로그인용으로 저장하던 자격증명.
  // 비밀번호를 base64(= 평문과 다름없음)로 담고 있었다. 더 이상 쓰지 않으며
  // AuthNotifier.purgeLegacyCredentials() 가 앱 시작 시 삭제한다.
  // 세션 유지는 supabase_flutter 의 리프레시 토큰이 담당한다.
  // 절대 백업/동기화 대상에 넣지 말 것.
  static const savedAuthId   = 'calendar-saved-auth-id-v1';
  static const savedAuthPw   = 'calendar-saved-auth-pw-v1';

  /// 계정 종속 데이터 키 — 계정별로 분리 저장(스코프 프리픽스)된다.
  /// 기기 설정성 키(colorPreset, weekStart, continuousView, notifyEnabled,
  /// show-past)는 제외 — 기기에 그대로 남는다.
  static const Set<String> accountKeys = {
    events, themes, memos, starred, circles, themeFilter, cellDesign,
    motto, mottoIcon, dayTemplates, dayWidgetValues, recordTemplateRanges,
    recordTemplates,
    timetableTemplate, timetableOverrides, timetableWeekly, birthdays, neisSchool,
    todos, sportsSubscriptions,
  };

  /// user_data KV 테이블로 동기화하는 키 (events 는 별도 events 테이블이라 제외).
  ///
  /// todos 가 빠져 있어서 할 일은 기기를 바꾸면 사라졌다 — 계정 데이터이므로 포함한다.
  static const Set<String> userDataKeys = {
    themes, memos, starred, circles, themeFilter, cellDesign,
    motto, mottoIcon, dayTemplates, dayWidgetValues, recordTemplateRanges,
    recordTemplates,
    timetableTemplate, timetableOverrides, timetableWeekly, birthdays, neisSchool,
    sportsSubscriptions, todos,
  };

  /// 파일 백업/복원 대상 키.
  ///
  /// 사용자가 만든 계정 데이터 전체([accountKeys]) + 되살릴 가치가 있는 기기
  /// 설정. 예전에는 11개만 담아서 할 일·생일·스포츠 구독·기록 템플릿·직접 입력
  /// 시간표가 백업에 들어가지 않았는데도 UI 는 "백업 완료"라고 표시했다.
  ///
  /// 재요청 가능한 캐시(neisCache, neisAcademic, sportsEventsCache,
  /// sharedThemeEvents)와 자격증명은 의도적으로 제외한다.
  static const Set<String> backupKeys = {
    ...accountKeys,
    userProfile,
    continuousView,
    weekStart,
    showTimetable,
    timetableEmptyLabel,
    monthCellHeightFactor,
    colorPreset,
    recordMigratedV1,
  };
}
