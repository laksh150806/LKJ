import {copyFile,mkdir} from 'node:fs/promises';
await mkdir('dist/vendor/onnx',{recursive:true});
for(const file of ['ort.wasm.min.mjs','ort-wasm-simd-threaded.mjs','ort-wasm-simd-threaded.wasm'])await copyFile('node_modules/onnxruntime-web/dist/'+file,'dist/vendor/onnx/'+file);
