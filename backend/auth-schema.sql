-- Applied to pjwhuowljtglrtjxmuzj through the Supabase migrations tool.
-- No admin is seeded. Provision only the user-selected, verified account later.
create schema if not exists shop_private;
revoke all on schema shop_private from public, anon, authenticated;
grant usage on schema shop_private to authenticated;
create table shop_private.admin_account (
 singleton boolean primary key default true check (singleton),
 user_id uuid not null unique references auth.users(id) on delete cascade
);
revoke all on shop_private.admin_account from public, anon, authenticated;
alter table shop_private.admin_account enable row level security;
create policy no_client_access on shop_private.admin_account for all to anon, authenticated using (false) with check (false);
create function shop_private.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists (
  select 1 from shop_private.admin_account a join auth.users u on u.id=a.user_id
  where a.user_id=auth.uid() and u.email_confirmed_at is not null and u.deleted_at is null
 );
$$;
revoke all on function shop_private.is_admin() from public, anon;
grant execute on function shop_private.is_admin() to authenticated;
create table public.customer_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 preferred_name text not null check (char_length(btrim(preferred_name)) between 1 and 80),
 created_at timestamptz not null default now()
);
alter table public.customer_profiles enable row level security;
revoke all on public.customer_profiles from public, anon, authenticated;
grant select, insert, update on public.customer_profiles to authenticated;
create policy read_own_profile on public.customer_profiles for select to authenticated using ((select auth.uid()) = user_id or (select shop_private.is_admin()));
create policy create_own_profile on public.customer_profiles for insert to authenticated with check ((select auth.uid()) = user_id);
create policy update_own_profile on public.customer_profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create function public.my_shop_access() returns boolean language sql stable security invoker set search_path = '' as $$ select shop_private.is_admin(); $$;
revoke all on function public.my_shop_access() from public, anon;
grant execute on function public.my_shop_access() to authenticated;
