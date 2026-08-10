# Surlap 2.0 — 리팩터링 분석 및 마이그레이션 계획

> 제품 정의: **학교생활까지 자동으로 들어오는 학생용 캘린더**
> 목표: 기능은 유지, 사용자가 느끼는 복잡도는 절반 이하.

작성 시점 기준 브랜치: `surlap-2.0` (베이스: `7b07a39`)
분석 대상: Flutter 3.44.1 / Dart SDK ^3.11.4 / Riverpod 2.6 / SharedPreferences / Supabase 2.12
규모: `lib/**.dart` 147개 파일, 약 29,500 LOC

---

## 1. 현행 아키텍처 실측

### 1.1 스택

| 영역 | 현행 |
|---|---|
| 상태관리 | `flutter_riverpod` (`Notifier` / `Provider`) — 코드젠 미사용, 수동 provider |
| 로컬 저장 | `SharedPreferences` 단일 백엔드, `LocalStore` 래퍼 |
| 계정 분리 | `LocalStore._scope` (`guest` / `user_{uid}`) 키 프리픽스 |
| 원격 | Supabase (`events` 테이블 + `user_data` KV 테이블 + Realtime 공유) |
| 학교 데이터 | NEIS OpenAPI 직접 호출 (`lib/supabase/neis_service.dart`) |
| 라우팅 | **라우터 없음.** `MainShell` + `ViewMode` enum + `AnimatedSwitcher` 단일 셸 |
| 내비게이션 | (베이스 커밋에서) 좌상단 햄버거 + `Drawer` |
| 폰트 | Pretendard (로컬 asset) + Space Grotesk(워드마크만, google_fonts) |

라우터가 없다는 점이 중요하다. 화면 전환은 `viewProvider.setMode()` 한 곳을 지나고,
모달은 전부 `showModalBottomSheet` 직접 호출이다. → **5탭 재편이 라우팅 리팩터를 요구하지 않는다.**
`ViewMode` enum과 `MainShell._buildView` 스위치만 바꾸면 된다.

### 1.2 저장 포맷 (변경 금지 영역)

`StorageKeys`는 웹 버전 localStorage와 키 이름이 동일하다. 파일 상단에 "절대 변경 금지" 주석이 있고,
백업 파일·클라우드 KV·웹 클라이언트가 이 키를 공유한다. **키 이름과 JSON 형태는 유지한다.**

일정 저장 형태:

```
'handwriting-calendar-events-v1' → { "YYYY-MM-DD": [ EventItem, ... ] }

EventItem = { t, tm?, te?, th?, tt?, id?, _cid?, _author?, created_at?, rr? }
  t   : 제목
  tm  : 시작 "HH:MM"
  te  : 종료 "HH:MM"
  th  : 테마(=캘린더) id — String 또는 List<String>
  tt  : 시간표 항목 여부
  rr  : 반복 규칙 { f: "W|M|Y", i: int, u: "YYYY-MM-DD"?, c: int? }
```

**날짜가 저장 키다.** 일정의 날짜를 바꾸는 것 = 키 A의 배열에서 삭제 + 키 B의 배열에 추가.
현재 `EventsNotifier`에는 이 조합 연산이 없어서, 호출부(`add_edit_event_modal`)가 직접
`deleteEvent(oldKey, index)` + `addEvent(newKey, item)`를 순서대로 수행한다. → 원자성 없음.

할 일은 완전히 별도 계통이다: `'calendar-todos-v1' → [ TodoItem ]`, 평면 리스트, `dateKey` 선택값.

### 1.3 읽기 전용 소스 표현 방식

읽기 전용 데이터(NEIS 학사일정, 생일, 공휴일, 공유 구독, 스포츠)는 **직렬화되지 않는 플래그를 단
`EventItem`으로 즉석 변환**되어 로컬 일정과 같은 리스트에 섞인다.

```dart
EventItem(t: name, th: academicThemeId, academic: true)   // 학사일정
EventItem(t: b.name, th: birthdayThemeId, birthday: true) // 생일
EventItem(t: n, th: holidayThemeId)                       // 공휴일
```

