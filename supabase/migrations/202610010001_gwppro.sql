-- gwppro: run in the Supabase SQL Editor for the selected project.
-- No example clients, accounts, projects, or payments are inserted.
begin;
create table if not exists public.gwppro_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 email text not null unique check (email=lower(email)),
 name text not null default '',
 role text not null default 'client' check (role in ('admin','client')),
 created timestamptz not null default now()
);
create table if not exists public.gwppro_records (
 id text primary key,
 kind text not null check(kind in ('inquiry','client','project','task','proposal','invoice','message','lead','portfolio','service','setting','file')),
 email text not null default '' check(email=lower(email)),
 data jsonb not null check(jsonb_typeof(data)='object'),
 created timestamptz not null default now(),
 updated timestamptz not null default now()
);
create index if not exists gwppro_records_kind_email on public.gwppro_records(kind,email);
create index if not exists gwppro_records_project on public.gwppro_records((data->>'projectId'));
create table if not exists public.gwppro_payments (
 id text primary key,
 invoice text not null references public.gwppro_records(id),
 token text not null unique,
 status text not null,
 created timestamptz not null default now()
);
create table if not exists public.gwppro_notifications (
 id text primary key,
 email text not null check(email=lower(email)),
 title text not null,
 record text not null,
 kind text not null,
 created timestamptz not null default now(),
 read boolean not null default false
);
create index if not exists gwppro_notifications_email_created on public.gwppro_notifications(email,created desc);
create table if not exists public.gwppro_subscriptions (
 endpoint text primary key,
 email text not null check(email=lower(email)),
 data jsonb not null
);
create index if not exists gwppro_subscriptions_email on public.gwppro_subscriptions(email);
create table if not exists public.gwppro_auth_limits (
 id text primary key,
 attempts integer not null,
 expires bigint not null
);

create or replace function public.gwppro_sync_profile() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.gwppro_profiles(id,email,name)
 values(new.id,lower(new.email),left(coalesce(new.raw_user_meta_data->>'name',split_part(new.email,'@',1)),100))
 on conflict(id) do update set email=excluded.email,name=excluded.name;
 return new;
end; $$;
drop trigger if exists gwppro_auth_profile on auth.users;
create trigger gwppro_auth_profile after insert or update of email,raw_user_meta_data on auth.users for each row when (new.email is not null) execute function public.gwppro_sync_profile();
-- Bring already existing Auth users into this application's profile directory.
insert into public.gwppro_profiles(id,email,name)
select id,lower(email),left(coalesce(raw_user_meta_data->>'name',split_part(email,'@',1)),100) from auth.users where email is not null on conflict(id) do nothing;

create or replace function public.gwppro_is_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.gwppro_profiles where id=(select auth.uid()) and role='admin');
$$;
alter table public.gwppro_profiles enable row level security;
alter table public.gwppro_records enable row level security;
alter table public.gwppro_payments enable row level security;
alter table public.gwppro_notifications enable row level security;
alter table public.gwppro_subscriptions enable row level security;
alter table public.gwppro_auth_limits enable row level security;

-- Browser clients can read permitted rows. All mutation workflows go through
-- the checked server API; never grant clients direct writes or role changes.
revoke all on public.gwppro_profiles,public.gwppro_records,public.gwppro_payments,public.gwppro_notifications,public.gwppro_subscriptions,public.gwppro_auth_limits from anon,authenticated;
grant select on public.gwppro_records to anon,authenticated;
grant select on public.gwppro_profiles,public.gwppro_notifications to authenticated;
grant all on public.gwppro_profiles,public.gwppro_records,public.gwppro_payments,public.gwppro_notifications,public.gwppro_subscriptions,public.gwppro_auth_limits to service_role;
drop policy if exists gwppro_profile_read on public.gwppro_profiles;
create policy gwppro_profile_read on public.gwppro_profiles for select to authenticated using(id=(select auth.uid()));
drop policy if exists gwppro_public_catalog on public.gwppro_records;
create policy gwppro_public_catalog on public.gwppro_records for select to anon,authenticated using(kind in ('portfolio','service'));
drop policy if exists gwppro_workspace_read on public.gwppro_records;
create policy gwppro_workspace_read on public.gwppro_records for select to authenticated using(
 public.gwppro_is_admin() or (
 email=lower((select auth.jwt()->>'email')) and
 kind in ('project','task','proposal','invoice','message','file','inquiry') and
 (kind<>'proposal' or data->>'status'<>'Draft')
 ));
drop policy if exists gwppro_notification_read on public.gwppro_notifications;
create policy gwppro_notification_read on public.gwppro_notifications for select to authenticated using(email=lower((select auth.jwt()->>'email')));

insert into storage.buckets(id,name,public,file_size_limit) values('gwppro-files','gwppro-files',false,10485760)
on conflict(id) do update set public=false,file_size_limit=10485760;
drop policy if exists gwppro_private_files on storage.objects;
create policy gwppro_private_files on storage.objects for select to authenticated using(
 bucket_id='gwppro-files' and exists (
 select 1 from public.gwppro_records r where r.kind='file' and r.data->>'key'=name and
 (public.gwppro_is_admin() or r.email=lower((select auth.jwt()->>'email')))
 ));

