begin;
alter table public.gwppro_payments add column if not exists method text not null default 'legacy';
alter table public.gwppro_payments add column if not exists data jsonb not null default '{}';
create index if not exists gwppro_payments_invoice_created on public.gwppro_payments(invoice,created desc);

create or replace function public.gwppro_client_access(p_email text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.gwppro_records where kind='client' and email=lower(p_email))
 and not exists(select 1 from public.gwppro_records where kind='client' and email=lower(p_email) and data->>'status'='Archived');
$$;
revoke all on function public.gwppro_client_access(text) from public,anon;
grant execute on function public.gwppro_client_access(text) to service_role;
-- Match the profile email to Auth as well as JWT record ownership.
create or replace function public.gwppro_has_workspace() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.gwppro_profiles p where p.id=(select auth.uid())
 and p.email=lower((select auth.jwt()->>'email')) and (p.role='admin' or public.gwppro_client_access(p.email)));
$$;
revoke all on function public.gwppro_has_workspace() from public,anon;
grant execute on function public.gwppro_has_workspace() to authenticated,service_role;
drop policy if exists gwppro_workspace_read on public.gwppro_records;
create policy gwppro_workspace_read on public.gwppro_records for select to authenticated using(
 public.gwppro_has_workspace() and (public.gwppro_is_admin() or (email=lower((select auth.jwt()->>'email')) and kind in ('project','task','proposal','invoice','message','file','inquiry') and (kind<>'proposal' or data->>'status'<>'Draft'))));
drop policy if exists gwppro_notification_read on public.gwppro_notifications;
create policy gwppro_notification_read on public.gwppro_notifications for select to authenticated using(public.gwppro_has_workspace() and email=lower((select auth.jwt()->>'email')));
drop policy if exists gwppro_private_files on storage.objects;
create policy gwppro_private_files on storage.objects for select to authenticated using(bucket_id='gwppro-files' and public.gwppro_has_workspace() and (public.gwppro_is_admin() or exists(select 1 from public.gwppro_records r where r.kind='file' and r.email=lower((select auth.jwt()->>'email')) and r.data->>'key'=name)));

