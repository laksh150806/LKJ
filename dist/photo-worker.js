import * as ort from './vendor/onnx/ort.wasm.min.mjs';
ort.env.wasm.numThreads=1;
ort.env.wasm.wasmPaths=new URL('./vendor/onnx/',import.meta.url).href;
self.onmessage=async ({data})=>{
 try{
  self.postMessage({status:'Loading the free cutout model…'});
  const session=await ort.InferenceSession.create(new URL('./models/u2netp.onnx',import.meta.url).href,{executionProviders:['wasm'],graphOptimizationLevel:'all'});
  const pixels=data.pixels,n=320*320,input=new Float32Array(3*n),mean=[.485,.456,.406],std=[.229,.224,.225];
  for(let c=0;c<3;c++)for(let i=0;i<n;i++)input[c*n+i]=(pixels[i*4+c]/255-mean[c])/std[c];
  self.postMessage({status:'Separating jewellery from the background…'});
  const outputs=await session.run({[session.inputNames[0]]:new ort.Tensor('float32',input,[1,3,320,320])});
  const values=outputs[session.outputNames[0]].data;let min=Infinity,max=-Infinity;for(const v of values){min=Math.min(min,v);max=Math.max(max,v)};
  if(max-min<1e-6)throw new Error('No clear subject found.');
  const mask=new Uint8ClampedArray(n);for(let i=0;i<n;i++)mask[i]=Math.round(255*(values[i]-min)/(max-min));
  await session.release();self.postMessage({mask},[mask.buffer]);
 }catch{self.postMessage({error:'Automatic cutout could not finish on this device. Try Remove a colour or the Erase / Restore brushes, or keep the original.'})}
};