`academic` / `birthday` / `sport` / `sportColor` / `sportEmoji` / `sportLogo`는 `toJson()`에 없다.
즉 **모델 안에 이미 원시적인 source 개념이 bool 플래그 6개로 흩어져 있다.** 2.0의 `CalendarSource`
enum은 이 플래그들을 대체하는 것이지 새 개념을 도입하는 게 아니다.

### 1.4 화면별 데이터 조립 — 핵심 문제

각 뷰가 **자기만의 병합 로직**을 갖는다. 소스 목록도, 필터 적용 여부도 서로 다르다.

| 화면 | 로컬 | 반복 | 학사 | 생일 | 공휴일 | 공유 | 스포츠 | 필터 적용 |
|---|---|---|---|---|---|---|---|---|
| `day_view` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `month_view` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `continuous_week_view` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `planner_view` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `home_view` (오늘) | ✅ | 부분 | ✅ | — | — | — | — | ❌ |
| `year_view` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `search_view` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `widget_bridge` (홈위젯) | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅(부분) |

`day_view.dart:110-155`만 봐도 한 화면이 소스 7종의 병합·필터·중복제거·학년필터를 전부
인라인으로 처리한다. 같은 코드가 4곳에 조금씩 다르게 복제돼 있다.

**결과적으로 나타나는 사용자 관찰 가능 버그:**
- 캘린더를 OFF 해도 검색 결과·연간 뷰·오늘 화면에서는 그대로 보인다.
- 반복 일정이 검색과 연간 뷰에 나오지 않는다.
- 홈 위젯과 앱 화면의 오늘 일정이 서로 다르다.

### 1.5 캘린더(=테마) 모델

`CalendarTheme { id, name, color, image?, shareCode?, shareRole? }` 하나가
"카테고리"와 "공유 캘린더"를 겸한다. 여기에 UI 전용 sentinel id가 섞여 있다:

- `'holidays'` — 실제 테마로 저장됨(기본값)
- `'__academic__'` — 저장 안 됨, 필터 전용 sentinel
- 생일 sentinel, 스포츠 구독 id — 각각 별도 규칙

`filterProvider`는 **숨긴 id의 Set**이다(화이트리스트 아님). ON/OFF 개념 자체는 이미 전역이므로
2.0에서는 이 provider를 그대로 쓰고, **모든 consumer가 반드시 이 필터를 거치게** 만들면 된다.

---

## 2. 발견된 실제 버그 (사용자 데이터에 영향)

### 🔴 B-1. 클라우드 동기화가 손실적(lossy) — 최우선

`lib/supabase/events_sync.dart`

```dart
'date', 'title', 'is_timetable', 'theme_id', 'position'   // 서버에 보내는 전부
```

`EventItem`의 나머지 필드는 서버 스키마에 **컬럼 자체가 없다.**
업로드 → 로그아웃 → 다운로드 하면 다음이 전부 사라진다:

| 필드 | 의미 | 왕복 후 |
|---|---|---|
| `tm` / `te` | 시작/종료 시각 | **소실** → 모든 일정이 종일 일정이 됨 |
| `rr` | 반복 규칙 | **소실** → 모든 반복 일정이 1회성이 됨 |
| `id` | 고유 id | **소실** → 중복 판정 불가 |
| `created_at` | 생성 시각 | 소실 |
| `_cid` / `_author` | 공유 출처 | 소실 |
| `th`(List인 경우) | 다중 캘린더 | 첫 항목만 유지 |

`pullToLocal()`이 `setStringQuiet(events, ...)`로 로컬을 **통째로 교체**하므로 복구 경로가 없다.
스펙 §24의 "Cloud Sync는 반드시 lossless"에 정면으로 위배된다.

**수정 방향:** 서버 `events` 테이블에 `payload jsonb` 컬럼 1개를 추가(nullable)하고
`EventItem.toJson()` 전체를 그대로 넣는다. 읽을 때 `payload`가 있으면 그것을 신뢰하고,
없으면(구버전 행) 기존 컬럼으로 폴백한다. 기존 컬럼은 계속 채워서 웹 클라이언트 호환을 유지한다.
→ 파괴적 스키마 변경 없음, 구/신 클라이언트 양방향 호환.

### 🔴 B-2. 백업에 사용자 데이터 다수 누락

