begin;
alter table public.gwppro_notifications add column if not exists admin_read boolean not null default false;
create or replace function public.gwppro_can_read_record(p_id text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.gwppro_records r where r.id=p_id and public.gwppro_has_workspace() and
 (public.gwppro_is_admin() or (
 r.email=lower((select auth.jwt()->>'email')) and r.kind in ('project','task','proposal','invoice','message','file','inquiry')
 and (r.kind<>'proposal' or r.data->>'status' in ('Sent','Accepted'))
 and (r.kind not in ('task','proposal','invoice','message','file') or nullif(r.data->>'projectId','') is null or exists(
 select 1 from public.gwppro_records p where p.id=r.data->>'projectId' and p.kind='project' and p.email=r.email))
 )));
$$;
revoke all on function public.gwppro_can_read_record(text) from public,anon;
grant execute on function public.gwppro_can_read_record(text) to authenticated,service_role;
drop policy if exists gwppro_workspace_read on public.gwppro_records;
create policy gwppro_workspace_read on public.gwppro_records for select to authenticated using(public.gwppro_can_read_record(id));
drop policy if exists gwppro_notification_read on public.gwppro_notifications;
create policy gwppro_notification_read on public.gwppro_notifications for select to authenticated using(public.gwppro_has_workspace() and (public.gwppro_is_admin() or (email=lower((select auth.jwt()->>'email')) and public.gwppro_can_read_record(record))));
drop policy if exists gwppro_private_files on storage.objects;
create policy gwppro_private_files on storage.objects for select to authenticated using(bucket_id='gwppro-files' and public.gwppro_has_workspace() and (public.gwppro_is_admin() or exists(select 1 from public.gwppro_records r where r.kind='file' and r.data->>'key'=name and public.gwppro_can_read_record(r.id))));
create or replace function public.gwppro_check_project_owner() returns trigger
language plpgsql security definer set search_path='' as $$
declare project_email text;
begin
 if new.kind in ('task','proposal','invoice','message','file') and nullif(new.data->>'projectId','') is not null then
  select email into project_email from public.gwppro_records where id=new.data->>'projectId' and kind='project';
  if project_email is null or project_email<>new.email then raise exception 'Record ownership must match its project.'; end if;
 end if;
 if new.kind='project' and old.email is distinct from new.email and exists(select 1 from public.gwppro_records where kind in ('task','proposal','invoice','message','file') and data->>'projectId'=new.id) then raise exception 'Resolve project assignments before changing its client.'; end if;
 return new;
end; $$;
drop trigger if exists gwppro_check_project_owner on public.gwppro_records;
create trigger gwppro_check_project_owner before insert or update on public.gwppro_records for each row execute function public.gwppro_check_project_owner();
commit;
notify pgrst, 'reload schema';