create or replace function public.gwppro_auth_attempt(p_id text,p_expires bigint) returns integer
language plpgsql security invoker set search_path='' as $$
declare n integer;
begin
 delete from public.gwppro_auth_limits where expires < extract(epoch from clock_timestamp())*1000;
 insert into public.gwppro_auth_limits(id,attempts,expires) values(p_id,1,p_expires)
 on conflict(id) do update set attempts=public.gwppro_auth_limits.attempts+1 returning attempts into n;
 return n;
end; $$;

create or replace function public.gwppro_accept_proposal(p_id text,p_email text,p_admin boolean) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare r public.gwppro_records;amount numeric;deposit numeric;pid text;iid text;project jsonb;invoice jsonb;
begin
 select * into r from public.gwppro_records where id=p_id and kind='proposal' for update;
 if not found or (not p_admin and r.email<>lower(p_email)) then raise exception 'Access denied.';end if;
 pid:='project-'||r.id;iid:='deposit-'||r.id;
 if r.data->>'status'='Accepted' then return jsonb_build_object('changed',false,'projectId',pid,'invoiceId',iid);end if;
 if r.data->>'status'<>'Sent' then raise exception 'This proposal is not ready for acceptance.';end if;
 amount:=(r.data->>'amount')::numeric;deposit:=coalesce((r.data->>'deposit')::numeric,50);
 if amount is null or amount<=0 or amount='NaN'::numeric or deposit<=0 or deposit>100 or deposit='NaN'::numeric then raise exception 'Proposal amount is invalid.';end if;
 project:=jsonb_build_object('name',r.data->>'name','email',r.email,'status','Awaiting Payment','progress',0,'description',r.data->>'description','due',r.data->>'due');
 invoice:=jsonb_build_object('name',(r.data->>'name')||' — upfront payment','email',r.email,'projectId',pid,'amount',round(amount*deposit)/100,'currency',coalesce(r.data->>'currency','USD'),'status','Pending','due',r.data->>'due');
 insert into public.gwppro_records(id,kind,email,data) values(pid,'project',r.email,project),(iid,'invoice',r.email,invoice) on conflict(id) do nothing;
 update public.gwppro_records set data=r.data||jsonb_build_object('status','Accepted','projectId',pid),updated=now() where id=p_id;
 return jsonb_build_object('changed',true,'projectId',pid,'invoiceId',iid);
end; $$;

create or replace function public.gwppro_final_invoice(p_id text) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare r public.gwppro_records;iid text;balance numeric;total numeric;invoice jsonb;
begin
 select * into r from public.gwppro_records where id=p_id and kind='proposal' for update;
 if not found or r.data->>'status'<>'Accepted' then raise exception 'Accept the proposal before creating a final invoice.';end if;
 iid:='final-'||r.id;
 if exists(select 1 from public.gwppro_records where id=iid) then return jsonb_build_object('changed',false,'invoiceId',iid);end if;
 if exists(select 1 from public.gwppro_records where kind='invoice' and data->>'projectId'=r.data->>'projectId' and data->>'currency' is distinct from r.data->>'currency') then raise exception 'Review mixed-currency invoices before calculating the final balance.';end if;
 select coalesce(sum((data->>'amount')::numeric),0) into total from public.gwppro_records where kind='invoice' and data->>'projectId'=r.data->>'projectId';
 balance:=round((r.data->>'amount')::numeric-total,2);
 if balance is null or balance<=0 or balance='NaN'::numeric then raise exception 'The full proposal amount has already been invoiced.';end if;
 invoice:=jsonb_build_object('name',(r.data->>'name')||' — final payment','email',r.email,'projectId',r.data->>'projectId','amount',balance,'currency',r.data->>'currency','status','Pending');
 insert into public.gwppro_records(id,kind,email,data) values(iid,'invoice',r.email,invoice);
 return jsonb_build_object('changed',true,'invoiceId',iid);
end; $$;

create or replace function public.gwppro_claim_outreach(p_id text,p_expected_status text) returns boolean
language plpgsql security invoker set search_path='' as $$
declare n integer;
begin
 update public.gwppro_records set data=data||jsonb_build_object('status','Sending'),updated=now()
 where id=p_id and kind='lead' and data->>'status'=p_expected_status and data->>'sentAt' is null;
 get diagnostics n=row_count;return n=1;
end; $$;

-- The API supplies checked caller information. These RPCs are server-only.
revoke all on function public.gwppro_sync_profile() from public,anon,authenticated;
revoke all on function public.gwppro_is_admin() from public,anon;
grant execute on function public.gwppro_is_admin() to authenticated,service_role;
revoke all on function public.gwppro_auth_attempt(text,bigint),public.gwppro_accept_proposal(text,text,boolean),public.gwppro_final_invoice(text),public.gwppro_claim_outreach(text,text) from public,anon,authenticated;
grant execute on function public.gwppro_auth_attempt(text,bigint),public.gwppro_accept_proposal(text,text,boolean),public.gwppro_final_invoice(text),public.gwppro_claim_outreach(text,text) to service_role;
commit;
