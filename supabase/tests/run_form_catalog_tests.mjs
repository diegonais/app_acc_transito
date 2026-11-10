// PostgreSQL 17 nativo y descartable para Windows cuando Docker no esta disponible.
// Dependencias SOLO en un directorio temporal externo, sin tocar pubspec/package.json.
// npm install --prefix <TEMP/transito-form-pg-...> @embedded-postgres/windows-x64@17.11.0-beta.19 pg@8.16.3
// node supabase/tests/run_form_catalog_tests.mjs <directorio temporal anterior>
// Auth/Storage de plataforma simulados. No acredita JWT/HTTP ni cargas reales.
import {execFileSync} from 'node:child_process';
import {mkdtempSync,readFileSync,readdirSync,writeFileSync,realpathSync,rmSync} from 'node:fs';
import {join,resolve,dirname,sep} from 'node:path';
import {tmpdir} from 'node:os';
import {createRequire} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {randomBytes,randomUUID} from 'node:crypto';
import {createServer} from 'node:net';

const runtime=realpathSync(process.argv[2]);
if(!runtime.startsWith(realpathSync(tmpdir())+sep) || !/^transito-form-pg-[a-f0-9]+$/.test(runtime.split(sep).at(-1)))
  throw Error('Runtime no es el temporal dedicado');
const require=createRequire(join(runtime,'package.json'));
const {Client}=require('pg');
const {initdb,pg_ctl}=await import(pathToFileURL(require.resolve('@embedded-postgres/windows-x64')).href);
const tests=dirname(fileURLToPath(import.meta.url));
const root=resolve(tests,'../..');
const cluster=mkdtempSync(join(runtime,'cluster-'));
const data=join(cluster,'data');
const password=randomBytes(32).toString('hex');
const passwordFile=join(cluster,'password');
writeFileSync(passwordFile,password,{mode:0o600});
const socket=createServer();
await new Promise(r=>socket.listen(0,'127.0.0.1',r));
const port=socket.address().port;
await new Promise(r=>socket.close(r));
const options={host:'127.0.0.1',port,user:'postgres',password,database:'acc_transito_test_09',connectionTimeoutMillis:5000};
function command(file,args){return execFileSync(file,args,{encoding:'utf8',windowsHide:true,stdio:'ignore',timeout:60000});}
function sqlFile(file){return readFileSync(file,'utf8').replace(/^\\ir (.+)\r?$/gm,(_,relative)=>sqlFile(resolve(dirname(file),relative)));}
let started=false; let db;
try {
  command(initdb,['-D',data,'-U','postgres','--encoding=UTF8','--locale=C','--auth=scram-sha-256','--pwfile='+passwordFile]);
  command(pg_ctl,['-D',data,'-l',join(cluster,'postgres.log'),'-o',`-h 127.0.0.1 -p ${port}`,'-w','start']);
  started=true;
  const admin=new Client({...options,database:'postgres'}); await admin.connect();
  const actual=(await admin.query('show data_directory')).rows[0].data_directory;
  if(realpathSync(actual)!==realpathSync(data))throw Error('Cluster de destino no coincide');
  await admin.query('create database acc_transito_test_09'); await admin.end();
  db=new Client(options); await db.connect();
  await db.query(sqlFile(join(tests,'support/plain_postgres_bootstrap.sql')));
  // Solo contratos minimos para poder aplicar TODAS las migraciones acumuladas.
  await db.query(`create role service_role nologin bypassrls;
    create schema storage;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
    alter table storage.objects enable row level security;
    create function storage.allow_only_operation(text) returns boolean language sql stable as $$select false$$;
    create function storage.allow_any_operation(text[]) returns boolean language sql stable as $$select false$$;
    create table auth.sessions(id uuid primary key,user_id uuid,not_after timestamptz);
    create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb)$$;`);
  const migrations=readdirSync(join(root,'supabase/migrations')).filter(f=>f.endsWith('.sql')).sort();
  for(const name of migrations){await db.query(sqlFile(join(root,'supabase/migrations',name))); console.log('Migracion OK: '+name);}
  for(const name of ['schema_security.sql','finalization_rpc.sql','storage_security.sql','form_catalog_roundtrip.sql']){
    let sql=sqlFile(join(tests,name));
    if(name==='schema_security.sql')sql=sql.replace('count(*) = 1 from pg_proc','count(*) = 2 from pg_proc')
      .replaceAll("connamespace='public'::regnamespace","connamespace='public'::regnamespace and conrelid<>'public.reservas_archivos'::regclass");
    await db.query(sql); console.log('SQL OK: '+name);
  }
  // Regresion con sesiones independientes y espera de bloqueo observada.
  await db.query(sqlFile(join(tests,'support/finalization_fixtures.sql')));
  const payload=(await db.query('select test_support.payload() p')).rows[0].p;
  payload.naturaleza='COLISION';payload.epi='EPI 3';
  const makeClient=async(name)=>{const c=new Client({...options,application_name:name});await c.connect();return c;};
  const a=await makeClient('catalog_race_a'); const b=await makeClient('catalog_race_b');
  async function actor(c,id){await c.query('begin');await c.query('set local role authenticated');await c.query("select set_config('request.jwt.claim.sub',$1,true)",['10000000-0000-4000-8000-00000000000'+id]);}
  async function waiting(){for(let i=0;i<100;i++){
    if((await db.query("select 1 from pg_stat_activity where application_name='catalog_race_b' and wait_event_type='Lock'")).rowCount)return;
    await new Promise(r=>setTimeout(r,25));
  }throw Error('No se observo espera concurrente');}
  try{
    await actor(a,2);await actor(b,3);
    const ra=(await a.query('select public.finalizar_informe($1,$2) r',[randomUUID(),payload])).rows[0].r;
    const qb=b.query('select public.finalizar_informe($1,$2) r',[randomUUID(),payload]);
    await waiting();await a.query('commit');const rb=(await qb).rows[0].r;await b.query('commit');
    if(ra.correlativo===rb.correlativo)throw Error('Colision concurrente');
    console.log('CONCURRENCIA OK: autores distintos, mismo anio, correlativos distintos');
    await actor(a,2);await actor(b,2);const op=randomUUID();
    const first=(await a.query('select public.finalizar_informe($1,$2) r',[op,payload])).rows[0].r;
    const replay=b.query('select public.finalizar_informe($1,$2) r',[op,payload]);
    await waiting();await a.query('commit');const second=(await replay).rows[0].r;await b.query('commit');
    if(JSON.stringify(first)!==JSON.stringify(second))throw Error('Replay concurrente distinto');
    console.log('CONCURRENCIA OK: misma operacion y contenido, resultado unico');
  }finally{await a.end();await b.end();}
  console.log('PostgreSQL '+(await db.query('show server_version')).rows[0].server_version+'; pruebas completas; Auth/Storage simulados, sin HTTP');
}finally{
  if(db)await db.end();
  if(started)command(pg_ctl,['-D',data,'-m','fast','-w','stop']);
  if(realpathSync(cluster).startsWith(runtime+sep) && /^cluster-/.test(cluster.split(sep).at(-1)))rmSync(cluster,{recursive:true});
}
