-- Made-to-order designs: no stock management or reservation restrictions.
-- Keep the unused legacy stock column for compatibility with already-open older clients.
drop trigger if exists reserved_stock on public.jewellery;
drop function if exists shop_private.guard_reserved_stock();
create or replace function public.submit_order_request(p_key uuid,p_contact jsonb,p_method text,p_items jsonb,p_terms boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); oid uuid; r public.shop_settings%rowtype; j public.jewellery%rowtype; entry jsonb; n integer; rate numeric; unit numeric; amount numeric:=0; snapshots jsonb:='[]';
begin
 if uid is null or not exists(select 1 from auth.users where id=uid and email_confirmed_at is not null and deleted_at is null) then raise exception 'Sign in with a verified email first.';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select id into oid from public.order_requests where customer_id=uid and request_key=p_key;if oid is not null then return oid;end if;
 if p_key is null or p_terms is distinct from true then raise exception 'Accept the request terms to continue.';end if;
 if p_method is null or p_method not in ('delivery','pickup') then raise exception 'Choose delivery or shop pickup.';end if;
 if jsonb_typeof(p_contact) is distinct from 'object' or
 coalesce(length(btrim(p_contact->>'name')),0) not between 1 and 80 or
 coalesce(p_contact->>'phone','') !~ '^\+91[6-9][0-9]{9}$' or
 coalesce(length(btrim(p_contact->>'address')),0) not between 10 and 500 or
 coalesce(length(btrim(p_contact->>'city')),0) not between 2 and 80 or
 coalesce(length(btrim(p_contact->>'state')),0) not between 2 and 80 or
 coalesce(p_contact->>'pincode','') !~ '^[1-9][0-9]{5}$' then raise exception 'Enter your name, Indian mobile number and full address for delivery or pickup.';end if;
 if jsonb_typeof(p_items) is distinct from 'array' then raise exception 'Choose jewellery first.';end if;
 if jsonb_array_length(p_items) not between 1 and 50 then raise exception 'Choose between 1 and 50 different pieces.';end if;
 if (select count(distinct x->>'id') from jsonb_array_elements(p_items) x)<>jsonb_array_length(p_items) then raise exception 'Duplicate jewellery in request.';end if;
 if (select count(*) from public.order_requests where customer_id=uid and created_at>now()-interval '1 day')>=20 then raise exception 'Daily request limit reached. Please contact the shop.';end if;
 select * into r from public.shop_settings where singleton;
 if r.rate_source<>'livechennai' or r.rate_checked_at is null or r.rate_checked_at<now()-interval '15 minutes' or r.rate_sync_error is not null then raise exception 'Metal rates are being refreshed. Please try again shortly.';end if;
 for entry in select value from jsonb_array_elements(p_items) loop
  n:=1; -- One request per selected design; no customer quantity input.
  select * into j from public.jewellery where id=(entry->>'id')::uuid;
  if not found or j.is_sample then raise exception 'A piece is unavailable. Refresh your bag.';end if;
  if coalesce((r.rate_source_times->>case j.purity when '22K' then 'gold_22' when '18K' then 'gold_18' else 'silver_925' end)::timestamptz,'epoch')<now()-interval '36 hours' then raise exception 'The source rate is old. Please contact the shop for an estimate.';end if;
  rate:=case j.purity when '22K' then r.gold_22 when '18K' then r.gold_18 else r.silver_925 end;
  unit:=round(j.weight*rate+case j.charge_type when 'fixed' then j.charge when 'gram' then j.weight*j.charge else j.weight*rate*j.charge/100 end,2);
  snapshots:=snapshots||jsonb_build_array(jsonb_build_object('id',j.id,'name',j.name,'metal',j.metal,'purity',j.purity,'weight',j.weight,'qty',n,'unit_estimate',unit,'photo',j.photos[1],'rate',rate,'shop_charge',unit-j.weight*rate));amount:=amount+unit*n;
 end loop;
 insert into public.order_requests(customer_id,request_key,contact,fulfilment,items,estimated_subtotal,rate_snapshot)
 values(uid,p_key,jsonb_build_object('name',btrim(p_contact->>'name'),'phone',p_contact->>'phone','address',btrim(p_contact->>'address'),'city',btrim(p_contact->>'city'),'state',btrim(p_contact->>'state'),'pincode',p_contact->>'pincode'),p_method,snapshots,amount,jsonb_build_object('source',r.rate_source,'source_times',r.rate_source_times,'checked_at',r.rate_checked_at)) returning id into oid;
 return oid;
end $$;

create or replace function public.quote_order_request(p_id uuid,p_version integer,p_quote jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare o public.order_requests%rowtype;qid uuid;ja numeric;ga numeric;da numeric;total_amount numeric;expiry timestamptz;eta date;terms text;
begin
 if not shop_private.is_admin() then raise exception 'Only the shop administrator can issue a quote.';end if;
 select * into o from public.order_requests where id=p_id for update;
 if not found or o.version is distinct from p_version or o.status not in ('pending','quoted','agreed') then raise exception 'This request changed. Reload before continuing.';end if;
 ja:=(p_quote->>'jewellery_amount')::numeric;ga:=(p_quote->>'gst_amount')::numeric;da:=(p_quote->>'delivery_amount')::numeric;
 expiry:=(p_quote->>'expires_at')::timestamptz;eta:=(p_quote->>'expected_date')::date;terms:=btrim(p_quote->>'terms');
 if ja is null or ja<=0 or ja>100000000 or ga is null or ga<0 or ga>100000000 or da is null or da<0 or da>1000000 or ja<>round(ja,2) or ga<>round(ga,2) or da<>round(da,2) then raise exception 'Enter valid amounts with at most two decimal places.';end if;
 if o.fulfilment='pickup' and da<>0 then raise exception 'Collecting from the shop has no delivery charge.';end if;
 if expiry is null or expiry<=now() or expiry>now()+interval '7 days' then raise exception 'Quote validity must be in the future and within seven days.';end if;
 if eta is null or eta<(now() at time zone 'Asia/Kolkata')::date or eta>(now() at time zone 'Asia/Kolkata')::date+365 then raise exception 'Enter an expected date within the next year.';end if;
 if coalesce(length(terms),0) not between 20 and 3000 then raise exception 'Include clear cancellation and refund terms.';end if;
 total_amount:=ja+ga+da;
 insert into public.order_quotes(request_id,jewellery_amount,gst_amount,delivery_amount,total,advance_amount,balance_amount,expected_date,expires_at,terms,created_by)
 values(o.id,ja,ga,da,total_amount,round(total_amount*0.20,2),total_amount-round(total_amount*0.20,2),eta,expiry,terms,auth.uid()) returning id into qid;
 update public.order_requests set status='quoted',quote_id=qid,quote_expires_at=expiry,agreed_at=null,note='' where id=o.id;
 return qid;
end $$;

drop function if exists shop_private.reserved_units(uuid,uuid);
