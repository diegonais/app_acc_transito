// Reusa SIN EDITAR la suite 11; copia efimera, resultados 11 fuera del repositorio.
import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
const wd=process.argv[2];
const source=new URL('./run_auth_http_tests.mjs',import.meta.url);
let code=readFileSync(source,'utf8')
  .replaceAll('transito-auth-','transito-storage-').replaceAll('transito_auth_test_','transito_storage_test_')
  .replace("['auth','rest']","['auth','rest','storage']")
  .replace("new URL('./support/finalization_fixtures.sql',import.meta.url)",JSON.stringify(fileURLToPath(new URL('./support/finalization_fixtures.sql',import.meta.url))))
  .replace("new URL('./auth_http_results.json',import.meta.url)",JSON.stringify(join(wd,'auth_http_results.json')));
code=code.replace("catch {throw Error('Fallo SQL local; revisar fixture sin exponer credenciales');}",
  "catch(e) {throw Error('SQL sintetico: '+String(e.stderr).split('\\n').filter(s=>/ERROR:|CONTEXT:/.test(s)).join(' ').slice(0,1200));}");
// SQL de regresion acumulado. 09 contaba un solo helper DEFINER; 12 añade uno
// acotado para RLS Storage. Solo adaptar esa expectativa de catalogo en RAM.
const suites=['schema_security.sql','finalization_rpc.sql','storage_security.sql'];
const statements=suites.map(name=>{
  let s=readFileSync(new URL(name,import.meta.url),'utf8');
  if(name==='schema_security.sql') s=s.replace('count(*) = 1 from pg_proc','count(*) = 2 from pg_proc')
    .replace('un solo definer acotado','dos helpers definer acotados (09 + Storage 12)')
    .replaceAll("connamespace='public'::regnamespace","connamespace='public'::regnamespace and conrelid<>'public.reservas_archivos'::regclass");
  if(name==='finalization_rpc.sql')s=s.replace('\\ir support/finalization_fixtures.sql',()=>readFileSync(new URL('./support/finalization_fixtures.sql',import.meta.url),'utf8'));
  return s;
});
const anchor="const users={};";
code=code.replace(anchor,()=>statements.map((s,i)=>`console.log('SQL ${['09','10','12'][i]}: '+sql(${JSON.stringify(s)}).split('\\n').filter(Boolean).at(-1));`).join('\n')+'\n'+anchor);
const storageModule=pathToFileURL(fileURLToPath(new URL('./storage_http_cases.mjs',import.meta.url))).href;
code+=`\nawait (await import(${JSON.stringify(storageModule)})).run({wd,project,status,base,users,sql,http,check,payload,db});\n`;
const target=join(wd,'storage-test.mjs');
writeFileSync(target,code);
await import(pathToFileURL(target).href);
