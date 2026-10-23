begin;
select set_config('request.jwt.claim.sub',(select user_id::text from shop_private.admin_account),true);
set local role authenticated;
insert into public.jewel_categories(metal,name) values('Gold','__QA shared catalogue');
insert into public.jewellery(name,metal,category,purity,weight,charge_type,charge,photos)
values('QA ring','Gold','__QA shared catalogue','22K',2,'fixed',100,array['assets/ring.jpg']);
do $$ declare before_version integer; changed integer; begin
 if not public.my_shop_access() then raise exception 'Admin permission failed'; end if;
 select version into before_version from public.jewellery where category='__QA shared catalogue';
 update public.jewellery set name='QA updated' where category='__QA shared catalogue' and version=before_version;
 if not exists(select 1 from public.jewellery where category='__QA shared catalogue' and version=before_version+1) then raise exception 'Version did not advance'; end if;
 update public.jewellery set name='QA stale overwrite' where category='__QA shared catalogue' and version=before_version;
 get diagnostics changed=row_count;
 if changed<>0 then raise exception 'Stale write was accepted'; end if;
 begin delete from public.jewel_categories where name='__QA shared catalogue'; raise exception 'Nonempty category deletion succeeded'; exception when foreign_key_violation then null; end;
 update public.jewel_categories set name='__QA renamed' where name='__QA shared catalogue';
 if not exists(select 1 from public.jewellery where category='__QA renamed') then raise exception 'Category rename did not cascade'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
set local role authenticated;
do $$ declare changed integer; begin
 if public.my_shop_access() then raise exception 'Customer gained admin'; end if;
 begin insert into public.jewel_categories(metal,name) values('Gold','__QA forbidden'); raise exception 'Customer created category'; exception when insufficient_privilege then null; end;
 begin insert into public.jewellery(name,metal,category,purity,weight,charge_type,charge,photos) values('Forbidden','Gold','__QA renamed','22K',2,'fixed',100,array['assets/ring.jpg']); raise exception 'Customer created jewellery'; exception when insufficient_privilege then null; end;
 update public.jewellery set name='Customer overwrite' where category='__QA renamed';get diagnostics changed=row_count;if changed<>0 then raise exception 'Customer edited jewellery';end if;
 delete from public.jewellery where category='__QA renamed';get diagnostics changed=row_count;if changed<>0 then raise exception 'Customer deleted jewellery';end if;
 update public.shop_settings set gold_22=1;get diagnostics changed=row_count;if changed<>0 then raise exception 'Customer changed rate';end if;
end $$;
reset role;
set local role anon;
do $$ begin
 if not exists(select 1 from public.catalogue_items where category='__QA renamed' and name='QA updated') then raise exception 'Guest cannot read jewellery';end if;
 if not exists(select 1 from public.catalogue_categories where name='__QA renamed' and product_count=1) then raise exception 'Guest count incorrect';end if;
 begin insert into public.jewel_categories(metal,name) values('Gold','__QA anonymous');raise exception 'Guest could write';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
