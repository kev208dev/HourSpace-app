-- Surlap 기초 스키마.
--
-- ── 왜 이 파일이 뒤늦게 생겼나 ─────────────────────────────────────────────
-- 이전 프로젝트(ref dtmwnmeobutohjdpwhka)의 테이블은 대시보드에서 손으로
-- 만들어져 리포에 정의가 없었다. 프로젝트를 새로 파면 앱이 붙을 테이블이
-- 하나도 없다. 그 상태를 없애려고 실제 코드가 쓰는 스키마를 그대로 옮겼다.
--
-- 참조하는 코드:
--   events       ← lib/supabase/events_sync.dart
--   user_data    ← lib/supabase/user_data_sync.dart
--   theme_shares ← lib/supabase/theme_share_service.dart
--                  + lib/providers/theme_sharing_provider.dart (Realtime)
--
-- 멱등이다(`if not exists` / `drop policy if exists`). 여러 번 돌려도 안전.
--
-- 적용: 대시보드 → SQL Editor 에 붙여넣고 Run. 또는 `supabase db push`.
--       이 파일 → 0001_delete_account.sql → 20260619 → 20260810 순서.

-- ══════════════════════════════════════════════════════════════════════════
-- events — 날짜별 일정
-- ══════════════════════════════════════════════════════════════════════════
--
-- date 는 'YYYY-MM-DD' 문자열이다(로컬 저장 키와 같은 형식). 타임존 해석이
-- 끼어들면 안 되는 값이라 date 타입이 아니라 text 로 둔다.
--
-- payload 가 원본이고 나머지 컬럼은 웹 클라이언트·구버전 앱 호환용 사본이다.
-- 자세한 배경은 20260810_events_payload.sql 주석 참고.
create table if not exists public.events (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  date         text not null,
  title        text not null default '',
  is_timetable boolean not null default false,
  theme_id     text,
  position     integer not null default 0,
  payload      jsonb,
  created_at   timestamptz not null default now()
);

-- pullToLocal 은 user_id 로 걸러 date, position 순으로 정렬한다.
-- pushDate 는 (user_id, date) 로 지우고 다시 넣는다. 같은 인덱스가 둘 다 받는다.
create index if not exists events_user_date_idx
  on public.events (user_id, date, position);

alter table public.events enable row level security;

drop policy if exists events_own_all on public.events;
create policy events_own_all on public.events
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ══════════════════════════════════════════════════════════════════════════
-- user_data — 계정 단위 KV
-- ══════════════════════════════════════════════════════════════════════════
--
-- 값은 SharedPreferences 에 있던 문자열을 그대로 싣는다(대부분 JSON 문자열).
-- 어떤 키가 올라가는지는 StorageKeys.userDataKeys 가 정한다.
--
-- primary key (user_id, key) 가 있어야 upsert 의 onConflict: 'user_id,key' 가
-- 동작한다. 없으면 42P10 으로 실패한다.
create table if not exists public.user_data (
  user_id    uuid not null references auth.users (id) on delete cascade,
  key        text not null,
  value      text,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

alter table public.user_data enable row level security;

drop policy if exists user_data_own_all on public.user_data;
create policy user_data_own_all on public.user_data
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ══════════════════════════════════════════════════════════════════════════
-- theme_shares — 공유 캘린더
-- ══════════════════════════════════════════════════════════════════════════
--
-- code 는 32자 알파벳에서 뽑은 8자리(Random.secure) = 약 1.1e12 가지.
-- payload v2 는 { theme, events, v: 2 }.
create table if not exists public.theme_shares (
  code       text primary key,
  payload    jsonb not null,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists theme_shares_created_by_idx
  on public.theme_shares (created_by);

alter table public.theme_shares enable row level security;

-- 쓰기는 만든 사람만. 구독자가 남의 공유를 고치거나 지울 수 없다.
drop policy if exists theme_shares_owner_write on public.theme_shares;
create policy theme_shares_owner_write on public.theme_shares
  for insert
  to authenticated
  with check (created_by = auth.uid());

drop policy if exists theme_shares_owner_update on public.theme_shares;
create policy theme_shares_owner_update on public.theme_shares
  for update
  to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

drop policy if exists theme_shares_owner_delete on public.theme_shares;
create policy theme_shares_owner_delete on public.theme_shares
  for delete
  to authenticated
  using (created_by = auth.uid());

-- ⚠️ 읽기는 열려 있다 — 공유 코드를 아는 사람이 곧 구독자이기 때문이다.
--
-- 한계를 분명히 적어 둔다: 이 정책은 특정 행이 아니라 테이블 전체에 대한
-- SELECT 를 허용하므로, 코드를 모르는 사람도 필터 없이 조회하면 공유된
-- 캘린더 전부를 받아갈 수 있다. 코드가 길어 찍어 맞히기는 어렵지만,
-- 목록을 통째로 긁는 건 막지 못한다.
--
-- 제대로 막으려면 SELECT 를 소유자로 좁히고 코드 조회는 security definer
-- 함수로 빼야 한다. 다만 그렇게 하면 구독자의 Realtime 구독(RLS 를 그대로
-- 따른다)이 끊겨 공유 캘린더 실시간 반영이 죽는다. 그 교체는 별도 작업이다.
drop policy if exists theme_shares_read_all on public.theme_shares;
create policy theme_shares_read_all on public.theme_shares
  for select
  to anon, authenticated
  using (true);

-- 구독자에게 owner 의 수정이 실시간으로 흘러가야 한다
-- (theme_sharing_provider 의 onPostgresChanges update 구독).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'theme_shares'
  ) then
    alter publication supabase_realtime add table public.theme_shares;
  end if;
end $$;

-- ══════════════════════════════════════════════════════════════════════════
-- 권한
-- ══════════════════════════════════════════════════════════════════════════
-- Supabase 는 public 스키마 새 테이블에 기본 권한을 주지만, 프로젝트 설정에
-- 따라 다를 수 있어 명시한다. 실제 접근 제어는 위 RLS 가 한다.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.events       to authenticated;
grant select, insert, update, delete on public.user_data    to authenticated;
grant select, insert, update, delete on public.theme_shares to authenticated;
grant select                        on public.theme_shares to anon;
