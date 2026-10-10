-- Paper Danfo: playtest survey table. Paste into Supabase > SQL Editor > Run.
-- Public can insert one row per response (anonymous), nobody can read anyone's answers via the API.
-- You read them in Supabase > Table Editor > survey_responses, or export to CSV from there.

create table if not exists public.survey_responses (
  id            uuid primary key default gen_random_uuid(),
  rid           text not null,                      -- the browser-side response id (lets re-sends overwrite nothing)
  started_at    timestamptz not null,
  completed_at  timestamptz not null default now(),
  answers       jsonb not null default '{}'::jsonb,
  ua            text,                                -- user agent, first 300 chars
  ip_hash       text,                                -- never raw IP; see below
  created_at    timestamptz not null default now()
);
create unique index if not exists survey_responses_rid on public.survey_responses (rid);

-- lightweight anti-spam: at most 10 submissions per minute from one request (across all devices).
-- adjust / drop if the bounty bumps real traffic above that.
create table if not exists public.survey_rate (bucket timestamptz primary key, n int not null default 0);

alter table public.survey_responses enable row level security;
alter table public.survey_rate enable row level security;      -- no policies: only the function reads/writes

-- the one endpoint the public hits: a function the public can call, that writes a row and rate-limits.
-- the raw table has NO insert/select policy for the public, so this function (SECURITY DEFINER) is the only path in.
create or replace function public.submit_survey(p_rid text, p_started_at timestamptz, p_answers jsonb, p_ua text default null)
returns void language plpgsql security definer set search_path = public as $$
declare bk timestamptz := date_trunc('minute', now());
begin
  if p_rid is null or char_length(p_rid) not between 6 and 64 then raise exception 'bad rid'; end if;
  if jsonb_typeof(p_answers) <> 'object' then raise exception 'bad answers'; end if;
  if octet_length(p_answers::text) > 32768 then raise exception 'too big'; end if;
  insert into survey_rate(bucket, n) values (bk, 1) on conflict (bucket) do update set n = survey_rate.n + 1;
  if (select n from survey_rate where bucket = bk) > 60 then raise exception 'too many right now, try again in a minute'; end if;
  insert into survey_responses(rid, started_at, completed_at, answers, ua)
  values (p_rid, coalesce(p_started_at, now()), now(), p_answers, left(coalesce(p_ua, ''), 300))
  on conflict (rid) do update set answers = excluded.answers, completed_at = excluded.completed_at, ua = excluded.ua;
end $$;

revoke all on public.survey_responses, public.survey_rate from anon, authenticated;
grant execute on function public.submit_survey(text, timestamptz, jsonb, text) to anon, authenticated;

-- a simple read view for the dashboard: one row per response, with the answers prettied
create or replace view public.survey_report as
  select rid, started_at, completed_at, extract(epoch from (completed_at - started_at))::int as took_s,
         answers->>'fun_rating'    as fun,
         answers->>'diff_curve'    as difficulty,
         answers->>'runs'          as runs,
         answers->>'bought_skin'   as bought_skin,
         answers->>'fav_skin'      as fav_skin,
         answers->>'controls_clear' as controls,
         answers->>'add_one'       as add_one,
         answers->>'cut_one'       as cut_one,
         answers->>'anything'      as anything,
         answers->>'contact'       as contact,
         answers, ua
  from survey_responses
  order by completed_at desc;

-- a quick tally view
create or replace view public.survey_tally as
  select 'responses' as metric, count(*)::text as value from survey_responses
  union all select 'avg fun (1-5)', round(avg(nullif(answers->>'fun_rating','')::numeric), 2)::text from survey_responses
  union all select 'completed last 24h', count(*)::text from survey_responses where completed_at > now() - interval '1 day'
  union all select 'median time (s)', round(percentile_cont(0.5) within group (order by extract(epoch from (completed_at - started_at))))::text from survey_responses;
