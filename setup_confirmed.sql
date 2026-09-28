-- DOCTOR MReda - confirmed referrals
-- Run this in Supabase SQL Editor after the existing setup.

alter table public.referrals
  add column if not exists confirmed boolean not null default false;

-- Rebuild register function so a referral is NOT counted until confirmed.
drop function if exists public.register_referral(text,text,text);

create or replace function public.register_referral(
  p_username text,
  p_visitor_id text,
  p_referred_by text default null
)
returns table (
  username text,
  referral_code text,
  referrals bigint,
  is_new boolean,
  confirmed boolean
)
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_code text;
  v_existing referrals%rowtype;
begin
  p_username := left(trim(p_username), 40);
  p_visitor_id := left(trim(p_visitor_id), 120);
  p_referred_by := nullif(left(trim(p_referred_by), 40), '');

  if p_username is null or length(p_username) < 2 then
    raise exception 'اسم غير صالح';
  end if;

  if p_visitor_id is null or length(p_visitor_id) < 8 then
    raise exception 'معرف غير صالح';
  end if;

  select * into v_existing
  from public.referrals r
  where r.visitor_id = p_visitor_id
  limit 1;

  if found then
    return query
    select
      v_existing.username,
      v_existing.referral_code,
      (select count(*) from public.referrals x
       where x.referred_by = v_existing.referral_code
         and x.confirmed = true)::bigint,
      false,
      coalesce(v_existing.confirmed, false);
    return;
  end if;

  if p_referred_by is not null and not exists (
    select 1 from public.referrals r
    where r.referral_code = p_referred_by
  ) then
    p_referred_by := null;
  end if;

  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
    exit when not exists (
      select 1 from public.referrals r
      where r.referral_code = v_code
    );
  end loop;

  insert into public.referrals(
    username, referral_code, referred_by, visitor_id, confirmed
  )
  values (
    p_username, v_code, p_referred_by, p_visitor_id, false
  );

  return query
  select p_username, v_code, 0::bigint, true, false;
end;
$function$;

-- This is the confirmation step after the invitee has joined the WhatsApp channel.
-- It prevents the inviter's count from increasing before this step.
drop function if exists public.confirm_referral(text);

create or replace function public.confirm_referral(p_visitor_id text)
returns table (
  confirmed boolean,
  referral_code text,
  inviter_code text
)
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_ref referrals%rowtype;
begin
  p_visitor_id := left(trim(p_visitor_id), 120);

  select * into v_ref
  from public.referrals r
  where r.visitor_id = p_visitor_id
  limit 1;

  if not found then
    raise exception 'لم يتم العثور على مشاركتك';
  end if;

  update public.referrals r
  set confirmed = true
  where r.visitor_id = p_visitor_id;

  return query
  select true, v_ref.referral_code, v_ref.referred_by;
end;
$function$;

-- Leaderboard: ONLY confirmed referrals count.
drop function if exists public.get_leaderboard();

create or replace function public.get_leaderboard()
returns table (
  username text,
  referral_code text,
  referrals bigint
)
language sql
security definer
set search_path = public
as $function$
  select
    r.username,
    r.referral_code,
    count(c.id)::bigint as referrals
  from public.referrals r
  left join public.referrals c
    on c.referred_by = r.referral_code
   and c.confirmed = true
  group by r.id, r.username, r.referral_code
  order by count(c.id) desc, r.created_at asc
  limit 20;
$function$;

revoke all on function public.register_referral(text,text,text) from public;
grant execute on function public.register_referral(text,text,text) to anon, authenticated;

revoke all on function public.confirm_referral(text) from public;
grant execute on function public.confirm_referral(text) to anon, authenticated;

revoke all on function public.get_leaderboard() from public;
grant execute on function public.get_leaderboard() to anon, authenticated;
