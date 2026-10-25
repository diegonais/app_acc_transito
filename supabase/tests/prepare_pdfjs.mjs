// Solo herramienta de construccion; no se ejecuta en Edge. Node >=20 y tar.
// Descargar una distribucion exacta y verificada, sin instalar dependencias npm.
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const version='6.4.299';
const integrity='AVl138zALtfaAPvADulE0PZThbYzCBS79nL4pOSL/6Sm/4AH5A21BD9VHt97OlCuzJuCpmeZtAtkinisF4Vb1g==';
const url=`https://registry.npmjs.org/pdfjs-dist/-/pdfjs-dist-${version}.tgz`;
const response=await fetch(url);if(!response.ok)throw Error('Distribucion PDF.js no disponible');
const tar=Buffer.from(await response.arrayBuffer());
if(createHash('sha512').update(tar).digest('base64')!==integrity)throw Error('Integridad PDF.js incorrecta');
const extract=p=>execFileSync('tar',['-xOzf','-',`package/${p}`],{input:tar,maxBuffer:10000000});
let api=extract('legacy/build/pdf.mjs').toString();
const start=api.indexOf('if (isNodeJS) {\n  let canvas;');
const end=api.indexOf('async function node_utils_fetchData',start);
if(start<0||end<start)throw Error('Cambio upstream: revisar bootstrap canvas');
api=api.slice(0,start)+'// Adaptacion de inspeccion: sin bootstrap canvas/Path2D nativo.\n'+api.slice(end);
const native='    const require = process.getBuiltinModule("module").createRequire(import.meta.url);\n    const canvas = require("@napi-rs/canvas");\n    return canvas.createCanvas(width, height);';
if(api.split(native).length!==2)throw Error('Cambio upstream: revisar NodeCanvasFactory');
api=api.replace(native,'    throw new Error("Renderizado canvas no habilitado en el verificador");');
if(api.includes('@napi-rs/canvas'))throw Error('Dependencia nativa inesperada');
const files={'pdf.mjs':Buffer.from(api),'pdf.worker.mjs':extract('legacy/build/pdf.worker.mjs'),'LICENSE':extract('LICENSE')};
const hash=b=>createHash('sha256').update(b).digest('hex');
files['manifest.json']=Buffer.from(JSON.stringify({package:'pdfjs-dist',version,source:url,sha512:integrity,adaptations:['Sin bootstrap de canvas nativo','NodeCanvasFactory falla explicitamente; no renderizado'],files:Object.fromEntries(Object.entries(files).map(([n,b])=>[n,{bytes:b.length,sha256:hash(b)}]))},null,2)+'\n');
const directory=new URL('../functions/verificar-archivo/vendor/pdfjs/',import.meta.url);
if(!process.argv.includes('--check'))mkdirSync(directory,{recursive:true});
for(const [name,bytes] of Object.entries(files)){
 const path=new URL(name,directory);
 if(process.argv.includes('--check')){if(!readFileSync(path).equals(bytes))throw Error('Vendor no reproducible: '+name);}
 else writeFileSync(path,bytes);
}
console.log(JSON.stringify({pdfjs:version,mode:process.argv.includes('--check')?'CHECK':'BUILD',directory:fileURLToPath(directory),bytes:Object.values(files).reduce((n,b)=>n+b.length,0)}));