`lib/modals/backup_modal.dart` `_backupKeys` (11개)에 없는 것:

- `todos` — **할 일 전체** (스펙 §23이 명시적으로 지적)
- `birthdays` — 생일
- `sportsSubscriptions` — 스포츠 구독
- `recordTemplates`, `recordTemplateRanges` — 기록 템플릿/기간
- `timetableTemplate`, `timetableOverrides`, `timetableWeekly` — 직접 입력한 시간표
- `memos`, `mottoIcon`, `cellDesign`, `userProfile`

UI는 "백업 완료"라고 표시한다. 백업 → 앱 초기화 → 복원 하면 할 일과 생일과 시간표가 사라진다.

**수정 방향:** `_backupKeys`를 `StorageKeys.accountKeys` 기반으로 도출 + 명시적 추가분.
`schemaVersion: 2` 유지하고 복원 시 알 수 없는 키는 무시(전방 호환).

### 🔴 B-3. 생일 알림 예약이 다른 알림을 전부 취소

`lib/utils/birthday_notifications.dart:63`

```dart
await _plugin.cancelAll();   // ← 플러그인 전역
```

다른 알림 계통은 각자 id 대역을 쓴다:

| 계통 | id base |
|---|---|
| 스포츠 | `0x10000000` |
| 일정 | `0x20000000` |
| 브리핑 | `0x30000000` |
| 생일 | **대역 없음 → cancelAll()** |

생일 알림 설정을 한 번 건드리면 일정 알림·스포츠 알림·브리핑이 전부 사라지고,
해당 계통이 다시 스케줄될 때까지 복구되지 않는다. 스펙 §21/§22가 지적한 바로 그 구조다.

**수정 방향:** 생일에 `0x40000000` 대역 부여 + `_cancelOwn()`(pendingRequests 필터링)으로 교체.
`event_notifications.dart:81`이 이미 올바른 패턴을 갖고 있으므로 그것을 따른다.

### 🔴 B-4. 비밀번호를 base64로 로컬 저장

`lib/supabase/auth_service.dart:_saveCredentials()`

```dart
await ls.setString(StorageKeys.savedAuthPw, base64Encode(utf8.encode(password)));
```

base64는 인코딩이지 암호화가 아니다. 기기에서 평문 비밀번호를 그대로 복원할 수 있다.
`StorageKeys` 주석도 "base64로 난독화 저장"이라고 스스로 인정하고 있다.

**수정 방향:** `supabase_flutter`는 이미 세션(리프레시 토큰)을 로컬에 영속화하고 앱 시작 시
자동 복원한다(`Supabase.initialize`의 기본 `LocalStorage`). 비밀번호 저장은 애초에 불필요하다.
저장 로직 제거 + 앱 시작 시 기존에 저장된 값 **1회 purge**(마이그레이션).

### 🟠 B-5. 할 일이 클라우드에 동기화되지 않음

`StorageKeys.userDataKeys`에 `todos`가 없다. `accountKeys`에는 있어서 계정별로 분리 저장은 되지만
클라우드에는 올라가지 않는다. 기기를 바꾸면 할 일이 사라진다. (B-2와 합쳐 할 일은
백업으로도, 클라우드로도 보존되지 않는 유일한 1급 데이터다.)

### 🟠 B-6. 일정 날짜 변경이 원자적이지 않음

`EventsNotifier`에 날짜 이동 API가 없어 호출부가 delete+add를 따로 수행한다.
중간 실패나 인덱스 어긋남 시 중복 또는 소실이 발생한다. 반복 일정의 경우
앵커를 옮기면 `recurringEventsByDateProvider`의 전개 결과가 통째로 이동하는데
"이 일정만 / 이후 전체" 구분이 없다.

### 🟡 B-7. 검색이 지역적

`searchHits()`가 로컬 이벤트 + 할 일만 본다. 학교/학사/공유/스포츠/생일/공휴일/반복 미포함,
필터 미적용. 스펙 §16.

### 🟡 B-8. 할 일 상태 3단 순환

`toggleDone()`이 `(status + 1) % 3` — 완료를 취소하려고 탭하면 "진행중"을 거친다.
체크박스 관용구에 어긋난다. 스펙 §15.

