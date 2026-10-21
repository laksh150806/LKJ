begin;
create temporary table lk_test_accounts (a uuid, b uuid);
insert into lk_test_accounts values (gen_random_uuid(), gen_random_uuid());
insert into auth.users(id, email, email_confirmed_at, raw_user_meta_data)
select a, a::text || '@example.invalid', now(), '{"role":"admin"}'::jsonb from lk_test_accounts
union all select b, b::text || '@example.invalid', now(), '{}'::jsonb from lk_test_accounts;
select set_config('request.jwt.claim.sub', a::text, true), set_config('lk.test.other_user', b::text, true) from lk_test_accounts;
set local role authenticated;
insert into public.customer_profiles(user_id, preferred_name) values (auth.uid(), 'Profile A');
do $$ begin
  if public.my_shop_access() then raise exception 'Self promotion succeeded'; end if;
  begin
    insert into public.customer_profiles(user_id, preferred_name) values (current_setting('lk.test.other_user')::uuid, 'Not mine');
    raise exception 'Cross-account insert succeeded';
  exception when insufficient_privilege then null; end;
  begin
    update public.customer_profiles set user_id=current_setting('lk.test.other_user')::uuid where user_id=auth.uid();
    raise exception 'Ownership reassignment succeeded';
  exception when insufficient_privilege then null; end;
  update public.customer_profiles set preferred_name='Updated A' where user_id=auth.uid();
  if not exists(select 1 from public.customer_profiles where preferred_name='Updated A') then raise exception 'Own profile update failed'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub', b::text, true) from lk_test_accounts;
set local role authenticated;
do $$ begin
  if exists(select 1 from public.customer_profiles) then raise exception 'Other customer can read profile A'; end if;
  if public.my_shop_access() then raise exception 'Second customer has admin access'; end if;
end $$;
reset role;
rollback;
