-- Hardening: pin search_path on the analytics RPC and index the rate-limit expiry.
begin;
create index if not exists gwppro_auth_limits_expires on public.gwppro_auth_limits(expires);
create or replace function public.gwppro_track_visit(p_visit jsonb,p_event text) returns void language plpgsql security definer set search_path='' as $$
begin
 delete from public.gwppro_analytics_events where created < now()-interval '90 days';
 delete from public.gwppro_analytics_sessions where last_seen < now()-interval '90 days';
 insert into public.gwppro_analytics_sessions(id,visitor,started,last_seen,path,country,city,timezone,browser,device,referrer,email)
 values((p_visit->>'id'),(p_visit->>'visitor'),(p_visit->>'started')::timestamptz,(p_visit->>'last_seen')::timestamptz,(p_visit->>'path'),(p_visit->>'country'),(p_visit->>'city'),(p_visit->>'timezone'),(p_visit->>'browser'),(p_visit->>'device'),(p_visit->>'referrer'),(p_visit->>'email'))
 on conflict(id) do update set last_seen=greatest(public.gwppro_analytics_sessions.last_seen,excluded.last_seen),path=excluded.path,email=excluded.email;
 if p_event is not null then
  insert into public.gwppro_analytics_events(id,session,path,created) values(p_event,p_visit->>'id',p_visit->>'path',(p_visit->>'last_seen')::timestamptz) on conflict(id) do nothing;
 end if;
end $$;
revoke all on function public.gwppro_track_visit(jsonb,text) from public,anon,authenticated;
grant execute on function public.gwppro_track_visit(jsonb,text) to service_role;
commit;