---

## 3. Surlap 2.0 목표 구조

```
                    CalendarRepository
                            │
     ┌──────────────────────┼──────────────────────┐
     │                      │                      │
   Local                  School                 Remote
  (편집 가능)            (읽기 전용)            (읽기 전용)
     │                      │                      │
 events_provider      neis_cache               shared_theme_events
 recurring            academic_schedule        sports_events
                      timetable_weekly         birthdays / holidays
     │                      │                      │
     └──────────────────────┼──────────────────────┘
                            │
                      CalendarItem
                   (+ filterProvider 단일 적용)
                            │
      ┌───────────┬─────────┼─────────┬───────────┐
      │           │         │         │           │
    Today     Calendar    Search   Widget    충돌검사/알림
```

### 3.1 `CalendarItem`

```dart
enum CalendarSource {
  local,           // 내가 만든 일정 (편집 가능)
  schoolTimetable, // NEIS/직접입력 시간표
  schoolAcademic,  // NEIS 학사일정
  shared,          // 구독 중인 공유 캘린더
  sports,          // 스포츠 구독
  birthday,
  holiday,
}

class CalendarItem {
  final String id;              // 소스별 안정 id
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final CalendarSource source;
  final String? sourceId;       // 원본 참조 (예: 로컬은 "dateKey#index")
  final String? calendarId;     // = 기존 th (테마 id / sentinel id)
  final bool editable;
  final Color? color;
  final Map<String, dynamic>? recurrenceRule;  // = 기존 rr
  final Map<String, dynamic> metadata;         // 스포츠 로고/이모지, 학년 등
  final String? createdAt;
  final String? updatedAt;
}
```

**`EventItem`은 삭제하지 않는다.** 로컬 저장 포맷 = 웹 호환 포맷이므로 그대로 두고,
`CalendarItem`은 그 위의 **읽기 전용 뷰 모델**로 둔다. 쓰기는 계속 `EventItem` 경로.
→ 데이터 마이그레이션 0, 롤백 가능.

### 3.2 단일 조회 API

```dart
// 범위 조회 — 모든 뷰가 이것만 쓴다.
final calendarRangeProvider =
    Provider.family<List<CalendarItem>, DateRange>((ref, range) => ...);

// 하루 조회 (범위 조회의 얇은 래퍼)
final calendarDayProvider =
    Provider.family<List<CalendarItem>, String>((ref, dateKey) => ...);
```

필터(`filterProvider`) 적용은 **repository 안에서 한 번만** 한다.
화면은 필터를 볼 필요가 없다 → 스펙 §3의 "OFF 하면 모든 뷰에서 동일하게 숨겨짐"이 구조적으로 보장된다.

### 3.3 정보구조 (IA)

```
[ 오늘 ] [ 캘린더 ] [ 학교 ] [ 할 일 ] [ 더보기 ]
```

| 탭 | 답하는 질문 | 흡수하는 기존 화면 |
|---|---|---|
| 오늘 | 지금 뭘 해야 하지? | `home_view` |
| 캘린더 | 언제 뭐가 있지? | `month_view` + `continuous_week_view` + `planner_view` + `day_view` + `year_view` |
| 학교 | 오늘 학교에서 뭐 하지? | `timetable_view` 상단부 + NEIS 급식/학사 |
| 할 일 | 아직 뭘 안 했지? | (신규 — 기존엔 전용 화면 없음) |
| 더보기 | 나머지 전부 | `profile_view` + `settings_view` + `theme_share_page` + 스포츠 |

공유 캘린더는 하단 내비에서 제거 → 더보기 / 캘린더 관리 하위로.

### 3.4 컬러 시맨틱

기존 브랜드 퍼플(`#5A2DF4` / 다크 `#8B6CFF`)을 **interaction 색으로 유지**하고,
Now/Today 전용 색과 destructive 색을 시맨틱으로 분리한다.

| 역할 | 값 | 사용처 |
|---|---|---|
| interaction | `sh.accent` = 퍼플 (기존) | 선택, 주요 버튼, 활성 탭 |
| **now / today** | `sh.now` = 라임 (신규) | NOW 카드, 오늘 날짜, 현재시간 인디케이터, 현재 교시 |
| warning / destructive | `sh.danger` = `#D9614E` (기존) | 충돌 경고, 삭제 |
| background | `sh.bg` (기존 웜 그라데이션) | 앱 배경 |

