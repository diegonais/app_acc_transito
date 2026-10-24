// Adaptadores en RAM: las evidencias/harness 09/10/11/12 no se modifican.
import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
const wd=process.argv[2];
const repo=(name)=>fileURLToPath(new URL(name,import.meta.url));
let cases=readFileSync(repo('./storage_http_cases.mjs'),'utf8');
cases=cases.replace(/const verifier=spawn\([\s\S]*?const rows=\[\];/,"const verifier={kill(){}};\n  const rows=[];")
  .replace("(verify?'http://127.0.0.1:57523':base)+path","base+(verify?'/functions/v1/verificar-archivo':path)")
  .replace("endpoint:verify?'/verificar':","endpoint:verify?'/functions/v1/verificar-archivo':")
  .replace("'http://127.0.0.1:57523/ready'","base+'/functions/v1/verificar-archivo'")
  .replace('data?.code??data?.estado','data?.error??data?.code??data?.estado')
  .replace("new URL('./storage_http_results.json',import.meta.url)",JSON.stringify(repo('./edge_storage_http_results.json')));
const casesPath=join(wd,'edge-storage-cases.mjs');writeFileSync(casesPath,cases);
let code=readFileSync(repo('./run_auth_http_tests.mjs'),'utf8')
  .replaceAll('transito-auth-','transito-edge-').replaceAll('transito_auth_test_','transito_edge_test_')
  .replace("['auth','rest']","['auth','rest','storage','edge_runtime']")
  .replace("new URL('./support/finalization_fixtures.sql',import.meta.url)",JSON.stringify(repo('./support/finalization_fixtures.sql')))
  .replace("new URL('./auth_http_results.json',import.meta.url)",JSON.stringify(join(wd,'auth_http_results.json')));
code=code.replace("catch {throw Error('Fallo SQL local; revisar fixture sin exponer credenciales');}",
  "catch(e) {throw Error('SQL sintetico: '+String(e.stderr).split('\\n').filter(s=>/ERROR:|CONTEXT:/.test(s)).join(' ').slice(0,1200));}");
const suites=['schema_security.sql','finalization_rpc.sql','storage_security.sql'];
const statements=suites.map(name=>{
  let s=readFileSync(repo(name),'utf8');
  if(name==='schema_security.sql')s=s.replace('count(*) = 1 from pg_proc','count(*) = 2 from pg_proc')
    .replaceAll("connamespace='public'::regnamespace","connamespace='public'::regnamespace and conrelid<>'public.reservas_archivos'::regclass");
  if(name==='finalization_rpc.sql')s=s.replace('\\ir support/finalization_fixtures.sql',()=>readFileSync(repo('./support/finalization_fixtures.sql'),'utf8'));
  return s;
});
code=code.replace('const users={};',()=>statements.map((s,i)=>`console.log('SQL ${['09','10','12'][i]}: '+sql(${JSON.stringify(s)}).split('\\n').filter(Boolean).at(-1));`).join('\n')+'\nconst users={};');
code+=`\nawait (await import(${JSON.stringify(pathToFileURL(casesPath).href)})).run({wd,project,status,base,users,sql,http,check,payload,db});\n`;
code+=`\nawait (await import(${JSON.stringify(pathToFileURL(repo('./edge_http_cases.mjs')).href)})).run({wd,project,status,base,users,sql,http,check,payload,db});\n`;
const target=join(wd,'edge-test.mjs');writeFileSync(target,code);
await import(pathToFileURL(target).href);
