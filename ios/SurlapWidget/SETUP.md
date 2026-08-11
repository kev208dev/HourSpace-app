# iOS 홈 위젯 (SurlapWidget) 설정

Flutter 쪽(데이터 브리지)은 이미 완료. iOS는 Xcode에서 **위젯 익스텐션 타겟 생성**과
**App Group 연결**만 수동으로 하면 된다. (Swift 코드는 `SurlapWidget.swift`에 작성됨)

App Group id: `group.com.kev208dev.Surlap`
위젯 kind/이름: `SurlapWidget`

Bundle ID:
- Runner: `com.kev208dev.Surlap`
  (Apple Developer 등록 App ID 는 `QXVSJ4484A.com.kev208dev.surlap`.
   Bundle ID 는 case-insensitive 라 동일 식별자로 취급된다)
- 위젯 익스텐션: `com.kev208dev.Surlap.SurlapWidget` (호스트 앱 ID 접두사 필수)

App Group id 는 Bundle ID 와 달라도 무방하며 `group.com.kev208dev.Surlap` 을 유지한다.
단, 두 App ID 모두에서 App Groups capability 에 이 그룹이 체크돼 있어야 한다.

Runner App ID 에는 App Groups 외에 **Sign in with Apple** capability 도 켜져 있다
(로그인용). Apple 로그인 쪽 설정값은 `docs/apple-signin-setup.md` 참고 —
위젯과는 무관하니 여기서는 App Groups 만 신경 쓰면 된다.

---

## 1. 위젯 익스텐션 타겟 생성

1. `ios/Runner.xcworkspace`를 Xcode로 연다 (`.xcodeproj` 아님, **workspace**).
2. 메뉴 **File → New → Target…**
3. **Widget Extension** 선택 → Next
4. 설정:
   - Product Name: **SurlapWidget**
   - **Include Live Activity**: 체크 해제
   - **Include Configuration App Intent**: 체크 해제 (정적 위젯)
   - Team: Runner와 동일
5. Finish → "Activate scheme?" 뜨면 **Activate**.

→ `SurlapWidget` 폴더 + 기본 `SurlapWidget.swift`가 생성됨.

## 2. Swift 코드 교체

1. Xcode가 만든 기본 `SurlapWidget.swift` 내용을 전부 지우고,
   이 폴더의 `SurlapWidget.swift`(이미 작성됨) 내용으로 교체.
   - 또는 Finder에서 이 파일을 타겟 폴더로 덮어쓰기 → Xcode에서 자동 반영.
2. 기본 생성된 `AppIntent.swift`(있으면) 삭제 — 정적 위젯이라 불필요.

## 3. App Group 추가 (양쪽 타겟 모두)

**Runner 타겟:**
1. 프로젝트 네비게이터 → **Runner** 프로젝트 → **Runner** 타겟
2. **Signing & Capabilities** 탭
3. **+ Capability** → **App Groups** 추가
4. **+** 눌러 `group.com.kev208dev.Surlap` 입력/체크

**SurlapWidget 타겟:**
1. 같은 화면에서 **SurlapWidget** 타겟 선택
2. **Signing & Capabilities** → **+ Capability** → **App Groups**
3. 동일한 `group.com.kev208dev.Surlap` 체크
4. Team/Signing이 비어 있으면 Runner와 같은 팀 지정

> 두 타겟이 **같은 App Group**을 공유해야 앱이 쓴 데이터를 위젯이 읽는다.

## 4. 빌드 & 테스트

```bash
cd Surlap-app
flutter run -d 00008120-000E4C8822EB401E   # 연결된 아이폰
```

1. 앱을 한 번 실행 → 오늘 할 일/일정 데이터가 App Group에 기록됨.
2. 홈 화면 → 빈 곳 길게 누르기 → **+** → "Surlap" 검색 → 위젯 추가.
3. small = 요약(할 일 수/일정 수), medium/large = 할 일 체크리스트 + 일정.
4. 앱에서 할 일/일정 추가·완료 → 앱을 백그라운드로 보내면 위젯 갱신됨.

## 동작 원리

- 앱: `lib/home_widget/widget_bridge.dart`가 오늘 데이터를 JSON으로 만들어
  `HomeWidget.saveWidgetData('hs_widget', …)` → App Group UserDefaults에 저장,
  `updateWidget()`으로 위젯 리로드 요청.
- 위젯: `WidgetStore.read()`가 `UserDefaults(suiteName: group…)`에서 `hs_widget`
  JSON을 읽어 렌더.
- 갱신 시점: 앱 시작, 앱 복귀(resumed), 할 일/일정 변경 시 (`app.dart`의 ref.listen).

## 문제 해결

- 위젯이 "오늘 할 일·일정이 없어요"만 나옴 → 앱을 한 번 켜서 데이터 기록했는지 확인.
- 빌드 에러 `No such module 'WidgetKit'` → 위젯 타겟의 iOS Deployment Target이 14.0+ 인지 확인.
- 데이터 안 보임 → 두 타겟의 App Group id가 정확히 같은지(`group.com.kev208dev.Surlap`) 확인.