라임은 **Now/Today에만** 쓴다. 하단 내비 선택 상태 등 일반 활성 표시에는 쓰지 않는다.

---

## 4. 실행 계획

| Phase | 내용 | 리스크 |
|---|---|---|
| 1 | `CalendarItem` + `CalendarRepository` 신설, 기존 뷰를 순차 이관 | 중 — 뷰별 회귀 |
| 1b | B-1~B-6 데이터 신뢰성 버그 수정 + 테스트 | **높음(데이터)** — 비파괴 전략 필수 |
| 2 | 5탭 하단 내비 복원, Today NOW 구조, Calendar 뷰모드 통합, 제스처 축소 | 중 |
| 3 | 학교 탭 신설 | 낮 |
| 4 | 할 일 탭 + 2단 상태 | 낮 |
| 5 | 전역 검색 | 낮 (Phase 1 완료 시 자명) |
| 6 | 기록 시스템 UI 단일화 | 중 |
| 7 | 공유 lifecycle / 게스트 마이그레이션 / 알림 | 중 |
| 8 | 온보딩 축소, 상태 UI, 접근성 | 낮 |

각 Phase마다 `flutter analyze` + `flutter test` 통과 후 커밋한다.

### 기준선 (작업 시작 시점)

- `flutter analyze` — **No issues found**
- `flutter test` — **17 pass / 3 fail**
  - `onboarding_test.dart`: 2건 (이전 리디자인 커밋에서 발생, 선행 실패)
  - `timetable_view_test.dart`: 1건 (24시간 아젠다뷰 전환에서 발생, 선행 실패)

이 3건은 Phase 2/3에서 해당 화면을 손볼 때 함께 정리한다.

---

## 5. 진행 현황

브랜치 `surlap-2.0`. 각 커밋은 `flutter analyze` 무경고 + `flutter test` 통과 상태로 남겼다.

### 완료

| 커밋 | 내용 |
|---|---|
| `9b73935` | 분석 및 계획 문서 |
| `1db7fd7` | `CalendarItem` 통합 모델 + `CalendarRepository` 단일 조회 계층 |
| `d30c0d7` | 전역 검색 · 연간 뷰 · 홈 위젯을 통합 계층으로 이관 |
| `9d3ad71` | 데이터 신뢰성 결함 6건 수정 (B-1~B-6) |
| `74fe283` | 하단 5탭 IA 재편 + 오늘/캘린더/학교/할 일/더보기 화면 |
| `97fddb5` | 새 화면 렌더링 스모크 테스트 |
| `8fb2d30` | 월간·주간 뷰 통합 계층 이관 + 제스처 2개로 축소 + 아젠다 |
| `4e42458` | 첫 실행 2걸음으로 축소 + 선행 실패 테스트 3건 정리 |
| `ed9bbca` | 게스트 → 계정 데이터 이관 |
| `0284e0b` | 공유 캘린더 삭제 lifecycle 정리 |

스펙 항목별로는 §2·§3·§4·§5·§6·§7·§8·§9·§10·§11·§12·§13·§15·§16·§19·§22·§23·§24·§25·§26·§27·§28·§29·§32 를 다뤘다.

### origin/main 통합 (2026-08-10)

`origin/main` 은 같은 조상 `059433d` 에서 갈라진 **별개의 UI 개편 브랜치**다
(`8a52e83` 161파일 +14097/-7565, `2f66434`). 로컬 `main`(4커밋)은 origin 에 올라간 적이 없다.

```
059433d ─┬─ 90c0c4b → edf71bc → 6adafc8 → 7b07a39 → [Surlap 2.0 11커밋] → [통합 4커밋]
         └─ 8a52e83 → 2f66434  (origin/main)
```

머지·리베이스 대신 **영역별로 선별 통합**했다. `8a52e83` 은 드로어 내비게이션과
화면 전면 재작성을 포함해 Surlap 2.0 의 핵심 원칙과 정면으로 충돌하기 때문이다.

