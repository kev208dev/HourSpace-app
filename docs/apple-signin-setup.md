# Sign in with Apple 설정

> **상태: 설정 완료.** Apple Developer(App ID·Services ID·Key)와 Supabase
> Apple provider 가 모두 구성됐고, `lib/screens/login/login_screen.dart` 의
> `_kAppleEnabled` 는 `true` 다. 아래는 그 최종 값 기록 + 재설정용 절차다.

비밀값(`.p8` private key, client secret JWT)은 **이 저장소에 절대 넣지 않는다.**
Supabase Dashboard에만 입력한다.

## 식별자 기준

| 항목 | 값 |
| --- | --- |
| iOS 앱 Bundle ID (Xcode) | `com.kev208dev.Surlap` |
| Apple Developer 등록 App ID | `com.kev208dev.surlap` (Team `QXVSJ4484A`) |
| 위젯 익스텐션 Bundle ID | `com.kev208dev.Surlap.SurlapWidget` |
| App Group | `group.com.kev208dev.Surlap` |
| Android applicationId | `com.kev208dev.Surlap` |
| Services ID (웹·Android 리다이렉트용) | `com.kev208dev.surlapapp.web` |
| Client secret JWT | `<APPLE_CLIENT_SECRET>` (Supabase Dashboard 에만) |

Bundle ID 는 Apple 기준 case-insensitive 이므로 Xcode 의 `com.kev208dev.Surlap` 과
등록된 App ID `com.kev208dev.surlap` 은 같은 식별자다. Xcode 값은 바꾸지 않는다.

Android applicationId 는 Apple 과 무관하므로 그대로 둔다.

## Apple Developer

1. **App IDs**
   - `com.kev208dev.surlap` (기존) — Sign in with Apple + App Groups 체크
   - `com.kev208dev.surlap.SurlapWidget` — App Groups 체크 (없으면 생성)
   - 두 App ID 모두 App Groups 목록에서 `group.com.kev208dev.Surlap` 선택
2. **Services ID** (Identifiers → Services IDs)
   - Identifier: `com.kev208dev.surlapapp.web`
   - Sign in with Apple → Configure
     - Primary App ID: `Surlap (QXVSJ4484A.com.kev208dev.surlap)`
     - Domains and Subdomains: `enejjngrffugopgqeuxg.supabase.co`
     - Return URLs: `https://enejjngrffugopgqeuxg.supabase.co/auth/v1/callback`
   - GitHub Pages 도메인이 아니라 **Supabase 도메인**을 넣는다.
3. **Key** (Keys → +)
   - Sign in with Apple 체크, Primary App ID = `com.kev208dev.surlap`
   - `.p8` 파일은 1회만 다운로드된다. Key ID 를 기록.
4. **Team ID** — 계정 우상단 / Membership 에서 확인.

`.p8` + Team ID(`QXVSJ4484A`) + Key ID + Services ID 로 client secret JWT 를 만든다
(`iss`=Team ID, `kid`=Key ID, `sub`=Services ID, `aud`=`https://appleid.apple.com`, 만료 ≤ 6개월).

## Supabase Dashboard

Authentication → Providers → Apple

| 필드 | 값 |
| --- | --- |
| Enable | ON |
| Client IDs | `com.kev208dev.surlapapp.web,com.kev208dev.surlap,com.kev208dev.Surlap` |
| Secret Key (for OAuth) | `<APPLE_CLIENT_SECRET>` |

(위 Client IDs 가 **실제로 입력된 값**이다. 순서는 검증에 영향이 없다.)

- Client IDs 는 쉼표로 구분한다(공백 없이).
  앞의 Bundle ID 는 **iOS 네이티브 시트가 주는 id_token 의 `aud`** 와 대조되고,
  마지막 Services ID 는 **웹/Android 리다이렉트 플로우**에 쓰인다.
  Bundle ID 를 빼면 iOS 네이티브 로그인이 `Unacceptable audience` 로 실패한다.
- **대소문자 두 형태를 모두 넣는 이유**: Apple 은 Bundle ID 를 case-insensitive 로
  취급하지만 Supabase 의 audience 검증은 정확한 문자열 비교다. Apple 이 `aud` 에
  등록 형태(`surlap`)를 돌려줄지 앱이 보낸 형태(`Surlap`)를 돌려줄지 확정할 수 없으므로
  둘 다 등록해 둔다. iOS 실기기 테스트로 실제 값을 확인한 뒤 하나로 줄여도 된다.
