export function inventoryError(error) {
  let message='The change could not be saved online. Check your connection and try again.';
  if(error?.code==='P0001')message=error.message;
  if(error?.code==='23505')message='That name already exists. Please choose another name.';
  if(error?.code==='23503')message='This category still contains jewellery. Move or delete its pieces first.';
  if(error?.code==='42501'||error?.status===403)message='Only the shop administrator can make this change. Please sign in again.';
  return Object.assign(new Error(message),{code:error?.code,status:error?.status});
}
const fromRow = row => ({ ...row, chargeType: row.charge_type, isSample: row.is_sample, category: row.category });
const productFields = 'id,name,metal,category,purity,weight,charge_type,charge,description,photos,tag,is_sample,version,created_at,preview_price';
export function createInventory(client) {
  const bucket = client.storage.from('jewellery-images');
  function check(result) { if (result.error) throw inventoryError(result.error); return result.data; }
  async function changed(query) {
    const data = check(await query.select());
    if (!data?.length) throw Object.assign(new Error('This item changed on another device. Reload the catalogue before editing it again.'),{code:'conflict'});
    return data[0];
  }
  async function preparePhotos(photos) {
    const result = [], uploaded = [];
    try {
      for (const src of photos) {
        if (src.startsWith('data:image/')) {
          const blob = await (await fetch(src)).blob();
          if (!['image/jpeg','image/png','image/webp'].includes(blob.type) || blob.size > 5242880) throw new Error('Use a JPEG, PNG or WebP image under 5 MB.');
          const path = `${crypto.randomUUID()}.${blob.type.split('/')[1]}`;
          check(await bucket.upload(path, blob, { contentType: blob.type, cacheControl: '31536000', upsert: false }));
          uploaded.push(path); result.push(bucket.getPublicUrl(path).data.publicUrl);
        } else if (/^https:\/\//.test(src) || /^assets\/[a-z0-9.-]+$/i.test(src)) result.push(src);
        else throw new Error('This image address is not supported. Upload the photo again.');
      }
      return { photos: result, uploaded };
    } catch (error) { if (uploaded.length) await bucket.remove(uploaded); throw error; }
  }
  async function cleanupRejected(prepared,error){
    // A lost response can follow a committed write. Keep its images until the outcome is known.
    if(prepared.uploaded.length&&(/^(23|42|conflict)/.test(error.code||'')||error.status===403))await bucket.remove(prepared.uploaded);
  }
  return {
    async metadata() {
      const [categories, settings] = await Promise.all([
        client.from('catalogue_categories').select('*').order('created_at').order('name'),
        client.from('shop_settings').select('*').eq('singleton', true).single()
      ]);
      return { categories: check(categories), settings: check(settings) };
    },
    async products({metal,category,page=1,search='',sort='featured'}) {
      let query = client.from('catalogue_items').select(productFields, {count:'exact'}).eq('metal',metal).eq('category',category);
      // Only a single ilike filter: no user-controlled PostgREST expression grammar.
      if (search.trim()) query = query.ilike('name', '%'+search.trim().replace(/[\\%_]/g,'\\$&')+'%');
      query = sort==='low'||sort==='high' ? query.order('preview_price',{ascending:sort==='low'}) : query.order('created_at',{ascending:false});
      const result = await query.order('id').range((page-1)*12,page*12-1);
      return {items:check(result).map(fromRow),count:result.count||0};
    },
    async byIds(ids) {
      if (!ids.length) return [];
      const result = await client.from('catalogue_items').select(productFields).in('id', ids.slice(0,100));
      return check(result).map(fromRow);
    },
    async product(id) {
      if (!/^[0-9a-f-]{36}$/i.test(id)) return null;
      const result = await client.from('catalogue_items').select(productFields).eq('id',id).maybeSingle();
      const row=check(result);return row?fromRow(row):null;
    },
    async addCategory(metal,name) { return check(await client.from('jewel_categories').insert({metal,name:name.trim()}).select().single()); },
    async renameCategory(row,name) { return changed(client.from('jewel_categories').update({name:name.trim()}).eq('metal',row.metal).eq('name',row.name).eq('version',row.version)); },
    async deleteCategory(row) { return changed(client.from('jewel_categories').delete().eq('metal',row.metal).eq('name',row.name).eq('version',row.version)); },
    async saveCover(row,cover) {
      const prepared = cover.src ? await preparePhotos([cover.src]) : {photos:[],uploaded:[]};
      try { return await changed(client.from('jewel_categories').update({cover:{...cover,src:prepared.photos[0]||null}}).eq('metal',row.metal).eq('name',row.name).eq('version',row.version)); }
      catch(error){await cleanupRejected(prepared,error);throw error;}
    },
    async saveProduct(item,version=null,legacyId=null) {
      const prepared = await preparePhotos(item.photos);
      const row={id:item.id,name:item.name,metal:item.metal,category:item.category,purity:item.purity,weight:item.weight,charge_type:item.chargeType,charge:item.charge,description:item.description||'',photos:prepared.photos,tag:item.tag||'',is_sample:Boolean(item.isSample)};
      if(legacyId)row.legacy_id=legacyId;
      try {
        if(version!==null)return await changed(client.from('jewellery').update(row).eq('id',item.id).eq('version',version));
        return check(await client.from('jewellery').insert(row).select().single());
      }catch(error){await cleanupRejected(prepared,error);throw error;}
    },
    async importedIds() { return check(await client.from('jewellery').select('legacy_id').not('legacy_id','is',null)).map(x=>x.legacy_id); },
    async deleteProduct(item) { return changed(client.from('jewellery').delete().eq('id',item.id).eq('version',item.version)); },
    async saveSettings(row,version) { return changed(client.from('shop_settings').update(row).eq('singleton',true).eq('version',version)); }
  };
}