| 영역 | 판단 | 근거 |
|---|---|---|
| 앱 아이콘 · 스플래시 · 네이티브 위젯 리소스 | **채택** | Dart 충돌 없음, 품질 우위 |
| 위젯 데이터 계약 `surlap.widget.v2` | **채택(계약만)** | 네이티브가 요구. 데이터 출처는 `CalendarRepository` 유지 |
| `neis_service` (+`resolveOfficialSchoolLogo`) | **채택** | 시그니처 동일한 상위집합 |
| `translations` 747 → 2211줄 | **채택** | `tr()` 이 미번역 시 원문 폴백 |
| `AppEmptyState` / `AppToast` | **채택** | §33 미완 항목을 채움 |
| `themes_provider` 시스템 캘린더 분리 | **채택** | §10 방향과 일치 |
| `recurring_provider.setCells` | 채택 | 독립적 개선 |
| 드로어 내비게이션 · `surlap_app_bar` | **거부** | 5탭 IA와 충돌 |
| `main_shell` · `view_provider` 재작성 | **거부** | 5탭 · `AppTab` 구조와 충돌 |
| `home_view` · `profile_view` · `search_view` 재작성 | **거부** | Today NOW 구조 · 더보기 허브 · 통합 검색과 충돌 |
| `add_edit_event_modal` 재작성 | **거부** | 자연어 우선 입력과 충돌 |
| `month_view` · `day_view` · `month_grid` 재작성 | **거부** | 통합 계층 · 제스처 2개 원칙과 충돌 |
| 마스코트 삭제 | **거부** | 현재 화면 다수가 사용 중 |
| `2f66434` 월 전환 perf | **해당 없음** | 그 jank 는 origin/main 이 `AnimatedSwitcher` key 에 연·월을 넣어 생긴 것. 이 브랜치는 key 가 탭 단위라 재생성이 없고, 월간 조회도 이미 O(1) 해시 조회다 |

교시 시각은 통합 과정에서 `periodTime()`(1교시 08:40)으로 통일했다.
origin/main 의 위젯 브릿지는 `8 + period` 를 그대로 시(hour)로 써서 09:00 이었다.

### 남은 작업

| 스펙 | 내용 | 비고 |
|---|---|---|
| §17 | 기록 시스템 UI 단일화 | 하루 템플릿 / 기록 템플릿 / 기간 적용이 아직 별개 진입점. 데이터 구조는 유지하고 사용자 UI만 "기록" 하나로 합치면 된다 |
| §33 | Empty / loading / error / offline 상태 정비 | 오늘·학교·할 일·검색·캘린더 아젠다까지 `AppEmptyState` 적용 완료. 공유·스포츠 화면이 남음 |
| §21 | 생일 전용 관리 화면을 Calendar Source 로 인식시키기 | 알림 충돌은 이미 해결(§22). 남은 건 UI 위치 |
| §14 | 시간표 Export 화면 정비 | 기능은 그대로 동작. 스타일 프리셋 UI만 미정비 |
| §35 | 큰 기기 / 작은 기기 실기 확인 | 정적 분석·위젯 테스트로는 못 잡는 부분 |

### 주의 사항

- **서버 마이그레이션이 필요하다.** `supabase/migrations/20260810_events_payload.sql` 을
  적용해야 클라우드 동기화가 무손실이 된다. 적용 전에는 앱이 `undefined_column(42703)`
  을 보고 자동으로 레거시 형식으로 내려가므로 동작은 하지만, 시각·반복 정보는
  여전히 왕복에서 사라진다. 마이그레이션은 비파괴적(컬럼 추가만)·멱등이며
  RLS 에 영향이 없다. 적용 후 PostgREST 스키마 캐시 갱신이 필요할 수 있다.
- **76MB AAB / mapping.txt 히스토리 정리는 별도 작업으로 남긴다.** 이번 통합에서는
  건드리지 않았다.
- `EventItem` 저장 포맷과 `StorageKeys` 키 이름은 이번 작업에서 바꾸지 않았다.
  웹 클라이언트·기존 백업 파일과 호환된다.
- 예전 버전이 저장한 로컬 비밀번호는 앱 시작 시 1회 삭제된다.
