# Sign in with Apple 설정 체크리스트

> 코드는 이미 붙어 있다. 아래 대시보드 작업이 끝나면
> `lib/screens/login/login_screen.dart` 의 `_kAppleEnabled` 를 `true` 로 바꾼다.

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
| Services ID (웹용, 신규 생성) | `com.kev208dev.surlapapp.web` |
| Client secret JWT (신규 생성) | `<APPLE_CLIENT_SECRET>` |

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
| Client IDs | `com.kev208dev.surlap,com.kev208dev.Surlap,com.kev208dev.surlapapp.web` |
| Secret Key (for OAuth) | `<APPLE_CLIENT_SECRET>` |

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

- Site URL: `https://kev208dev.github.io/Surlap/`
- Redirect URLs: `https://kev208dev.github.io/Surlap/**`, `surlap://login-callback`

## 확인

- iOS 실기기 — Apple 버튼 → 네이티브 시트 → 최초 1회 이름 저장
- 웹 — Apple 버튼 → appleid.apple.com → `/Surlap/` 로 복귀, 새로고침 시 404 없음
- Google 로그인이 그대로 동작하는지 함께 확인
