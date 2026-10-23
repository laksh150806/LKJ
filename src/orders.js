export function orderError(error){
 const safe=error?.code==='P0001'?error.message:error?.code==='42501'?'Please sign in with the correct account.':'Could not complete the request. Check your connection, then retry. Your request will not be duplicated.';
 return new Error(safe);
}
export function createOrders(client){
 async function result(query){const r=await query;if(r.error)throw orderError(r.error);return r.data;}
 return {
  submit:args=>result(client.rpc('submit_order_request',args)),
  quote:args=>result(client.rpc('quote_order_request',args)),
  respond:args=>result(client.rpc('respond_order_request',args)),
  async list({page=1,admin=false,userId,status=''}){
   let q=client.from('order_requests').select('id,status,fulfilment,estimated_subtotal,quote_expires_at,created_at,contact,version',{count:'exact'});
   if(!admin)q=q.eq('customer_id',userId);if(status)q=q.eq('status',status);
   const r=await q.order('created_at',{ascending:false}).order('id').range((page-1)*12,page*12-1);
   if(r.error)throw orderError(r.error);return {items:r.data,count:r.count};
  },
  async detail(id){const order=await result(client.from('order_requests').select('*').eq('id',id).single());const quotes=await result(client.from('order_quotes').select('*').eq('request_id',id).order('created_at',{ascending:false}));return {order,quotes};}
 };
}
