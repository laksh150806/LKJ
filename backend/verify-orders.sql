begin;
create temp table qa_order_ids(k text primary key,v uuid);
grant all on qa_order_ids to authenticated;
insert into qa_order_ids values('customer',gen_random_uuid()),('other',gen_random_uuid()),('product',gen_random_uuid()),('key',gen_random_uuid());
insert into auth.users(id,email,email_confirmed_at) select v,k||'-orders-qa@example.invalid',now() from qa_order_ids where k in ('customer','other');
insert into public.jewel_categories(metal,name) values('Gold','__Order QA');
insert into public.jewellery(id,name,metal,category,purity,weight,charge_type,charge,photos,stock_quantity) select v,'QA order ring','Gold','__Order QA','22K',2,'fixed',100,array['assets/ring.jpg'],0 from qa_order_ids where k='product';
-- Isolate tests from source availability; all values roll back.
update public.shop_settings set rate_source='livechennai',rate_checked_at=now(),rate_sync_error=null,rate_source_times=jsonb_build_object('gold_22',now(),'gold_18',now(),'silver_925',now());
select set_config('request.jwt.claim.sub',(select v::text from qa_order_ids where k='customer'),true);
set local role authenticated;
do $$ declare oid uuid;again uuid;contact jsonb:='{"name":"QA Customer","phone":"+919840763243","address":"Test address number 123","city":"Chennai","state":"Tamil Nadu","pincode":"600019"}';items jsonb;begin
 items:=jsonb_build_array(jsonb_build_object('id',(select v from qa_order_ids where k='product'),'qty',9,'unit_estimate',1));
 begin perform public.submit_order_request(gen_random_uuid(),contact-'address','pickup',items,true);raise exception 'Missing pickup address accepted';exception when raise_exception then if sqlerrm='Missing pickup address accepted' then raise;end if;end;
 begin perform public.submit_order_request(gen_random_uuid(),contact,'delivery',items,false);raise exception 'Missing terms accepted';exception when raise_exception then if sqlerrm='Missing terms accepted' then raise;end if;end;
 oid:=public.submit_order_request((select v from qa_order_ids where k='key'),contact,'delivery',items,true);
 again:=public.submit_order_request((select v from qa_order_ids where k='key'),contact,'delivery',items,true);
 if oid<>again then raise exception 'Duplicate submission created another order';end if;
 if (select estimated_subtotal from public.order_requests where id=oid)<>((select gold_22 from public.shop_settings)*2+100) then raise exception 'Client forged estimate';end if;
 insert into qa_order_ids values('order',oid);
 begin update public.order_requests set status='agreed' where id=oid;raise exception 'Direct status write accepted';exception when insufficient_privilege then null;end;
 begin perform public.quote_order_request(oid,1,'{}');raise exception 'Customer issued quote';exception when raise_exception then if sqlerrm='Customer issued quote' then raise;end if;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select v::text from qa_order_ids where k='other'),true);
set local role authenticated;
do $$ declare oid uuid;begin
 if exists(select 1 from public.order_requests) then raise exception 'Other customer read private request';end if;
 begin perform public.respond_order_request((select v from qa_order_ids where k='order'),1,'cancel','');raise exception 'Other customer cancelled request';exception when raise_exception then if sqlerrm='Other customer cancelled request' then raise;end if;end;
 oid:=public.submit_order_request(gen_random_uuid(),'{"name":"QA Other","phone":"+919840763243","address":"Test address number 456","city":"Chennai","state":"Tamil Nadu","pincode":"600019"}','pickup',jsonb_build_array(jsonb_build_object('id',(select v from qa_order_ids where k='product'),'qty',9)),true);
 insert into qa_order_ids values('other_order',oid);
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select user_id::text from shop_private.admin_account),true);
set local role authenticated;
do $$ declare q jsonb;qid uuid;begin
 q:=jsonb_build_object('jewellery_amount',10000.05,'gst_amount',300,'delivery_amount',100,'expected_date',(now() at time zone 'Asia/Kolkata')::date+5,'expires_at',now()+interval '24 hours','terms','Cancel before payment without charge. Shop unable to fulfil: full advance refund.');
 qid:=public.quote_order_request((select v from qa_order_ids where k='order'),1,q);
 if (select total from public.order_quotes where id=qid)<>10400.05 or (select advance_amount from public.order_quotes where id=qid)<>2080.01 or (select balance_amount from public.order_quotes where id=qid)<>8320.04 then raise exception 'Advance calculation wrong';end if;
 perform public.quote_order_request((select v from qa_order_ids where k='other_order'),1,q||'{"delivery_amount":0}'); -- Both requests can be made to order with zero stock.
 update public.jewellery set stock_quantity=0 where id=(select v from qa_order_ids where k='product');
 delete from public.jewellery where id=(select v from qa_order_ids where k='product'); -- Request snapshots survive catalogue deletion.
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select v::text from qa_order_ids where k='customer'),true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.order_quotes)<>1 then raise exception 'Own quote missing';end if;
 begin perform public.respond_order_request((select v from qa_order_ids where k='order'),1,'agree','');raise exception 'Stale quote accepted';exception when raise_exception then if sqlerrm='Stale quote accepted' then raise;end if;end;
 perform public.respond_order_request((select v from qa_order_ids where k='order'),2,'agree','');
 if not exists(select 1 from public.order_requests where status='agreed') then raise exception 'Agreement not saved';end if;
 perform public.respond_order_request((select v from qa_order_ids where k='order'),3,'cancel','');
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select user_id::text from shop_private.admin_account),true);
set local role authenticated;
do $$ declare q jsonb;begin
 q:=jsonb_build_object('jewellery_amount',10000,'gst_amount',300,'delivery_amount',0,'expected_date',(now() at time zone 'Asia/Kolkata')::date+5,'expires_at',now()+interval '24 hours','terms','Cancel before payment without charge. Shop unable to fulfil: full advance refund.');
 perform public.quote_order_request((select v from qa_order_ids where k='other_order'),2,q);
end $$;
reset role;
update public.order_requests set quote_expires_at=now()-interval '1 minute' where id=(select v from qa_order_ids where k='other_order');
select set_config('request.jwt.claim.sub',(select v::text from qa_order_ids where k='other'),true);
set local role authenticated;
do $$ begin
 begin perform public.respond_order_request((select v from qa_order_ids where k='other_order'),4,'agree','');raise exception 'Expired quote accepted';exception when raise_exception then if sqlerrm='Expired quote accepted' then raise;end if;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select user_id::text from shop_private.admin_account),true);
set local role authenticated;
do $$ begin
 perform public.respond_order_request((select v from qa_order_ids where k='other_order'),4,'reject','This piece is no longer available.');
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select v::text from qa_order_ids where k='other'),true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.order_quotes where request_id<>(select v from qa_order_ids where k='other_order')) then raise exception 'Other customer can read someone else quote';end if;
 if not exists(select 1 from public.order_requests where status='rejected' and note='This piece is no longer available.') then raise exception 'Rejection reason missing';end if;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform count(*) from public.order_requests;raise exception 'Guest read orders';exception when insufficient_privilege then null;end;
 begin perform public.submit_order_request(gen_random_uuid(),'{}','pickup','[]',true);raise exception 'Guest submitted order';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
