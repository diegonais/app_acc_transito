import {randomUUID,createHash} from 'node:crypto';
import {readFileSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
export async function run({base,status,users,check,http,sql,db,project,payload}) {
  const A=users.POLICE_A,rows=[];
  async function edge(actor,body,expected,headers={},label='control') {
    const started=performance.now();
    const res=await fetch(base+'/functions/v1/verificar-archivo',{method:'POST',headers:{apikey:status.ANON_KEY,'Content-Type':'application/json',...(actor?{Authorization:'Bearer '+actor.token}:{}),...headers},body:typeof body==='string'?body:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
    const data=await res.json();
    check(expected.includes(res.status),`Edge ${label}: HTTP ${res.status}`);
    check(!JSON.stringify(data).match(/eyJ|service_role|transito-evidencias|\/storage\/|stack|trace/i),'Respuesta divulga datos internos');
    rows.push({actor:actor?.name??'anon',status:res.status,estado:data.estado??data.message??null,ms:Math.round(performance.now()-started)});
    return data;
  }
  await edge(null,{reserva_id:randomUUID()},[401]);
  await edge({name:'JWT_INVALIDO',token:'no.es.valido'},{reserva_id:randomUUID()},[401,403]);
  await edge(A,{reserva_id:randomUUID(),url:'https://example.invalid/archivo'},[400]);
  await edge(A,{reserva_id:randomUUID(),bucket:'transito-pdf'},[400]);
  await edge(A,{reserva_id:'../../externo'},[400]);
  await edge(A,{reserva_id:[randomUUID()]},[400]);
  await edge(A,'{malformado',[400]);
  await edge(A,{reserva_id:randomUUID()},[400],{'Content-Type':'text/plain'});
  await edge(A,{reserva_id:randomUUID(),rol:'ADMIN',auth_uid:users.ADMIN.id},[400]);
  await edge(A,{reserva_id:randomUUID()},[403],{'x-forwarded-host':'example.invalid','x-supabase-url':'https://example.invalid'});
  // Cuenta A sigue activa; la suite 12 solo inactivo su informe.
  const invalidBytes=Buffer.from('imagen falsa');const rid=randomUUID(),op=randomUUID();
  const r=(await http(A,'POST','/rest/v1/rpc/reservar_archivo',{p_reserva:rid,p_operacion:op,p_clase:'FOTOGRAFIA',p_tipo:'OTRA',p_mime:'image/png',p_bytes:invalidBytes.length,p_sha256:createHash('sha256').update(invalidBytes).digest('hex'),p_informe:null},[200])).data;
  await edge(A,{reserva_id:r.reserva_id},[422]);
  check(sql(`select estado from public.reservas_archivos where reserva_id='${rid}';`)==='RESERVADO','Fallo de Storage confirmo reserva');
  const fixtures=JSON.parse(readFileSync(process.env.TRANSITO_EDGE_FIXTURES,'utf8'));
  const parity=[];let setupRequests=1;
  async function setup(path,body,expected=[200],privileged=false,raw=false){
    const key=privileged?status.SERVICE_ROLE_KEY:status.ANON_KEY;
    const response=await fetch(base+path,{method:'POST',headers:{apikey:key,Authorization:'Bearer '+(privileged?key:A.token),
      'Content-Type':raw?raw:'application/json',...(privileged&&raw?{'x-upsert':'true'}:{})},body:raw?body:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
    setupRequests++;check(expected.includes(response.status),'Preparacion sintetica fallo: '+response.status);
    return await response.json();
  }
  for(const fixture of fixtures){
    const bytes=Buffer.from(fixture.base64,'base64'),id=randomUUID(),op=randomUUID();
    const isPdf=fixture.mime==='application/pdf';
    const report=isPdf?await setup('/rest/v1/rpc/finalizar_informe',{operation_id:randomUUID(),payload}):null;
    const reservation=await setup('/rest/v1/rpc/reservar_archivo',{p_reserva:id,p_operacion:op,p_clase:isPdf?'PDF':'FOTOGRAFIA',p_tipo:isPdf?null:'OTRA',p_mime:fixture.mime,p_bytes:Math.max(1,bytes.length),p_sha256:createHash('sha256').update(bytes).digest('hex'),p_informe:report?.id_informe??null});
    await setup(`/storage/v1/object/${reservation.bucket_id}/${reservation.objeto}`,bytes,[200],false,fixture.mime);
    console.log(`Fixture Edge: ${fixture.name}, ${bytes.length} bytes`);
    const result=await edge(A,{reserva_id:fixture.name==='PNG_valido'?id.toUpperCase():id},fixture.expected?[200]:[422],{},fixture.name);
    const state=sql(`select estado from public.reservas_archivos where reserva_id='${id}';`);
    check(state===(fixture.expected?'VERIFICADO':'RESERVADO'),'Estado de fixture incorrecto');
    parity.push({name:fixture.name,bytes:bytes.length,python:fixture.python,edge:fixture.expected,coincide:fixture.python===fixture.expected,ms:rows.at(-1).ms});
  }
  // Fallos distribuidos reales solo en nuestro stack, nunca storage.objects directo.
  const valid=fixtures.find(f=>f.name==='PNG_valido'),bytes=Buffer.from(valid.base64,'base64');
  const pending=await setup('/rest/v1/rpc/reservar_archivo',{p_reserva:randomUUID(),p_operacion:randomUUID(),p_clase:'FOTOGRAFIA',p_tipo:'OTRA',p_mime:'image/png',p_bytes:bytes.length,p_sha256:valid.sha256,p_informe:null});
  await setup(`/storage/v1/object/${pending.bucket_id}/${pending.objeto}`,bytes,[200],false,'image/png');
  const storage=`supabase_storage_${project}`;
  const inspected=JSON.parse(execFileSync('docker',['inspect',storage],{encoding:'utf8'}))[0];
  check(inspected.Config.Labels['com.supabase.cli.project']===project,'Destino de fallo no dedicado');
  execFileSync('docker',['pause',storage]);
  try {await edge(A,{reserva_id:pending.reserva_id},[503]);}
  finally {execFileSync('docker',['unpause',storage]);}
  check(sql(`select estado from public.reservas_archivos where reserva_id='${pending.reserva_id}';`)==='RESERVADO','Timeout confirmo archivo');
  const altered=Buffer.from(bytes);altered[altered.length-1]^=1;
  await setup(`/storage/v1/object/${pending.bucket_id}/${pending.objeto}`,altered,[200],true,'image/png');
  await edge(A,{reserva_id:pending.reserva_id},[422]);
  check(sql(`select estado from public.reservas_archivos where reserva_id='${pending.reserva_id}';`)==='RESERVADO','Alteracion confirmada');
  const runtime=JSON.parse(execFileSync('docker',['inspect',`supabase_edge_runtime_${project}`],{encoding:'utf8'}))[0].Config.Image;
  writeFileSync(new URL('./edge_http_results.json',import.meta.url),JSON.stringify({checks:rows.length,setupRequests,passed:rows.length,failed:0,runtime,parity,rows},null,2)+'\n');
  console.log(JSON.stringify({edge_additional_http:rows.length,status:'OK'}));
}
