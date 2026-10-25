-- Keep original compressed upload alongside each styled gallery photo, preserving reversibility.
alter table public.jewellery add column photo_originals text[] not null default '{}'::text[] check(cardinality(photo_originals)<=8 and array_position(photo_originals,null) is null);
create or replace view public.catalogue_items with(security_invoker=true) as
select j.id,j.name,j.metal,j.category,j.purity,j.weight,j.charge_type,j.charge,j.description,j.photos,j.tag,j.is_sample,j.legacy_id,j.version,j.created_at,j.updated_at,
 j.weight*r.rate+case j.charge_type when 'fixed' then j.charge when 'gram' then j.weight*j.charge else j.weight*r.rate*j.charge/100 end as preview_price,j.stock_quantity,j.photo_originals
from public.jewellery j cross join public.shop_settings s cross join lateral(select case j.purity when '22K' then s.gold_22 when '18K' then s.gold_18 else s.silver_925 end as rate) r;
