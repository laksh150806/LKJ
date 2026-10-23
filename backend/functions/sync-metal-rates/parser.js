// Source HTML is untrusted. Require labelled tables, dates, units and matching totals.
const plain = s => s.replace(/<[^>]*>/g,' ').replace(/&nbsp;|&#160;/gi,' ').replace(/\s+/g,' ').trim();
function table(html,label) {
 const tables=[...html.matchAll(/<table\b[^>]*>[\s\S]*?<\/table>/gi)].map(x=>x[0]);
 const found=tables.find(t=>label.test(plain(t)));
 if(!found)throw new Error('Source table changed');
 const rows=[...found.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)].map(x=>[...x[1].matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/gi)].map(c=>plain(c[1])));
 const row=rows.find(r=>/^\d{1,2}\/[A-Za-z]+\/\d{4}$/.test(r[0]||''));
 if(!row)throw new Error('Source date missing');
 return row;
}
function day(s){const m=s.match(/^(\d{1,2})\/([A-Za-z]+)\/(\d{4})$/);const month=['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'].indexOf(m?.[2].slice(0,3).toLowerCase());if(!m||month<0)throw new Error('Invalid source date');return `${m[3]}-${String(month+1).padStart(2,'0')}-${m[1].padStart(2,'0')}`;}
function value(s){if(!/^[\d,]+(?:\.\d{1,2})?$/.test(s||''))throw new Error('Invalid source price');const n=Number(s.replaceAll(',',''));if(!Number.isFinite(n)||n<=0||n>10000000)throw new Error('Invalid source price');return n;}
function time(html,date){const text=plain(html);const m=text.match(/last update time:\s*(?:(\d{1,2})\/(\d{1,2})\/(\d{4})\s+)?(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)/i);if(!m)throw new Error('Source timestamp missing');if(m[1]&&`${m[3]}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`!==date)throw new Error('Source dates disagree');const h=Number(m[4]);if(h<1||h>12||+m[5]>59||+m[6]>59)throw new Error('Invalid source time');return new Date(`${date}T${String(h%12+(m[7].toUpperCase()==='PM'?12:0)).padStart(2,'0')}:${m[5]}:${m[6]}+05:30`).toISOString();}
export function parseRates(main,eighteen,now=Date.now()){
 const g=table(main,/Pure Gold \(24 k\).*Standard Gold \(22 K\)/i),s=table(main,/Silver 1 Gm.*Ready Silver \(1 Kg\)/i),e=table(eighteen,/18k Gold Rate.*1 \(grm\)/i);
 if(g.length!==5||s.length!==3||e.length!==4)throw new Error('Source columns changed');
 const gd=day(g[0]),sd=day(s[0]),ed=day(e[0]);
 const gold24=value(g[1]),gold22=value(g[3]),silver=value(s[1]),gold18=value(e[1]);
 if(Math.abs(value(g[2])-gold24*8)>1||Math.abs(value(g[4])-gold22*8)>1||Math.abs(value(s[2])-silver*1000)>1||Math.abs(value(e[2])-gold18*8)>1||Math.abs(value(e[3])-gold18*10)>1||gold18>=gold22||gold22>=gold24)throw new Error('Source unit validation failed');
 const stamps={gold_22:time(main.slice(main.indexOf('Chennai Gold Rate')),gd),silver_925:time(main.slice(main.indexOf('Chennai Silver Rate')),sd),gold_18:time(eighteen,ed)};
 for(const stamp of Object.values(stamps)){const age=now-Date.parse(stamp);if(age< -300000||age>72*3600000)throw new Error('Source rates are out of date');}
 return {gold_22:gold22,gold_18:gold18,silver_925:silver,rate_source:'livechennai',rate_source_times:stamps,rate_checked_at:new Date(now).toISOString(),rate_sync_error:null};
}
