// Supabase LOCAL real. Node >=20, sin dependencias ni credenciales versionadas.
// Preparacion y limpieza: run_auth_http_tests.ps1. No usar el bootstrap simulado.
// Solo imprime y guarda filas de evidencia permitidas; tokens/claves/passwords
// permanecen en memoria. Nunca imprimir errores fetch/CLI sin sanear.
import {execSync, execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync, realpathSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {resolve, join} from 'node:path';
import {tmpdir} from 'node:os';
import httpEngine from 'node:http';

process.on('uncaughtException',e=>{console.error(e.code?'Fallo de herramienta local; salida retenida por confidencialidad':e.message);process.exitCode=1;});

const wd = realpathSync(process.argv[2] ?? '');
if (!wd.startsWith(realpathSync(tmpdir())) || !/transito-auth-[a-f0-9]+$/.test(wd) || /["&|%]/.test(wd)) throw Error('Destino temporal invalido');
const config = readFileSync(join(wd,'supabase/config.toml'),'utf8');
const project = config.match(/^project_id = "(transito_auth_test_[a-f0-9]+)"/m)?.[1];
if (!project) throw Error('Proyecto no dedicado');
// La CLI 2.122 publica HostIp=0.0.0.0. Recrear SOLO nuestros contenedores
// manteniendo configuracion/volumen, antes de crear identidades. Secretos solo RAM.
async function engine(method,path,body,raw=false) {
  return await new Promise((resolve,reject)=>{
    const req=httpEngine.request({socketPath:'\\\\.\\pipe\\dockerDesktopLinuxEngine',path:'/v1.55'+path,method,
      headers:body?{'Content-Type':Buffer.isBuffer(body)?'application/x-tar':'application/json'}:{}},res=>{
      const chunks=[];res.on('data',d=>chunks.push(d));res.on('end',()=>{
        if(res.statusCode>=300)return reject(Error(`Docker API ${method}: HTTP ${res.statusCode}`));
        const out=Buffer.concat(chunks);
        resolve(raw?out:(out.length?JSON.parse(out.toString()):null));
      });
    });req.on('error',()=>reject(Error('Docker Engine API local no disponible')));
    req.end(body?(Buffer.isBuffer(body)?body:JSON.stringify(body)):undefined);
  });
}
for(const service of ['db','kong']) {
  const name=`supabase_${service}_${project}`;
  const i=JSON.parse(execFileSync('docker',['inspect',name],{encoding:'utf8'}))[0];
  checkProject(i);
  if(Object.values(i.HostConfig.PortBindings??{}).flat().some(b=>b.HostIp!=='127.0.0.1')) {
    // La CLI copia certificados/configuracion dentro del contenedor Kong.
    // Preservar su archivo tar SOLO en RAM, incluyendo cualquier dato sensible.
    const archive=service==='kong'?await engine('GET',`/containers/${i.Id}/archive?path=/home/kong`,undefined,true):null;
    const hc=structuredClone(i.HostConfig);
    for(const binds of Object.values(hc.PortBindings))for(const b of binds)b.HostIp='127.0.0.1';
    const endpoints=Object.fromEntries(Object.entries(i.NetworkSettings.Networks).map(([n,v])=>[n,
      {NetworkID:v.NetworkID,Aliases:(v.Aliases??[]).filter(a=>a!==i.Id&&a!==i.Id.slice(0,12))}]));
    await engine('POST',`/containers/${i.Id}/stop?t=20`);
    await engine('DELETE',`/containers/${i.Id}?v=false`);
    const created=await engine('POST',`/containers/create?name=${encodeURIComponent(name)}`,
      {...i.Config,HostConfig:hc,NetworkingConfig:{EndpointsConfig:endpoints}});
    if(archive)await engine('PUT',`/containers/${created.Id}/archive?path=/home`,archive);
    await engine('POST',`/containers/${created.Id}/start`);
  }
}
function checkProject(i) {if(i.Config.Labels['com.supabase.cli.project']!==project)throw Error('Contenedor no pertenece al stack dedicado');}
// Renovar pools tras recrear PostgreSQL: evita conexiones al backend detenido.
for(const service of ['auth','rest']) {
  const name=`supabase_${service}_${project}`;
  const i=JSON.parse(execFileSync('docker',['inspect',name],{encoding:'utf8'}))[0];checkProject(i);
  await engine('POST',`/containers/${i.Id}/restart?t=10`);
}
for(let n=0;n<60;n++) {
  const running=JSON.parse(execFileSync('docker',['inspect',`supabase_db_${project}`,`supabase_kong_${project}`,`supabase_auth_${project}`],{encoding:'utf8'}));
  for(const i of running)for(const binds of Object.values(i.HostConfig.PortBindings??{}))
    check(binds.every(b=>b.HostIp==='127.0.0.1'),'Puerto de test no limitado a localhost');
  if(running.every(i=>i.State.Health?.Status==='healthy'))break;
  await new Promise(r=>setTimeout(r,500));
}
const db = `supabase_db_${project}`;
const inspected = JSON.parse(execFileSync('docker',['inspect',db],{encoding:'utf8'}))[0];
if (inspected.Config.Labels['com.supabase.cli.project'] !== project) throw Error('Identidad Docker inesperada');
const status = JSON.parse(execSync(`npx --yes supabase@2.122.0 --workdir "${wd}" status -o json`,{encoding:'utf8',stdio:['pipe','pipe','pipe']}));
const base = status.API_URL;
if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(base)) throw Error('API no es localhost');
if (!status.ANON_KEY || !status.SERVICE_ROLE_KEY) throw Error('CLI no devolvio claves locales esperadas');
const results=[];
function check(ok,msg) { if (!ok) throw Error(msg); }
function sql(statement) {
  try {return execFileSync('docker',['exec','-i',db,'psql','-X','-q','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:statement,encoding:'utf8',stdio:['pipe','pipe','pipe']}).trim();}
  catch {throw Error('Fallo SQL local; revisar fixture sin exponer credenciales');}
}
async function http(actor,method,path,body,expected,options={}) {
  const headers={apikey:status.ANON_KEY,'Content-Type':'application/json'};
  if(options.admin) {headers.apikey=status.SERVICE_ROLE_KEY;headers.Authorization=`Bearer ${status.SERVICE_ROLE_KEY}`;}
  else if(actor?.token) headers.Authorization=`Bearer ${actor.token}`;
  if(options.schema) headers[method==='GET'?'Accept-Profile':'Content-Profile']=options.schema;
  let r; try {r=await fetch(base+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});}
  catch {throw Error('Solicitud localhost fallo o excedio tiempo');}
  const text=await r.text();let data;try {data=text?JSON.parse(text):null;}catch {data=null;}
  if(expected) check(expected.includes(r.status),`${actor?.name??'anon'} ${method} ${path.split('?')[0]}: HTTP ${r.status} inesperado; codigo ${String(data?.code??data?.error_code??'sin codigo').replace(/[^A-Za-z0-9_]/g,'').slice(0,40)}`);
  results.push({actor:actor?.name??'anon',method,endpoint:path.split('?')[0],status:r.status,code:typeof data?.code==='string'?data.code:null,resultado:'esperado'});
  return {status:r.status,data};
}
const users={};
for(const name of ['ADMIN','POLICE_A','POLICE_B','INACTIVO','SIN_PERFIL','NO_APROVISIONADO','PERFIL_INACTIVO']) {
  const email=`${name.toLowerCase()}-${randomUUID()}@example.test`;
  const password=`Aa1!${randomUUID()}${randomUUID().slice(0,16)}`;
  const created=await http({name},'POST','/auth/v1/admin/users',{email,password,email_confirm:true,user_metadata:{rol:'ADMIN'}},[200,201],{admin:true});
  const id=created.data.id??created.data.user?.id;
  check(typeof id==='string' && /^[a-f0-9-]{36}$/.test(id),'Auth no creo UUID');
  const login=await http({name},'POST','/auth/v1/token?grant_type=password',{email,password},[200]);
  const token=login.data.access_token;
  check(typeof token==='string','Login sin access token');
  const claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString());
  check(claims.sub===id && claims.role==='authenticated' && !!claims.session_id,'Claims/sesion no coherentes');
  const actor={name,id,token};users[name]=actor;
  const verified=await http(actor,'GET','/auth/v1/user',undefined,[200]);
  check(verified.data.id===id,'Auth no confirma identidad JWT');
  check(sql(`select count(*) from auth.sessions where id='${claims.session_id}' and user_id='${id}';`)==='1','Sesion Auth inexistente');
}
check(sql('select count(*) from public.usuarios;')==='0','Autoaprovisionamiento de rol inesperado');
for(const actor of Object.values(users)) {
  if(actor.name==='NO_APROVISIONADO')continue;
  const row=sql(`insert into public.usuarios(auth_uid,nombre_usuario,rol,estado,fecha_creacion,fecha_modificacion)
    values('${actor.id}','sintetico_${actor.name}','${actor.name==='ADMIN'?'ADMIN':'POLICE'}',${actor.name==='INACTIVO'?0:1},'2026-10-24','2026-10-24') returning id_usuario;`);
  actor.userId=Number(row);
  if(!['ADMIN','SIN_PERFIL'].includes(actor.name)) {
    actor.policeId=Number(sql(`insert into public.policias(id_usuario,numero_placa,grado,nombres,apellidos,unidad,sigla,ci,estado,fecha_creacion,fecha_modificacion)
      values(${actor.userId},'FICTICIA_${actor.name}','Grado ficticio','Nombre','${actor.name}','Unidad ficticia','TEST','CI ficticio',${actor.name==='PERFIL_INACTIVO'?0:1},'2026-10-24','2026-10-24') returning id_policia;`));
  }
}
// Obtener el payload sintetico existente sin crear el esquema de fixtures SQL.
const fixture=readFileSync(new URL('./support/finalization_fixtures.sql',import.meta.url),'utf8');
const payload=JSON.parse(fixture.match(/select '(\{[\s\S]*?\})'::jsonb/)[1]);
const endpoint='/rest/v1/rpc/finalizar_informe';
const op=randomUUID();
const a=(await http(users.POLICE_A,'POST',endpoint,{operation_id:op,payload},[200])).data;
const b=(await http(users.POLICE_B,'POST',endpoint,{operation_id:randomUUID(),payload},[200])).data;
check(a.gestion===2025 && b.gestion===2025 && a.numero_caso!==b.numero_caso,'Correlativo/gestion erroneos');
const retry=(await http(users.POLICE_A,'POST',endpoint,{operation_id:op,payload:Object.fromEntries(Object.entries(payload).reverse())},[200])).data;
check(JSON.stringify(a)===JSON.stringify(retry),'Respuesta perdida genera otro resultado');
await http(users.POLICE_A,'POST',endpoint,{operation_id:op,payload:{...payload,lugar:'Distinto'}},[409]);
await http(users.POLICE_B,'POST',endpoint,{operation_id:op,payload},[403]);
for(const key of ['rol','id_policia','gestion','policia_nombre_snapshot']) {
  await http(users.POLICE_A,'POST',endpoint,{operation_id:randomUUID(),payload:{...payload,[key]:'MANIPULADO'}},[400]);
}
await http(users.POLICE_A,'POST',endpoint,{operation_id:randomUUID(),payload:{...payload,fecha_hora_hecho:'2025-02-30T12:00:00.000'}},[400]);
await http(users.POLICE_A,'POST',endpoint,{operation_id:randomUUID(),payload:{...payload,fotografias:[{objeto:'falso'}]}},[422]);
await http(users.POLICE_A,'POST',endpoint,{operation_id:randomUUID(),payload:{...payload,ruta_croquis:'falso.png'}},[422]);
for(const name of ['ADMIN','INACTIVO','SIN_PERFIL','NO_APROVISIONADO','PERFIL_INACTIVO']) {
  await http(users[name],'POST',endpoint,{operation_id:randomUUID(),payload},[403]);
}
await http(null,'POST',endpoint,{operation_id:randomUUID(),payload},[401]);
check(sql('select count(*) from public.informes;')==='2','Negativos alteraron cabeceras');
check(sql('select count(*) from app_private.operaciones_finalizacion;')==='2','Negativos dejaron operaciones');
check(sql('select ultimo_correlativo from app_private.contadores_gestion where gestion=2025;')==='2','Negativos consumieron contador');
for(const [name,expected] of [['ADMIN',2],['POLICE_A',1],['POLICE_B',1],['INACTIVO',0],['SIN_PERFIL',0],['NO_APROVISIONADO',0],['PERFIL_INACTIVO',0]]) {
  const rows=(await http(users[name],'GET','/rest/v1/informes?select=id_informe',undefined,[200])).data;
  check(rows.length===expected,`RLS informes ${name}`);
}
await http(null,'GET','/rest/v1/informes?select=id_informe',undefined,[401]);
for(const table of ['informes','conductores','vehiculos','personas_involucradas','fotografias','archivos_informe']) {
  for(const actor of [users.ADMIN,users.POLICE_A]) {
    const own=(await http(actor,'GET',`/rest/v1/${table}?id_informe=eq.${a.id_informe}`,undefined,[200])).data;
    check(own.length===(['fotografias','archivos_informe'].includes(table)?0:1),`Relacionado autorizado ${table}`);
  }
  for(const actor of [users.POLICE_B,users.NO_APROVISIONADO,users.INACTIVO]) {
    const rows=(await http(actor,'GET',`/rest/v1/${table}?${table==='informes'?'id_informe':'id_informe'}=eq.${a.id_informe}`,undefined,[200])).data;
    check(rows.length===0,`ID directo ajeno visible ${table}`);
  }
  for(const actor of [users.POLICE_A,null]) {
    const denied=actor?[403]:[401];
    await http(actor,'POST',`/rest/v1/${table}`,{},denied);
    const field={informes:'descripcion',conductores:'nombre_completo',vehiculos:'marca',personas_involucradas:'nombre',fotografias:'descripcion',archivos_informe:'objeto'}[table];
    await http(actor,'PATCH',`/rest/v1/${table}?id_informe=eq.${a.id_informe}`,{[field]:'MANIPULADO'},denied);
    await http(actor,'DELETE',`/rest/v1/${table}?id_informe=eq.${a.id_informe}`,undefined,denied);
  }
}
for(const table of ['usuarios','policias']) {
  for(const actor of [users.POLICE_A,null]) {
    const denied=actor?[403]:[401];
    await http(actor,'POST',`/rest/v1/${table}`,{},denied);
    await http(actor,'PATCH',`/rest/v1/${table}?id_usuario=eq.${users.POLICE_A.userId}`,table==='usuarios'?{rol:'ADMIN'}:{nombres:'Alterado'},denied);
    await http(actor,'DELETE',`/rest/v1/${table}?id_usuario=eq.${users.POLICE_A.userId}`,undefined,denied);
  }
}
for(const actor of [users.POLICE_A,null]) {
  await http(actor,'GET','/rest/v1/operaciones_finalizacion',undefined,[404]);
  await http(actor,'POST','/rest/v1/rpc/finalizar_informe_impl',{},[404]);
  await http(actor,'POST','/rest/v1/rpc/actor',{},[404]);
  await http(actor,'POST','/rest/v1/rpc/finalizar_informe_impl',{},[406],{schema:'app_private'});
  for(const method of ['POST','PATCH','DELETE'])
    await http(actor,method,'/rest/v1/operaciones_finalizacion',method==='DELETE'?undefined:{},[406],{schema:'app_private'});
}
const snapshot=JSON.parse(sql(`select json_build_object('id_policia',id_policia,'nombre',policia_nombre_snapshot,'placa',policia_placa_snapshot,'grado',policia_grado_snapshot,'unidad',policia_unidad_snapshot) from public.informes where id_informe=${a.id_informe};`));
check(snapshot.id_policia===users.POLICE_A.policeId && snapshot.nombre==='Nombre POLICE_A' && snapshot.placa==='FICTICIA_POLICE_A' && snapshot.grado==='Grado ficticio' && snapshot.unidad==='Unidad ficticia','Snapshot incorrecto');
// Dos peticiones independientes simultaneas, ademas de concurrencia SQL del harness 10.
const concurrent=await Promise.all([users.POLICE_A,users.POLICE_B].map(actor=>http(actor,'POST',endpoint,{operation_id:randomUUID(),payload},[200])));
check(concurrent[0].data.correlativo!==concurrent[1].data.correlativo,'HTTP concurrente duplico numero');
const sameOp=randomUUID();
const identical=await Promise.all([1,2].map(()=>http(users.POLICE_A,'POST',endpoint,{operation_id:sameOp,payload},[200])));
check(JSON.stringify(identical[0].data)===JSON.stringify(identical[1].data),'HTTP idempotente duplico informe');
check(sql('select count(*) from public.informes;')==='5','Cantidad final inesperada');
check(sql('select count(*) from public.fotografias;')==='0','Fotografias falsas');
sql(`update public.informes set estado=0 where id_informe=${a.id_informe};`);
for(const actor of [users.ADMIN,users.POLICE_A]) {
  const rows=(await http(actor,'GET',`/rest/v1/informes?id_informe=eq.${a.id_informe}`,undefined,[200])).data;
  check(rows.length===0,'Informe inactivo visible');
  const children=(await http(actor,'GET',`/rest/v1/conductores?id_informe=eq.${a.id_informe}`,undefined,[200])).data;
  check(children.length===0,'Hijo inactivo visible');
}
// Catalogo real: solo helper actor puede ejecutarse por authenticated (lectura
// propia deliberada de 09); helpers de escritura/validacion quedan denegados.
check(sql(`select has_function_privilege('authenticated','app_private.finalizar_informe_impl(uuid,jsonb)','EXECUTE');`)==='f','Impl ejecutable directamente');
check(sql(`select has_function_privilege('anon','public.finalizar_informe(uuid,jsonb)','EXECUTE');`)==='f','anon EXECUTE residual');
check(sql(`select count(*) from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where p.oid='public.finalizar_informe(uuid,jsonb)'::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE';`)==='0','PUBLIC EXECUTE residual');
const metadata=JSON.parse(sql(`select json_build_object('owner',pg_get_userbyid(proowner),'security_definer',prosecdef,'config',proconfig) from pg_proc where oid='public.finalizar_informe(uuid,jsonb)'::regprocedure;`));
check(metadata.security_definer && metadata.config.includes('search_path=""'),'Definer sin search_path fijo');
const actorHelperExecute=sql("select has_function_privilege('authenticated','app_private.actor()','EXECUTE');")==='t';
check(actorHelperExecute,'Helper acotado actor requerido por RLS');
const report={fecha:new Date().toISOString(),cli:'2.122.0',http_checks:results.length,
  sql_snapshot_and_atomicity:'correctos',concurrencia_http:'dos solicitudes independientes simultaneas; no afirma bloqueo observado',
  private_actor_authenticated_execute:actorHelperExecute,private_actor_exposure:'no expuesto en Data API; EXECUTE SQL requerido por RLS, solo identidad propia',
  facade:metadata,results};
writeFileSync(new URL('./auth_http_results.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({http_checks:results.length,status:'OK',statuses:[...new Set(results.map(r=>r.status))],facade:metadata}));