- Secret 은 최장 6개월이므로 만료 전 재발급이 필요하다.

Authentication → URL Configuration

**이걸 안 하면 로그인이 끝난 뒤 `http://localhost:3000` 으로 튕긴다.**
새 Supabase 프로젝트의 Site URL 기본값이 `http://localhost:3000` 이고,
Redirect URLs 는 비어 있다. `/auth/v1/callback` 은 `state` 에 실린 `redirect_to`
를 **Redirect URLs 목록과 대조**해서, 매칭되지 않으면 조용히 Site URL 로
보낸다. 클라이언트가 올바른 `redirect_to` 를 보내도 소용없다.

| 필드 | 값 |
| --- | --- |
| Site URL | `https://kev208dev.github.io/Surlap/` |
| Redirect URLs | `https://kev208dev.github.io/Surlap/` |
| Redirect URLs | `https://kev208dev.github.io/Surlap/**` |
| Redirect URLs | `surlap://login-callback` |

- 정확 URL 과 `/**` 를 **둘 다** 넣는다. `/**` 가 빈 꼬리를 매칭하지 않는
  경우가 있어 정확 URL 이 없으면 루트 복귀가 그대로 실패한다.
- `surlap://login-callback` 이 없으면 **모바일 Google/Apple 리다이렉트 로그인**
  도 같은 이유로 깨진다(iOS 네이티브 Apple 시트는 리다이렉트를 안 타므로 무관).
- 진단 방법 — 토큰 없이 확인 가능하다. 아래가 `Location: http://localhost:3000…`
  이면 미등록, 보낸 URL 그대로 돌아오면 등록된 것이다.

  ```bash
  curl -sI "https://enejjngrffugopgqeuxg.supabase.co/auth/v1/verify\
?token=x&type=signup&redirect_to=https%3A%2F%2Fkev208dev.github.io%2FSurlap%2F" \
    -H "apikey: <SUPABASE_ANON_KEY>" | grep -i location
  ```

## 코드 쪽 동작 (검증 완료)

- **iOS·macOS** — `AppleSignIn.signInNative` 가 OS 시트를 띄우고 `signInWithIdToken`
  으로 세션을 만든다. nonce 는 Apple 에 **SHA-256 해시**를, Supabase 에 **원본**을
  준다(`lib/supabase/apple_sign_in.dart`). `test/apple_sign_in_test.dart` 가
  플랫폼 분기와 해시 규칙을 검증한다.
  → 이 경로의 audience 는 **번들 ID** 이므로 Client IDs 에 번들 ID 가 반드시 있어야 한다.
- **웹·Android** — `signInWithProvider(OAuthProvider.apple)` 리다이렉트.
  이 경로의 audience 는 **Services ID** 다.
- **웹 복귀 경로** — `_webRedirectUrl()` 이 `Uri.base` 에서 쿼리·프래그먼트만 떼고
  경로는 보존하므로 `https://kev208dev.github.io/Surlap/` 으로 돌아온다.
  origin 만 쓰면 `/Surlap/` 서브패스가 빠져 세션을 못 받는다.
  supabase_flutter 는 웹에서 `webOnlyWindowName: '_self'` 로 같은 탭 리다이렉트를
  하므로 새 탭 문제도 없다. 복귀 URL `/Surlap/?code=...` 는 실재 경로라
  `web/404.html` 의 SPA 리다이렉트를 타지 않고, `web/index.html` 의 복원
  스크립트도 `search[1] === '/'` 가 아니라 그냥 지나간다.
- **Google** — 같은 `signInWithProvider` 경로를 그대로 쓴다. Apple 활성화는
  `_kAppleEnabled` 상수 하나만 건드리므로 Google 경로에 영향이 없다.

## 실기기 확인 항목

- iOS 실기기 — Apple 버튼 → 네이티브 시트 → 최초 1회 이름 저장
  (`aud` 가 `surlap` / `Surlap` 중 무엇으로 오는지 확인해 Client IDs 를 줄일 수 있다)
- 웹 — Apple 버튼 → appleid.apple.com → `/Surlap/` 로 복귀, 새로고침 시 404 없음
- Google 로그인이 그대로 동작하는지 함께 확인
