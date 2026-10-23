export function rateState(row,now=Date.now()){
 if(!row||row.rate_source!=='livechennai')return {label:'RATES UNAVAILABLE',message:'Automatic rates have not been verified yet'};
 const times=['gold_22','gold_18','silver_925'].map(k=>Date.parse(row.rate_source_times?.[k]));
 if(times.some(t=>!Number.isFinite(t)||now-t>36*3600000))return {label:'OLDER SOURCE RATES',message:'The source has not published recent rates · prices are indicative'};
 const checked=Date.parse(row.rate_checked_at);
 if(row.rate_sync_error||!Number.isFinite(checked)||now-checked>15*60000)return {label:'CHECK DELAYED',message:'Showing last verified rates · automatic check delayed'};
 return {label:'LIVE CHENNAI',message:'Updates automatically · checked '+new Date(checked).toLocaleTimeString('en-IN',{timeZone:'Asia/Kolkata',hour:'2-digit',minute:'2-digit'})+' IST'};
}
