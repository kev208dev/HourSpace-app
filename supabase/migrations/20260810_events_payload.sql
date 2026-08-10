-- events 테이블 무손실 동기화용 payload 컬럼.
--
-- ── 왜 필요한가 ──────────────────────────────────────────────────────────
-- 기존 스키마는 date/title/is_timetable/theme_id/position 만 보관해서
-- 업로드 → 다운로드 왕복에서 시작·종료 시각(tm/te), 반복 규칙(rr), id,
-- created_at, 다중 캘린더가 전부 소실됐다. 모든 일정이 종일·1회성이 된다.
--
-- payload 에 EventItem 원본 JSON 전체를 담는다.
--
-- ── 안전성 검토 ──────────────────────────────────────────────────────────
--  * 비파괴적: 컬럼 추가만 한다. drop / type change / not null 없음.
--    기존 행은 payload = null 로 남고, 클라이언트가 레거시 컬럼으로 복원한다.
--  * 멱등: `if not exists` 라 여러 번 실행해도 안전하다.
--  * RLS 영향 없음: 컬럼 추가는 기존 정책을 바꾸지 않는다. events 의 기존
--    user_id 기반 정책이 그대로 적용된다.
--  * 기존 컬럼은 계속 채운다: 웹 클라이언트와 구버전 앱이 그대로 동작한다.
--  * 이름 충돌 없음: theme_shares.payload 와는 다른 테이블이다.
--
-- ── 적용 전/후 동작 ──────────────────────────────────────────────────────
-- 적용 전에도 앱은 죽지 않는다. EventsSync 가 undefined_column(42703)을 보고
-- 레거시 컬럼만으로 자동 폴백한다. 다만 그동안은 시각·반복 손실이 그대로다.
-- 그래서 프로덕션 배포 전 필수 항목이다.
--
-- ── 적용 방법 ────────────────────────────────────────────────────────────
--   supabase db push
--   또는 대시보드 SQL Editor 에서 이 파일 내용을 실행
--
-- 적용 후 PostgREST 스키마 캐시가 갱신돼야 새 컬럼이 보인다. Supabase 는 DDL
-- 이벤트 트리거로 자동 reload 하지만, 즉시 반영이 필요하면 아래를 실행한다:
--   notify pgrst, 'reload schema';

alter table public.events
  add column if not exists payload jsonb;

comment on column public.events.payload is
  'EventItem 원본 JSON(t, tm, te, th, tt, id, _cid, _author, created_at, rr). '
  '무손실 동기화용. null 이면 레거시 행 — 클라이언트가 나머지 컬럼으로 복원한다.';
