-- events 테이블 무손실 동기화용 payload 컬럼.
--
-- 기존 스키마는 date/title/is_timetable/theme_id/position 만 보관해서
-- 업로드 → 다운로드 왕복에서 시작·종료 시각(tm/te), 반복 규칙(rr), id,
-- created_at, 다중 캘린더가 전부 소실됐다.
--
-- payload 에 EventItem 원본 JSON 전체를 담는다. 기존 컬럼은 그대로 두고
-- 계속 채우므로 웹 클라이언트와 구버전 앱은 영향을 받지 않는다.
-- nullable 이라 기존 행도 그대로 유효하다(구버전 행은 앱이 레거시 컬럼으로 복원).

alter table public.events
  add column if not exists payload jsonb;

comment on column public.events.payload is
  'EventItem 원본 JSON(t, tm, te, th, tt, id, _cid, _author, created_at, rr). '
  '무손실 동기화용. null 이면 레거시 행 — 클라이언트가 나머지 컬럼으로 복원한다.';
