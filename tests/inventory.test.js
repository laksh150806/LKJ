import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createInventory, inventoryError} from '../src/inventory.js';
function fakeClient(result) {
 const calls=[];
 const chain={then:(resolve,reject)=>Promise.resolve(result).then(resolve,reject)};
 for(const name of ['select','eq','ilike','order','range','update','delete','insert','single'])chain[name]=(...args)=>{calls.push([name,...args]);return chain};
 return {calls,client:{from:()=>chain,storage:{from:()=>({})}}};
}
test('catalogue requests a bounded page and safely escapes literal search wildcards', async()=>{
 const {client,calls}=fakeClient({data:[{id:'piece',charge_type:'fixed',is_sample:false}],count:28});
 const page=await createInventory(client).products({metal:'Gold',category:'Rings',page:2,search:'20%_off',sort:'low'});
 assert.equal(page.count,28);assert.equal(page.items[0].chargeType,'fixed');
 assert.deepEqual(calls.find(c=>c[0]==='range'),['range',12,23]);
 assert.deepEqual(calls.find(c=>c[0]==='ilike'),['ilike','name','%20\\%\\_off%']);
 assert.deepEqual(calls.filter(c=>c[0]==='order').map(c=>c[1]),['preview_price','id']);
});
test('an optimistic-concurrency miss is not reported as a successful deletion', async()=>{
 const {client,calls}=fakeClient({data:[]});
 await assert.rejects(createInventory(client).deleteProduct({id:'piece',version:4}),/another device/);
 assert.ok(calls.some(c=>c[0]==='eq'&&c[1]==='version'&&c[2]===4));
});
test('foreign-key and authorization failures have specific messages',()=>{
 assert.match(inventoryError({code:'23503'}).message,/still contains jewellery/);
 assert.match(inventoryError({code:'42501'}).message,/administrator/);
});
test('failed multi-photo upload removes newly uploaded orphan photos',async()=>{
 let uploads=0,removed=[];
 const storage={upload:async()=>++uploads===1?{data:{}}:{error:{status:403}},getPublicUrl:path=>({data:{publicUrl:'https://example.com/'+path}}),remove:async paths=>{removed=paths;return {data:[]}}};
 const api=createInventory({storage:{from:()=>storage}});
 const photo='data:image/png;base64,iVBORw0KGgo=';
 await assert.rejects(api.saveProduct({photos:[photo,photo]}),/administrator/);
 assert.equal(uploads,2);assert.equal(removed.length,1);
});

test('an uncertain database response never deletes images that may already be referenced',async()=>{
 const {client}=fakeClient({error:{message:'Network response lost'}});
 let removed=0;
 client.storage.from=()=>({upload:async()=>({data:{}}),getPublicUrl:path=>({data:{publicUrl:'https://example.com/'+path}}),remove:async()=>{removed++;return {data:[]}}});
 await assert.rejects(createInventory(client).saveProduct({id:crypto.randomUUID(),photos:['data:image/png;base64,iVBORw0KGgo=']}),/could not be saved/);
 assert.equal(removed,0);
});
