-- Shared catalogue. All writes are enforced by the existing sole-admin record.
create table public.shop_settings (
 singleton boolean primary key default true check(singleton),
 gold_22 numeric(12,2) not null default 7000 check(gold_22>0),
 gold_18 numeric(12,2) not null default 5800 check(gold_18>0),
 silver_925 numeric(12,2) not null default 90 check(silver_925>0),
 gst numeric(5,2) not null default 3 check(gst between 0 and 100),
 delivery numeric(12,2) not null default 150 check(delivery>=0),
 rate_source text not null default 'sample' check(rate_source in ('sample','manual')),
 version integer not null default 1,
 updated_at timestamptz not null default now()
);
create table public.jewel_categories (
 metal text not null check(metal in ('Gold','Silver')),
 name text not null check(length(btrim(name)) between 1 and 40 and name<>'All pieces'),
 cover jsonb not null default '{}'::jsonb check(jsonb_typeof(cover)='object' and octet_length(cover::text)<20000),
 version integer not null default 1,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 primary key(metal,name)
);
create unique index jewel_categories_case_insensitive on public.jewel_categories(metal,lower(name));
create table public.jewellery (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(btrim(name)) between 1 and 80),
 metal text not null, category text not null,
 purity text not null,
 weight numeric(12,3) not null check(weight>0 and weight<=10000),
 charge_type text not null check(charge_type in ('fixed','gram','percent')),
 charge numeric(14,2) not null check(charge>=0 and charge<=10000000),
 description text not null default '' check(length(description)<=1500),
 photos text[] not null check(cardinality(photos) between 1 and 8),
 tag text not null default '' check(length(tag)<=80),
 is_sample boolean not null default false,
 legacy_id text unique,
 version integer not null default 1,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(metal,category) references public.jewel_categories(metal,name) on update cascade on delete restrict,
 check((metal='Gold' and purity in ('22K','18K')) or (metal='Silver' and purity='925')),
 check(charge_type<>'percent' or charge<=100),
 check(array_position(photos,null) is null)
);
create index jewellery_category_page on public.jewellery(metal,category,created_at desc,id);
create function shop_private.touch_catalogue_row() returns trigger language plpgsql security invoker set search_path='' as $$
begin new.version:=old.version+1; new.updated_at:=now(); return new; end $$;
revoke all on function shop_private.touch_catalogue_row() from public,anon,authenticated;
create trigger category_version before update on public.jewel_categories for each row execute function shop_private.touch_catalogue_row();
create trigger jewellery_version before update on public.jewellery for each row execute function shop_private.touch_catalogue_row();
create trigger settings_version before update on public.shop_settings for each row execute function shop_private.touch_catalogue_row();
alter table public.shop_settings enable row level security;
alter table public.jewel_categories enable row level security;
alter table public.jewellery enable row level security;
revoke all on public.shop_settings,public.jewel_categories,public.jewellery from public,anon,authenticated;
grant select on public.shop_settings,public.jewel_categories,public.jewellery to anon,authenticated;
grant insert,update,delete on public.jewel_categories,public.jewellery to authenticated;
grant update on public.shop_settings to authenticated;
create policy settings_read on public.shop_settings for select to anon,authenticated using(true);
create policy settings_admin_update on public.shop_settings for update to authenticated using((select shop_private.is_admin())) with check((select shop_private.is_admin()));
create policy categories_read on public.jewel_categories for select to anon,authenticated using(true);
create policy categories_admin_insert on public.jewel_categories for insert to authenticated with check((select shop_private.is_admin()));
create policy categories_admin_update on public.jewel_categories for update to authenticated using((select shop_private.is_admin())) with check((select shop_private.is_admin()));
create policy categories_admin_delete on public.jewel_categories for delete to authenticated using((select shop_private.is_admin()));
create policy jewellery_read on public.jewellery for select to anon,authenticated using(true);
create policy jewellery_admin_insert on public.jewellery for insert to authenticated with check((select shop_private.is_admin()));
create policy jewellery_admin_update on public.jewellery for update to authenticated using((select shop_private.is_admin())) with check((select shop_private.is_admin()));
create policy jewellery_admin_delete on public.jewellery for delete to authenticated using((select shop_private.is_admin()));
create view public.catalogue_categories with(security_invoker=true) as
select c.*, (select count(*) from public.jewellery j where j.metal=c.metal and j.category=c.name) as product_count,
(select j.photos[1] from public.jewellery j where j.metal=c.metal and j.category=c.name order by j.created_at,j.id limit 1) as first_photo
from public.jewel_categories c;
create view public.catalogue_items with(security_invoker=true) as
select j.*, j.weight*r.rate + case j.charge_type when 'fixed' then j.charge when 'gram' then j.weight*j.charge else j.weight*r.rate*j.charge/100 end as preview_price
from public.jewellery j cross join public.shop_settings s
cross join lateral (select case j.purity when '22K' then s.gold_22 when '18K' then s.gold_18 else s.silver_925 end as rate) r;
revoke all on public.catalogue_categories,public.catalogue_items from public,anon,authenticated;
grant select on public.catalogue_categories,public.catalogue_items to anon,authenticated;
insert into public.shop_settings(singleton) values(true);
insert into public.jewel_categories(metal,name,cover) values
('Gold','Rings','{"src":"assets/ring.jpg"}'),('Gold','Earrings','{"src":"assets/hero.jpg"}'),
('Gold','Necklaces','{"src":"assets/necklace.jpg"}'),('Gold','Bangles','{"src":"assets/bangle.jpg"}'),
('Silver','Rings','{"src":"assets/ring.jpg"}'),('Silver','Bracelets','{"src":"assets/bangle.jpg"}'),('Silver','Necklaces','{"src":"assets/necklace.jpg"}');
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('jewellery-images','jewellery-images',true,5242880,array['image/jpeg','image/png','image/webp']);
create policy jewellery_images_admin_select on storage.objects for select to authenticated using(bucket_id='jewellery-images' and (select shop_private.is_admin()));
create policy jewellery_images_admin_insert on storage.objects for insert to authenticated with check(bucket_id='jewellery-images' and (select shop_private.is_admin()));
create policy jewellery_images_admin_update on storage.objects for update to authenticated using(bucket_id='jewellery-images' and (select shop_private.is_admin())) with check(bucket_id='jewellery-images' and (select shop_private.is_admin()));
create policy jewellery_images_admin_delete on storage.objects for delete to authenticated using(bucket_id='jewellery-images' and (select shop_private.is_admin()));
