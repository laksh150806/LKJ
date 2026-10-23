import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { parseRates } from './parser.js';
const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
Deno.serve(async req=>{
 if(req.method!=='POST')return new Response('Method not allowed',{status:405});
 const token=req.headers.get('x-rate-job-token');
 if(!token||token.length>200)return new Response('Unauthorized',{status:401});
 const {data:allowed,error:authError}=await client.rpc('authorize_rate_job',{job_token:token});
 if(authError||!allowed)return new Response('Unauthorized',{status:401});
 try{
  const pages=await Promise.all(['gold_silverrate.asp','18k_goldrate_chennai.asp'].map(async page=>{
   const r=await fetch('https://www.livechennai.com/'+page,{signal:AbortSignal.timeout(15000),headers:{'User-Agent':'LKJewellers-RateSync/1.0'},redirect:'error'});
   if(!r.ok)throw new Error('Source unavailable');const html=await r.text();if(html.length>2000000)throw new Error('Source too large');return html;
  }));
  const rates=parseRates(pages[0],pages[1]);
  const {data:old,error:readError}=await client.from('shop_settings').select('rate_source_times').eq('singleton',true).single();
  if(readError)throw readError;
  for(const key of Object.keys(rates.rate_source_times)){if(old?.rate_source_times?.[key]&&Date.parse(rates.rate_source_times[key])<Date.parse(old.rate_source_times[key]))throw new Error('Source timestamp moved backwards');}
  const {error}=await client.from('shop_settings').update(rates).eq('singleton',true);if(error)throw error;
  return Response.json({ok:true,checked_at:rates.rate_checked_at});
 }catch{
  await client.from('shop_settings').update({rate_sync_error:'Automatic rate check failed. Showing the last verified rates.'}).eq('singleton',true);
  return Response.json({ok:false,error:'Rate check failed; previous verified values retained.'},{status:502});
 }
});
