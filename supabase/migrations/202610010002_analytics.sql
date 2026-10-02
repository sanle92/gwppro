create table if not exists public.gwppro_analytics_sessions (
 id text primary key, visitor text not null, started timestamptz not null, last_seen timestamptz not null,
 path text not null, country text not null, city text not null, timezone text not null,
 browser text not null, device text not null, referrer text not null, email text not null default ''
);
create index if not exists idx_gwppro_analytics_started on public.gwppro_analytics_sessions(started);
create index if not exists idx_gwppro_analytics_last_seen on public.gwppro_analytics_sessions(last_seen);
create table if not exists public.gwppro_analytics_events(id text primary key, session text not null references public.gwppro_analytics_sessions(id) on delete cascade,path text not null,created timestamptz not null);
create index if not exists idx_gwppro_analytics_events_created on public.gwppro_analytics_events(created);
alter table public.gwppro_analytics_sessions enable row level security;
alter table public.gwppro_analytics_events enable row level security;
revoke all on public.gwppro_analytics_sessions,public.gwppro_analytics_events from anon,authenticated;
grant select on public.gwppro_analytics_sessions,public.gwppro_analytics_events to authenticated;
grant all on public.gwppro_analytics_sessions,public.gwppro_analytics_events to service_role;
drop policy if exists analytics_admin on public.gwppro_analytics_sessions;
create policy analytics_admin on public.gwppro_analytics_sessions for select to authenticated using (public.gwppro_is_admin());
drop policy if exists analytics_admin on public.gwppro_analytics_events;
create policy analytics_admin on public.gwppro_analytics_events for select to authenticated using (public.gwppro_is_admin());
create or replace function public.gwppro_track_visit(p_visit jsonb,p_event text) returns void language plpgsql security definer set search_path=public as $$
begin
 delete from gwppro_analytics_events where created < now()-interval '90 days';
 delete from gwppro_analytics_sessions where last_seen < now()-interval '90 days';
 insert into gwppro_analytics_sessions select (p_visit->>'id'),(p_visit->>'visitor'),(p_visit->>'started')::timestamptz,(p_visit->>'last_seen')::timestamptz,(p_visit->>'path'),(p_visit->>'country'),(p_visit->>'city'),(p_visit->>'timezone'),(p_visit->>'browser'),(p_visit->>'device'),(p_visit->>'referrer'),(p_visit->>'email')
 on conflict(id) do update set last_seen=greatest(gwppro_analytics_sessions.last_seen,excluded.last_seen),path=excluded.path,email=excluded.email;
 if p_event is not null then
 insert into gwppro_analytics_events values(p_event,p_visit->>'id',p_visit->>'path',(p_visit->>'last_seen')::timestamptz) on conflict(id) do nothing;
 end if;
end $$;
revoke all on function public.gwppro_track_visit(jsonb,text) from public,anon,authenticated;
grant execute on function public.gwppro_track_visit(jsonb,text) to service_role;