create or replace function public.gwppro_reserve_payment(p_invoice text,p_method text,p_snapshot jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare i public.gwppro_records; p public.gwppro_payments; pid text;
begin
 select * into i from public.gwppro_records where id=p_invoice and kind='invoice' for update;
 if i.id is null or i.data->>'status'='Paid' then raise exception 'Invoice is unavailable or already paid.'; end if;
 if p_method not in ('stripe','paypal','bank','binance','crypto') then raise exception 'Invalid payment method.'; end if;
 if (i.data->>'amount')::numeric*100 <> (p_snapshot->>'amount')::numeric or i.data->>'currency'<>p_snapshot->>'currency' or i.email<>p_snapshot->>'email' then raise exception 'Invoice changed. Refresh before paying.'; end if;
 select * into p from public.gwppro_payments where invoice=p_invoice and status in ('Creating','Processing','Review') order by created desc limit 1;
 if p.id is not null then
   if p.method<>p_method then raise exception 'Another payment is open. Check or resolve it before choosing another method.'; end if;
   return to_jsonb(p);
 end if;
 pid:=gen_random_uuid()::text;
 insert into public.gwppro_payments(id,invoice,token,status,method,data) values(pid,p_invoice,'pending:'||pid,'Creating',p_method,p_snapshot) returning * into p;
 return to_jsonb(p);
end; $$;
create or replace function public.gwppro_submit_manual_payment(p_id text,p_reference text) returns void
language plpgsql security definer set search_path='' as $$
declare p public.gwppro_payments;
begin
 select * into p from public.gwppro_payments where id=p_id for update;
 if p.id is null or p.method not in ('paypal','bank','binance','crypto') or p.status not in ('Creating','Review') then raise exception 'Manual payment is unavailable.'; end if;
 if length(trim(p_reference))<4 or length(p_reference)>300 then raise exception 'Invalid payment reference.'; end if;
 if p.status='Review' then return; end if;
 update public.gwppro_payments set status='Review',data=data||jsonb_build_object('reference',trim(p_reference),'submittedAt',now()) where id=p.id;
end; $$;
create or replace function public.gwppro_settle_payment(p_id text,p_token text,p_actor text,p_reference text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.gwppro_payments; i public.gwppro_records; changed boolean;
begin
 -- Take the invoice lock first in every billing RPC to avoid lock-order deadlocks.
 select * into p from public.gwppro_payments where id=p_id;
 if p.id is null then raise exception 'Payment not found.'; end if;
 select * into i from public.gwppro_records where id=p.invoice and kind='invoice' for update;
 select * into p from public.gwppro_payments where id=p_id for update;
 if i.id is null then raise exception 'Invoice not found.'; end if;
 if p_actor='stripe' then
   if p.method<>'stripe' or p_token not like 'cs_%' or (p.token not like 'pending:%' and p.token<>p_token) then raise exception 'Invalid Stripe reference.'; end if;
 elsif p_actor='admin' then
   if p.method not in ('paypal','bank','binance','crypto') or p.status not in ('Review','Paid') or p_token<>p.token then raise exception 'Payment is not awaiting review.'; end if;
 else raise exception 'Invalid reviewer.';
 end if;
 if (i.data->>'amount')::numeric*100 <> (p.data->>'amount')::numeric or i.data->>'currency'<>p.data->>'currency' or i.email<>p.data->>'email' then raise exception 'Invoice changed. Payment requires manual review.'; end if;
 if p.status='Paid' then return jsonb_build_object('changed',false); end if;
 changed:=coalesce(i.data->>'status','')<>'Paid';
 update public.gwppro_payments set token=p_token,status='Paid',data=data||jsonb_build_object('reviewedAt',now(),'reviewer',p_actor,'providerReference',p_reference) where id=p.id;
 if changed then
   update public.gwppro_records set data=data||jsonb_build_object('status','Paid','paidAt',now(),'transaction',p_token,'paymentMethod',p.method),updated=now() where id=i.id;
   update public.gwppro_records set data=data||'{"status":"Active"}',updated=now() where id=i.data->>'projectId' and kind='project' and data->>'status'='Awaiting Payment';
 end if;
 return jsonb_build_object('changed',changed);
end; $$;
create or replace function public.gwppro_reject_payment(p_id text,p_note text) returns void
language plpgsql security definer set search_path='' as $$
declare p public.gwppro_payments;
begin
 select * into p from public.gwppro_payments where id=p_id;
 if p.id is null then raise exception 'Payment not found.'; end if;
 perform 1 from public.gwppro_records where id=p.invoice for update;
 select * into p from public.gwppro_payments where id=p_id for update;
 if p.method not in ('paypal','bank','binance','crypto') or p.status<>'Review' then raise exception 'Payment is not awaiting review.'; end if;
 if length(trim(p_note))<4 or length(p_note)>500 then raise exception 'Enter a reason with 4–500 characters.'; end if;
 update public.gwppro_payments set status='Rejected',data=data||jsonb_build_object('reviewedAt',now(),'reviewNote',p_note) where id=p_id;
end; $$;
revoke all on function public.gwppro_reserve_payment(text,text,jsonb),public.gwppro_submit_manual_payment(text,text),public.gwppro_settle_payment(text,text,text,text),public.gwppro_reject_payment(text,text) from public,anon,authenticated;
grant execute on function public.gwppro_reserve_payment(text,text,jsonb),public.gwppro_submit_manual_payment(text,text),public.gwppro_settle_payment(text,text,text,text),public.gwppro_reject_payment(text,text) to service_role;
create or replace function public.gwppro_invoice_payment_lock() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.kind='invoice' and old.data->>'status'='Paid' and new.data->>'status' is distinct from 'Paid' then raise exception 'Paid invoices cannot be reopened.'; end if;
 if old.kind='invoice' and (old.email<>new.email or old.data->>'amount' is distinct from new.data->>'amount' or old.data->>'currency' is distinct from new.data->>'currency') and (old.data->>'status'='Paid' or exists(select 1 from public.gwppro_payments where invoice=old.id and status in ('Creating','Processing','Review','Paid'))) then raise exception 'Resolve the payment before changing invoice billing details.'; end if;
 return new;
end; $$;
drop trigger if exists gwppro_invoice_payment_lock on public.gwppro_records;
create trigger gwppro_invoice_payment_lock before update on public.gwppro_records for each row execute function public.gwppro_invoice_payment_lock();
create or replace function public.gwppro_consume_recovery(p_id text) returns boolean
language plpgsql security definer set search_path='' as $$
declare found_id text;
begin
 update public.gwppro_auth_limits set attempts=1 where id=p_id and attempts=0 and expires>extract(epoch from now())*1000 returning id into found_id;
 return found_id is not null;
end; $$;
revoke all on function public.gwppro_consume_recovery(text) from public,anon,authenticated;
grant execute on function public.gwppro_consume_recovery(text) to service_role;
commit;
notify pgrst, 'reload schema';
