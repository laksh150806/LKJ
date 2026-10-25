// Original RGB pixels are never regenerated. Edits change the alpha mask only.
function canvas(w,h){const c=document.createElement('canvas');c.width=w;c.height=h;return c;}
async function loadImage(src){return new Promise((resolve,reject)=>{const img=new Image();img.crossOrigin='anonymous';const timer=setTimeout(()=>{img.src='';reject(new Error('Photo could not load. Please upload it again.'))},20000);img.onload=()=>{clearTimeout(timer);resolve(img)};img.onerror=()=>{clearTimeout(timer);reject(new Error('Photo could not load. Please upload it again.'))};img.src=src;});}
export async function openPhotoStudio({original,current,onApply}){
 let worker,timer,closed=false,busy=false,style='cream',mode='view',drawing=false,last=null,comparing=false;
 const dialog=document.createElement('dialog');dialog.className='photo-studio';
 dialog.innerHTML=`<div class="studio-heading"><div><small>PHOTO BACKGROUNDS</small><h2>A setting for your jewellery</h2></div><button type="button" id="studioClose" aria-label="Close photo editor">×</button></div><p>Choose a background, create a cutout and preview it before saving. Your original photo is kept.</p><div class="studio-layout"><div><canvas id="studioCanvas" aria-label="Photo preview; use erase, restore or colour removal tools to refine"></canvas><button type="button" id="studioCompare" class="secondary">View original</button></div><div class="studio-tools"><div class="studio-styles" role="group" aria-label="Background style"><button type="button" data-style="cream" class="selected" aria-pressed="true"><span class="swatch cream"></span>Warm Cream</button><button type="button" data-style="velvet" aria-pressed="false"><span class="swatch velvet"></span>Midnight Blue Velvet</button></div><button type="button" id="studioAuto" class="primary">Remove background automatically</button><p class="studio-status" id="studioStatus" role="status">Free processing on your device. First use downloads about 17 MB. Thin chains may need a touch-up.</p><label>Touch-up tool<select id="studioTool"><option value="view">Preview only</option><option value="colour">Remove a colour · tap the background</option><option value="erase">Erase background · brush</option><option value="restore">Restore jewellery · brush</option></select></label><label>Brush size<input id="studioBrush" type="range" min="3" max="100" value="25"></label><label>Colour removal tolerance<input id="studioTolerance" type="range" min="10" max="180" value="65"></label><p class="studio-hint">Zoom in with your browser to inspect chain links. Restore brings back the original pixels. Colour removal works best on a plain contrasting background.</p><div class="studio-history"><button type="button" id="studioUndo" class="secondary" disabled>Undo</button><button type="button" id="studioReset" class="secondary">Reset cutout</button></div><label class="checks studio-confirm"><input id="studioReviewed" type="checkbox"><span>I checked that the chain, stones and design are intact.</span></label><button type="button" id="studioApply" class="primary" disabled>Use this background</button><button type="button" id="studioOriginal" class="text-button">Use original photo</button><small>These are preset backgrounds. They do not recreate the jewellery or generate a new scene.</small></div></div>`;
 document.body.append(dialog);dialog.showModal();const $=s=>dialog.querySelector(s),preview=$('#studioCanvas');
 function stop(){worker?.terminate();worker=null;clearTimeout(timer);busy=false;$('#studioAuto').disabled=false;}
 function close(){closed=true;stop();dialog.close();dialog.remove();}
 $('#studioClose').onclick=close;dialog.addEventListener('cancel',e=>{e.preventDefault();close()});
 try{
  const img=await loadImage(original);if(closed)return;
  const scale=Math.min(1,900/Math.max(img.width,img.height)),w=Math.round(img.width*scale),h=Math.round(img.height*scale);
  const source=canvas(w,h),mask=canvas(w,h),cutout=canvas(w,h),output=canvas(w,h);source.getContext('2d').drawImage(img,0,0,w,h);const sx=source.getContext('2d'),mx=mask.getContext('2d'),cx=cutout.getContext('2d'),ox=output.getContext('2d');preview.width=w;preview.height=h;const px=preview.getContext('2d');
  const originalData=sx.getImageData(0,0,w,h),history=[];let changed=false,velvet=null;
  mx.fillStyle='white';mx.fillRect(0,0,w,h);
  const invalidate=()=>{$('#studioReviewed').checked=false;$('#studioApply').disabled=true;};
  function render(){
   ox.clearRect(0,0,w,h);
   if(style==='velvet'&&velvet){const factor=Math.max(w/velvet.width,h/velvet.height);ox.drawImage(velvet,(w-velvet.width*factor)/2,(h-velvet.height*factor)/2,velvet.width*factor,velvet.height*factor)}
   else if(style==='velvet'){ox.fillStyle='#09283e';ox.fillRect(0,0,w,h)}
   else{const gradient=ox.createRadialGradient(w*.3,h*.2,0,w*.5,h*.5,Math.max(w,h));gradient.addColorStop(0,'#fff7e8');gradient.addColorStop(1,'#dbc7a8');ox.fillStyle=gradient;ox.fillRect(0,0,w,h)}
   cx.clearRect(0,0,w,h);cx.globalCompositeOperation='source-over';cx.drawImage(source,0,0);cx.globalCompositeOperation='destination-in';cx.drawImage(mask,0,0);cx.globalCompositeOperation='source-over';
   ox.drawImage(cutout,0,0);px.clearRect(0,0,w,h);px.drawImage(comparing?source:output,0,0);
  }
  function saveUndo(){history.push(mx.getImageData(0,0,w,h));if(history.length>5)history.shift();$('#studioUndo').disabled=false;changed=true;invalidate();}
  function applyResult(src){if(closed)return;onApply(src);close();}
  $('#studioOriginal').onclick=()=>applyResult(original);
  $('#studioApply').onclick=()=>{if(!busy&&changed&&$('#studioReviewed').checked)applyResult(output.toDataURL('image/jpeg',.9))};
  $('#studioReviewed').onchange=()=>{$('#studioApply').disabled=busy||!changed||!$('#studioReviewed').checked};
  $('#studioCompare').onclick=()=>{comparing=!comparing;$('#studioCompare').textContent=comparing?'View edited preview':'View original';render()};
  for(const button of dialog.querySelectorAll('[data-style]'))button.onclick=async()=>{style=button.dataset.style;invalidate();for(const b of dialog.querySelectorAll('[data-style]')){b.classList.toggle('selected',b===button);b.setAttribute('aria-pressed',String(b===button))}if(style==='velvet'&&!velvet){try{velvet=await loadImage(new URL('./assets/backgrounds/midnight-velvet.png',import.meta.url).href)}catch{$('#studioStatus').textContent='Velvet texture could not load. Please retry when your connection returns.';style='cream'}}if(!closed)render()};
  $('#studioTool').onchange=e=>{mode=e.target.value;preview.style.touchAction=mode==='view'?'auto':'none';preview.style.cursor=mode==='view'?'default':'crosshair';};
  $('#studioReset').onclick=()=>{if(busy)return;saveUndo();mx.globalCompositeOperation='source-over';mx.fillStyle='white';mx.fillRect(0,0,w,h);changed=false;render()};
  $('#studioUndo').onclick=()=>{if(busy)return;const previous=history.pop();if(previous){mx.putImageData(previous,0,0);invalidate();render()}$('#studioUndo').disabled=!history.length};
  const position=e=>{const r=preview.getBoundingClientRect();const scale=Math.min(r.width/w,r.height/h),left=r.left+(r.width-w*scale)/2,top=r.top+(r.height-h*scale)/2;return {x:Math.max(0,Math.min(w-1,(e.clientX-left)/scale)),y:Math.max(0,Math.min(h-1,(e.clientY-top)/scale))}};
  function brush(point){mx.globalCompositeOperation=mode==='erase'?'destination-out':'source-over';mx.strokeStyle='white';mx.fillStyle='white';mx.lineWidth=Number($('#studioBrush').value)*w/500;mx.lineCap='round';mx.beginPath();mx.moveTo(last?.x??point.x,last?.y??point.y);mx.lineTo(point.x,point.y);mx.stroke();mx.beginPath();mx.arc(point.x,point.y,mx.lineWidth/2,0,Math.PI*2);mx.fill();mx.globalCompositeOperation='source-over';last=point;render()}
  preview.onpointerdown=e=>{if(busy||comparing||mode==='view')return;e.preventDefault();const point=position(e);saveUndo();if(mode==='colour'){const data=mx.getImageData(0,0,w,h),p=(Math.floor(point.y)*w+Math.floor(point.x))*4,t=Number($('#studioTolerance').value);for(let i=0;i<data.data.length;i+=4){const d=Math.hypot(originalData.data[i]-originalData.data[p],originalData.data[i+1]-originalData.data[p+1],originalData.data[i+2]-originalData.data[p+2]);if(d<t)data.data[i+3]=0;}mx.putImageData(data,0,0);render();return;}drawing=true;last=null;preview.setPointerCapture(e.pointerId);brush(point)};
  preview.onpointermove=e=>{if(drawing)brush(position(e))};preview.onpointerup=preview.onpointercancel=()=>{drawing=false;last=null};
  $('#studioAuto').onclick=()=>{
   if(busy)return;busy=true;invalidate();$('#studioAuto').disabled=true;$('#studioStatus').textContent='Preparing photo…';
   const small=canvas(320,320);small.getContext('2d').drawImage(source,0,0,320,320);const pixels=small.getContext('2d').getImageData(0,0,320,320).data;
   worker=new Worker(new URL('./photo-worker.js',import.meta.url),{type:'module'});
   timer=setTimeout(()=>{stop();$('#studioStatus').textContent='This device is taking too long. Use the touch-up tools or keep the original.';},120000);
   worker.onerror=()=>{stop();$('#studioStatus').textContent='Automatic cutout could not load. Use the touch-up tools or keep the original.'};
   worker.onmessage=({data})=>{if(closed)return;if(data.status)$('#studioStatus').textContent=data.status;if(data.error){stop();$('#studioStatus').textContent=data.error}if(data.mask){stop();saveUndo();const tiny=canvas(320,320),tx=tiny.getContext('2d'),rgba=tx.createImageData(320,320);for(let i=0;i<data.mask.length;i++){rgba.data[i*4]=255;rgba.data[i*4+1]=255;rgba.data[i*4+2]=255;rgba.data[i*4+3]=data.mask[i]}tx.putImageData(rgba,0,0);mx.clearRect(0,0,w,h);mx.drawImage(tiny,0,0,w,h);render();$('#studioStatus').textContent='Cutout ready. Inspect the fine chain and stones; use Restore or Erase to correct it before saving.';}};
   worker.postMessage({pixels},[pixels.buffer]);
  };
  render();
 }catch(e){if(!closed){$('#studioStatus').textContent=e.message;$('#studioAuto').disabled=true;$('#studioOriginal').onclick=close;}}
}
