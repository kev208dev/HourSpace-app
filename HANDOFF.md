# Surlap 리디자인 작업 인계 문서

이 저장소(`sunfish501/Surlap`, public)는 원본 `kev208dev/Surlap`을 그대로 복사해 온 것이다.
원본 저장소는 절대 건드리지 않는다 — push 대상은 항상 `origin` = `sunfish501/Surlap`.

## 지금까지 한 것

디자인 문서(HTML 목업, WCAG 대비 검증, 컴포넌트 스펙)를 별도로 먼저 완성했고,
그걸 기준으로 실제 코드를 고치는 중이다. 디자인 문서 요약:

- 브랜드는 실제 리포 값 그대로: 액센트 퍼플 라이트 `#5A2DF4` / 다크 `#8B6CFF`
  (`lib/core/constants/color_presets.dart`, `lib/core/theme/app_theme.dart`의
  `SurlapColors`/`buildTheme(ColorPreset)` — **이 파일들 색상 로직은 건드리지 않는다**,
  핵심 브랜드 기능).
- `lib/core/theme/category_colors.dart`(16색 카테고리 라운드로빈),
  `lib/core/theme/surlap_brand.dart`(로고 색) — **역시 건드리지 않는다**.
- `lib/core/theme/design_tokens.dart` — 간격/반경/그림자/타이포/모션 토큰만 다루는 파일.
  사용자 피드백("너무 복잡하고 다가가기 힘들다")에 따라 단순화된 버전으로 이미 교체함
  (그림자 4→2, 반경 5→4, 모션 4×3→2×1, 타이포 이중체계 통합). 이 파일이 바뀌면서
  삭제된 옛 심볼(`Radii.hero`, `Shadows.hairline/card/lift`, `Motion.micro/slow/spring/emphasized`,
  `AppType.display/title/section/body/caption/label`, `Borders.thick`)을 참조하는 곳이
  리포에 더 있으면 새 이름으로 마이그레이션해야 한다 — grep으로 찾아서 처리.

## 진행 중이던 작업 4갈래 (중단 시점 기준)

1. **테마 패치** — `design_tokens.dart` 교체 + `app_theme.dart`의 `_buildTextTheme` 패치.
   `git status`로 이 두 파일 수정 여부 확인, 안 끝났으면 위 내용대로 마저.
2. **내비게이션** — 하단 플로팅 유리질감 탭바(`lib/widgets/bottom_nav_bar.dart`,
   `SurlapBottomNav`)를 없애고 좌상단 햄버거 + `Drawer`(신규 `lib/widgets/nav_drawer.dart`)로
   전환. `main_shell.dart`의 스피드다이얼 FAB(`_SpeedDialFab`, 테마공유/일정추가/할일추가/
   기록템플릿 4액션)는 "액션"이라 유지하되 크기만 54px→44px로 축소. 코치마크
   (`lib/widgets/coach_mark.dart`)가 옛 하단탭 위치를 가리키던 것도 새 위치로 이전 필요.
3. **24시간 시간표** — `lib/screens/timetable_view/timetable_view.dart`를 기존 1~6교시
   그리드에서 06:00~24:00 세로 아젠다뷰(구글 캘린더 일간뷰 스타일)로 재설계. 학교 교시는
   NEIS provider 실제 시각으로 시간 블록, 등교전/방과후엔 다른 일정도 같은 타임라인에.
   "지금" 라인은 danger(빨강) 아니라 `context.sh.accent`(퍼플).
4. **공유 및 구독 통합** — `lib/screens/theme_share_page.dart` + 그 안의
   `lib/screens/sports/sports_subscription_section.dart`를 상단 세그먼트 탭
   ("캘린더 공유" | "스포츠 구독") 2개로 전환.

## 원칙 (계속 지킬 것)

- 사용자가 명시: **"기존 디자인을 위한 기능 코드가 있으면 우리 디자인으로 싹 바꾸고
  우리 디자인 기준으로 기능 코드도 수정해"** — 프레젠테이션 레이어(위젯 트리)는 과감히
  재설계해도 됨. 단, provider/데이터 레이어(Riverpod providers, Supabase 연동, NEIS 연동)는
  건드리지 않는다 — 그 로직은 그대로 재사용.
- `color_presets.dart` / `category_colors.dart` / `surlap_brand.dart`는 무변경.
- 이모지 아이콘 금지, 색은 항상 라벨/아이콘 병기, 터치 타깃 44dp 이상.
- 원본 `kev208dev/Surlap`에는 push 금지. 항상 `origin`(`sunfish501/Surlap`)에만.

## 다음에 할 일

1. `flutter analyze` 돌려서 지금 상태 에러부터 확인.
2. 위 4갈래 중 안 끝난 것 마저.
3. 단계별로 커밋 + `git push`.
4. 남은 스코프(이번 라운드 보류): 연간뷰(`lib/screens/year_view/year_view.dart`, 이미
   존재하니 우리 디자인 톤에 맞춰 폴리싱만), 검색 화면(`lib/screens/search_view.dart`,
   존재함, 스타일 정렬만), 홈스크린 네이티브 위젯(Android `SurlapWidgetProvider.kt`,
   iOS `SurlapWidget.swift` — 이미 존재, 이번 라운드는 스코프 아웃하기로 사용자와 합의됨).
