-- Request-first orders. Payment and paid/confirmed transitions are deliberately absent.
alter table public.jewellery add column stock_quantity integer not null default 0 check(stock_quantity between 0 and 100000);
-- Existing view column order must remain stable; append stock after preview_price.
create or replace view public.catalogue_items with(security_invoker=true) as
select j.id,j.name,j.metal,j.category,j.purity,j.weight,j.charge_type,j.charge,j.description,j.photos,j.tag,j.is_sample,j.legacy_id,j.version,j.created_at,j.updated_at,
 j.weight*r.rate+case j.charge_type when 'fixed' then j.charge when 'gram' then j.weight*j.charge else j.weight*r.rate*j.charge/100 end as preview_price,j.stock_quantity
from public.jewellery j cross join public.shop_settings s cross join lateral(select case j.purity when '22K' then s.gold_22 when '18K' then s.gold_18 else s.silver_925 end as rate) r;
create table public.order_requests(
 id uuid primary key default gen_random_uuid(),customer_id uuid not null references auth.users(id),request_key uuid not null,
 contact jsonb not null,fulfilment text not null check(fulfilment in ('delivery','pickup')),
 items jsonb not null,estimated_subtotal numeric(16,2) not null check(estimated_subtotal>0),rate_snapshot jsonb not null,
 status text not null default 'pending' check(status in ('pending','quoted','agreed','rejected','cancelled')),
 quote_id uuid,quote_expires_at timestamptz,note text not null default '',terms_version text not null default 'request-v1',
 agreed_at timestamptz,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(customer_id,request_key)
);
create table public.order_quotes(
 id uuid primary key default gen_random_uuid(),request_id uuid not null references public.order_requests(id),
 jewellery_amount numeric(14,2) not null check(jewellery_amount>0 and jewellery_amount<=100000000),
 gst_amount numeric(14,2) not null check(gst_amount>=0 and gst_amount<=100000000),
 delivery_amount numeric(14,2) not null check(delivery_amount>=0 and delivery_amount<=1000000),
 total numeric(16,2) not null,advance_amount numeric(16,2) not null,balance_amount numeric(16,2) not null,
 expected_date date not null,expires_at timestamptz not null,terms text not null check(length(terms) between 20 and 3000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now()
);
alter table public.order_requests add foreign key(quote_id) references public.order_quotes(id);
create index order_requests_customer_page on public.order_requests(customer_id,created_at desc,id);
create index order_requests_status_page on public.order_requests(status,created_at desc,id);
create index order_requests_quote_idx on public.order_requests(quote_id);
create index order_quotes_request_idx on public.order_quotes(request_id,created_at desc);
create index order_quotes_creator_idx on public.order_quotes(created_by);
create trigger order_version before update on public.order_requests for each row execute function shop_private.touch_catalogue_row();
alter table public.order_requests enable row level security;
alter table public.order_quotes enable row level security;
revoke all on public.order_requests,public.order_quotes from public,anon,authenticated;
grant select on public.order_requests,public.order_quotes to authenticated;
create policy orders_read on public.order_requests for select to authenticated using(customer_id=(select auth.uid()) or (select shop_private.is_admin()));
create policy quotes_read on public.order_quotes for select to authenticated using(exists(select 1 from public.order_requests o where o.id=request_id));

create function public.submit_order_request(p_key uuid,p_contact jsonb,p_method text,p_items jsonb,p_terms boolean) returns uuid
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
  if coalesce(entry->>'qty','') !~ '^[1-9][0-9]?$' then raise exception 'Quantity must be from 1 to 10.';end if;
  n:=(entry->>'qty')::integer;if n>10 then raise exception 'Quantity must be from 1 to 10.';end if;
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

create function shop_private.reserved_units(pid uuid,except_order uuid default null) returns integer language sql stable security definer set search_path='' as $$
 select coalesce(sum((i->>'qty')::integer),0)::integer from public.order_requests o cross join lateral jsonb_array_elements(o.items) i
 where o.status in ('quoted','agreed') and o.quote_expires_at>now() and (except_order is null or o.id<>except_order) and i->>'id'=pid::text;
$$;
revoke all on function shop_private.reserved_units(uuid,uuid) from public,anon,authenticated;
create function shop_private.guard_reserved_stock() returns trigger language plpgsql security definer set search_path='' as $$
declare reserved integer;begin
 reserved:=shop_private.reserved_units(old.id);
 if (tg_op='DELETE' and reserved>0) or (tg_op='UPDATE' and new.stock_quantity<reserved) then raise exception 'This stock is held by active quotes. Cancel or wait for those quotes before reducing it.';end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function shop_private.guard_reserved_stock() from public,anon,authenticated;
create trigger reserved_stock before update of stock_quantity or delete on public.jewellery for each row execute function shop_private.guard_reserved_stock();

create function public.quote_order_request(p_id uuid,p_version integer,p_quote jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare o public.order_requests%rowtype;j public.jewellery%rowtype;i jsonb;qid uuid;ja numeric;ga numeric;da numeric;total_amount numeric;expiry timestamptz;eta date;terms text;
begin
 if not shop_private.is_admin() then raise exception 'Only the shop administrator can issue a quote.';end if;
 select * into o from public.order_requests where id=p_id for update;
 if not found or o.version is distinct from p_version or o.status not in ('pending','quoted','agreed') then raise exception 'This request changed. Reload before continuing.';end if;
 ja:=(p_quote->>'jewellery_amount')::numeric;ga:=(p_quote->>'gst_amount')::numeric;da:=(p_quote->>'delivery_amount')::numeric;
 expiry:=(p_quote->>'expires_at')::timestamptz;eta:=(p_quote->>'expected_date')::date;terms:=btrim(p_quote->>'terms');
 if ja is null or ja<=0 or ja>100000000 or ga is null or ga<0 or ga>100000000 or da is null or da<0 or da>1000000 or ja<>round(ja,2) or ga<>round(ga,2) or da<>round(da,2) then raise exception 'Enter valid amounts with at most two decimal places.';end if;
 if o.fulfilment='pickup' and da<>0 then raise exception 'Shop pickup has no delivery charge.';end if;
 if expiry is null or expiry<=now() or expiry>now()+interval '7 days' then raise exception 'Quote validity must be in the future and within seven days.';end if;
 if eta is null or eta<(now() at time zone 'Asia/Kolkata')::date or eta>(now() at time zone 'Asia/Kolkata')::date+365 then raise exception 'Enter an expected date within the next year.';end if;
 if coalesce(length(terms),0) not between 20 and 3000 then raise exception 'Include clear cancellation and refund terms.';end if;
 -- Consistent row-lock order prevents two accepted requests promising the same stock.
 for i in select value from jsonb_array_elements(o.items) order by value->>'id' loop
  select * into j from public.jewellery where id=(i->>'id')::uuid for update;
  if not found or j.is_sample then raise exception 'A requested piece is no longer available.';end if;
  if j.stock_quantity-shop_private.reserved_units(j.id,o.id)<(i->>'qty')::integer then raise exception 'Not enough unreserved stock. Update quantity or reject the request.';end if;
 end loop;
 total_amount:=ja+ga+da;
 insert into public.order_quotes(request_id,jewellery_amount,gst_amount,delivery_amount,total,advance_amount,balance_amount,expected_date,expires_at,terms,created_by)
 values(o.id,ja,ga,da,total_amount,round(total_amount*0.20,2),total_amount-round(total_amount*0.20,2),eta,expiry,terms,auth.uid()) returning id into qid;
 update public.order_requests set status='quoted',quote_id=qid,quote_expires_at=expiry,agreed_at=null,note='' where id=o.id;
 return qid;
end $$;

create function public.respond_order_request(p_id uuid,p_version integer,p_action text,p_note text default '') returns void language plpgsql security definer set search_path='' as $$
declare o public.order_requests%rowtype;begin
 select * into o from public.order_requests where id=p_id for update;
 if not found or (o.customer_id is distinct from auth.uid() and not shop_private.is_admin()) then raise exception 'Request unavailable.';end if;
 if o.version is distinct from p_version then raise exception 'This request changed. Reload before continuing.';end if;
 if p_action='reject' and shop_private.is_admin() and o.status in ('pending','quoted','agreed') then
  if coalesce(length(btrim(p_note)),0) not between 3 and 1000 then raise exception 'Provide a reason for the customer.';end if;
  update public.order_requests set status='rejected',note=btrim(p_note) where id=o.id;
 elsif p_action='cancel' and o.customer_id=auth.uid() and o.status in ('pending','quoted','agreed') then
  update public.order_requests set status='cancelled',note='Cancelled by customer before payment.' where id=o.id;
 elsif p_action='agree' and o.customer_id=auth.uid() and o.status='quoted' then
  if o.quote_expires_at<=now() then raise exception 'This quote has expired. Ask the shop for a new quote.';end if;
  update public.order_requests set status='agreed',agreed_at=now() where id=o.id;
 else raise exception 'This action is not available for this request.';end if;
end $$;
revoke all on function public.submit_order_request(uuid,jsonb,text,jsonb,boolean),public.quote_order_request(uuid,integer,jsonb),public.respond_order_request(uuid,integer,text,text) from public,anon,authenticated;
grant execute on function public.submit_order_request(uuid,jsonb,text,jsonb,boolean),public.quote_order_request(uuid,integer,jsonb),public.respond_order_request(uuid,integer,text,text) to authenticated;
