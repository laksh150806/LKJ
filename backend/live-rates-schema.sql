-- Live Chennai polling, private scheduler authentication, and public freshness metadata.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
alter table public.shop_settings drop constraint shop_settings_rate_source_check;
alter table public.shop_settings add constraint shop_settings_rate_source_check check(rate_source in ('sample','manual','livechennai'));
alter table public.shop_settings add column rate_source_times jsonb not null default '{}'::jsonb,
 add column rate_checked_at timestamptz,
 add column rate_sync_error text;
-- Cron owns a private random token. Never return its value to a browser or commit it.
select vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'lk_rate_job_token');
create function public.authorize_rate_job(job_token text) returns boolean language sql security definer set search_path='' as $$
 select exists(select 1 from vault.decrypted_secrets where name='lk_rate_job_token' and decrypted_secret=job_token);
$$;
revoke all on function public.authorize_rate_job(text) from public,anon,authenticated;
grant execute on function public.authorize_rate_job(text) to service_role;
-- Admin still owns GST and delivery; the worker alone owns automatically sourced rates.
revoke update on public.shop_settings from authenticated;
grant update(gst,delivery) on public.shop_settings to authenticated;
select cron.schedule('lk-livechennai-rates','*/5 * * * *',$job$
 select net.http_post(
  url:='https://pjwhuowljtglrtjxmuzj.supabase.co/functions/v1/sync-metal-rates',
  headers:=jsonb_build_object('Content-Type','application/json','x-rate-job-token',(select decrypted_secret from vault.decrypted_secrets where name='lk_rate_job_token')),
  body:='{}'::jsonb,timeout_milliseconds:=40000);
$job$);
