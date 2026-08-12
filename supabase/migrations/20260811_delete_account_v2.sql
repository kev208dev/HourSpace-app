-- delete_account 재정의 — 없는 테이블을 건너뛴다.
--
-- ── 왜 고치나 ─────────────────────────────────────────────────────────────
-- 0001_delete_account.sql 은 theme_subscribers / theme_contributed_events /
-- user_backups 를 지운다. 이 셋은 옛 프로젝트에 손으로 만들어져 있었을 뿐
-- 앱 코드 어디서도 쓰지 않고, 0000_base_schema.sql 도 만들지 않는다.
--
-- plpgsql 본문은 정의 시점에 테이블 존재를 확인하지 않는다. 그래서 함수는
-- 멀쩡히 만들어지고, 사용자가 실제로 탈퇴를 누르는 순간 undefined_table 로
-- 터진다. 앱에서는 "탈퇴가 안 되는" 증상으로 보인다 — Apple/Google 심사
-- 요건(앱 내 계정 삭제)에 바로 걸린다.
--
-- 있으면 지우고 없으면 넘어가도록 동적 실행으로 바꾼다.
--
-- 소유 판별 컬럼: events/user_data 는 user_id, theme_shares 는 created_by.

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
  t   record;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  -- (테이블, 소유자 컬럼) 목록. 존재하는 것만 지운다.
  for t in
    select * from (values
      ('events',                   'user_id'),
      ('user_data',                'user_id'),
      ('theme_subscribers',        'user_id'),
      ('theme_contributed_events', 'user_id'),
      ('user_backups',             'user_id'),
      ('theme_shares',             'created_by')
    ) as v(tbl, owner_col)
  loop
    if to_regclass('public.' || quote_ident(t.tbl)) is not null then
      execute format('delete from public.%I where %I = $1', t.tbl, t.owner_col)
        using uid;
    end if;
  end loop;

  -- auth 계정 자체. 위 테이블들은 on delete cascade 도 걸려 있지만,
  -- cascade 가 없는 옛 테이블을 위해 명시적으로 먼저 지웠다.
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
