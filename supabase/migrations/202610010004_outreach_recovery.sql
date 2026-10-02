-- Atomic outreach delivery state. Frozen requests can be retried safely within
-- a conservative 23-hour provider idempotency window. No email is sent by SQL.
begin;
create or replace function public.gwppro_begin_outreach(p_id text,p_payload jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare r public.gwppro_records; attempt text; payload jsonb; requested timestamptz;
begin
 select * into r from public.gwppro_records where id=p_id and kind='lead' for update;
 if not found or r.data->>'sentAt' is not null or r.data->>'status' not in ('Message Ready','Sending') then raise exception 'This message cannot be sent.';end if;
 if exists(select 1 from public.gwppro_records where kind='lead' and email=r.email and data->>'status'='Do not contact') then raise exception 'This contact is suppressed.';end if;
 if r.data->>'status'='Sending' and (r.data->>'outreachAttemptAt' is null or (r.data->>'outreachAttemptAt')::timestamptz>clock_timestamp()-interval '60 seconds') then raise exception 'This message is already being processed.';end if;
 requested:=coalesce((r.data->>'outreachRequestedAt')::timestamptz,clock_timestamp());
 if requested<clock_timestamp()-interval '23 hours' then raise exception 'The retry window has expired. Review delivery in Resend before sending another message.';end if;
 payload:=coalesce(r.data->'outreachPayload',p_payload);
 if jsonb_typeof(payload)<>'object' or payload->>'to' is distinct from r.email or coalesce(payload->>'text','')='' or coalesce(payload->>'from','')='' then raise exception 'Outreach request is incomplete.';end if;
 attempt:=gen_random_uuid()::text;
 update public.gwppro_records set data=data||jsonb_build_object('status','Sending','outreachRequestedAt',requested,'outreachPayload',payload,'outreachAttempt',attempt,'outreachAttemptAt',clock_timestamp()),updated=clock_timestamp() where id=p_id;
 return jsonb_build_object('attempt',attempt,'payload',payload);
end $$;
create or replace function public.gwppro_finish_outreach(p_id text,p_attempt text,p_sent boolean,p_provider_id text default '') returns boolean
language plpgsql security invoker set search_path='' as $$
declare n integer;
begin
 -- Only this attempt may finish. Merge fields into the current row, preserving
 -- concurrent suppression and edits rather than restoring a stale snapshot.
 update public.gwppro_records set data=data||
 case when p_sent then jsonb_build_object('status',case when data->>'status'='Sending' then 'Contacted' else data->>'status' end,'sentAt',clock_timestamp(),'outreachProviderId',p_provider_id)
 else jsonb_build_object('status','Message Ready') end,updated=clock_timestamp()
 where id=p_id and kind='lead' and data->>'outreachAttempt'=p_attempt
 and (p_sent or data->>'status'='Sending');
 get diagnostics n=row_count;return n=1;
end $$;
revoke all on function public.gwppro_begin_outreach(text,jsonb),public.gwppro_finish_outreach(text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.gwppro_begin_outreach(text,jsonb),public.gwppro_finish_outreach(text,text,boolean,text) to service_role;
commit;
