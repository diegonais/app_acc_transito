import {spawn,execFileSync} from 'node:child_process';
import {randomUUID,createHash} from 'node:crypto';
import {writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';

export async function run({wd,project,status,base,users,sql,http,check,payload,db}) {
  const python=process.env.TRANSITO_TEST_PYTHON;
  if(!python)throw Error('Defina TRANSITO_TEST_PYTHON: Python con Pillow 12.3.0 y pypdf 6.10.0');
  const fixtures=JSON.parse(execFileSync(python,['-c',`import io,json,base64
from PIL import Image
from pypdf import PdfWriter
r={}
for fmt in ['PNG','JPEG']:
 b=io.BytesIO(); Image.new('RGB',(16,16),(32,64,128)).save(b,format=fmt); r[fmt]=base64.b64encode(b.getvalue()).decode()
b=io.BytesIO(); w=PdfWriter(); w.add_blank_page(width=100,height=100); w.write(b); r['PDF']=base64.b64encode(b.getvalue()).decode()
print(json.dumps(r))`],{encoding:'utf8'}));
  const files=Object.fromEntries(Object.entries(fixtures).map(([k,v])=>[k,Buffer.from(v,'base64')]));
  const verifier=spawn(python,[fileURLToPath(new URL('../local/storage_verifier.py',import.meta.url))],{
    env:{...process.env,TRANSITO_LOCAL_URL:base,TRANSITO_ANON_KEY:status.ANON_KEY,TRANSITO_SERVICE_KEY:status.SERVICE_ROLE_KEY},
    windowsHide:true,stdio:'ignore'});
  const rows=[];
  const denied=[400,401,403,404,409,422];
  async function request(actor,method,path,body,expected=[200],extra={},verify=false){
    const headers={apikey:status.ANON_KEY,...extra};
    if(actor)headers.Authorization=`Bearer ${actor.token}`;
    if(body!==undefined&&!Buffer.isBuffer(body)){headers['Content-Type']='application/json';body=JSON.stringify(body);}
    const res=await fetch((verify?'http://127.0.0.1:57523':base)+path,{method,headers,body,signal:AbortSignal.timeout(30000)});
    const bytes=Buffer.from(await res.arrayBuffer()); let data;try{data=JSON.parse(bytes.toString());}catch{}
    rows.push({actor:actor?.name??'anon',method,endpoint:verify?'/verificar':path.split('/').slice(0,5).join('/'),status:res.status,ok:expected.includes(res.status)});
    check(expected.includes(res.status),`Storage ${actor?.name??'anon'} ${method} ${path.split('/').slice(0,5).join('/')}: ${res.status}, code ${data?.code??data?.estado??''}`);
    return {data,bytes,status:res.status};
  }
  const rpc=(actor,name,data,expected=[200])=>request(actor,'POST','/rest/v1/rpc/'+name,data,expected);
  const verify=(actor,r,expected=[200])=>request(actor,'POST','/verificar',{reserva_id:r.reserva_id},expected,{},true);
  const upload=(actor,r,bytes,expected=[200],extra={})=>request(actor,'POST',`/storage/v1/object/${r.bucket_id}/${r.objeto}`,bytes,expected,{'Content-Type':r.mime,...extra});
  const download=(actor,r,expected=[200])=>request(actor,'GET',`/storage/v1/object/authenticated/${r.bucket_id}/${r.objeto}`,undefined,expected);
  const sha=b=>createHash('sha256').update(b).digest('hex');
  const A=users.POLICE_A,B=users.POLICE_B,admin=users.ADMIN,inactive=users.INACTIVO;
  const op=randomUUID();
  async function reserve(actor,bytes,clase='FOTOGRAFIA',mime='image/png',operation=op,informe=null,expected=[200],overrides={}){
    const args={p_reserva:randomUUID(),p_operacion:operation,p_clase:clase,p_tipo:clase==='FOTOGRAFIA'?'OTRA':null,p_mime:mime,p_bytes:bytes.length,p_sha256:sha(bytes),p_informe:informe,...overrides};
    return {args,r:(await rpc(actor,'reservar_archivo',args,expected)).data};
  }
  try {
    for(let i=0;i<40;i++){
      try{await fetch('http://127.0.0.1:57523/ready',{signal:AbortSignal.timeout(500)});break;}catch{await new Promise(r=>setTimeout(r,100));}
    }
    const {args,r}=await reserve(A,files.PNG);
    const duplicate=(await rpc(A,'reservar_archivo',args)).data;
    check(duplicate.objeto===r.objeto,'Reserva duplicada cambia ruta');
    await rpc(A,'reservar_archivo',{...args,p_sha256:sha(files.JPEG)},[409]);
    await rpc(B,'reservar_archivo',args,[403]);
    for(const actor of [admin,inactive,null])await rpc(actor,'reservar_archivo',{...args,p_reserva:randomUUID()},denied);
    await request(A,'POST','/rest/v1/reservas_archivos',{},[403]);
    await request(A,'PATCH',`/rest/v1/reservas_archivos?reserva_id=eq.${r.reserva_id}`,{estado:'VERIFICADO'},[403]);
    await request(A,'DELETE',`/rest/v1/reservas_archivos?reserva_id=eq.${r.reserva_id}`,undefined,[403]);
    await rpc(A,'confirmar_archivo_backend',{p_reserva:r.reserva_id,p_uid:A.id,p_bytes:files.PNG.length,p_sha256:sha(files.PNG),p_mime:'image/png'},[403]);
    const initial=sql('select count(*) from public.informes;');
    const counter=sql('select ultimo_correlativo from app_private.contadores_gestion where gestion=2025;');
    await rpc(A,'finalizar_informe',{operation_id:op,payload:{...payload,archivos:[r.reserva_id]}},[422]);
    await verify(A,r,[422]); // objeto inexistente
    await upload(B,r,files.PNG,denied);
    await upload(inactive,r,files.PNG,denied);
    await upload(null,r,files.PNG,denied);
    await upload(A,{...r,objeto:r.objeto+'/ajeno'},files.PNG,denied);
    await upload(A,{...r,bucket_id:'no-existe'},files.PNG,denied);
    await upload(A,r,files.PNG);
    await request(A,'POST',`/storage/v1/object/sign/${r.bucket_id}/${r.objeto}`,{expiresIn:86400},denied);
    await request(A,'POST',`/storage/v1/object/upload/sign/${r.bucket_id}/${r.objeto}`,{},denied);
    await upload(A,r,files.PNG,denied);
    await upload(A,r,files.JPEG,denied,{'x-upsert':'true'});
    await request(A,'PUT',`/storage/v1/object/${r.bucket_id}/${r.objeto}`,files.JPEG,denied,{'Content-Type':'image/jpeg'});
    const deletion=await request(A,'DELETE',`/storage/v1/object/${r.bucket_id}`,{prefixes:[r.objeto]},[200,...denied]);
    if(deletion.status===200)check(Array.isArray(deletion.data)&&deletion.data.length===0,'DELETE elimino objeto protegido');
    check((await download(A,r)).bytes.equals(files.PNG),'DELETE/overwrite altero objeto');
    await request(null,'GET',`/storage/v1/object/public/${r.bucket_id}/${r.objeto}`,undefined,denied);
    await download(admin,r,denied); // temporal ni ADMIN
    await verify(B,r,denied);await verify(inactive,r,denied);await verify(null,r,[401]);
    await verify(A,r);await verify(A,r); // respuesta perdida
    const jpeg=(await reserve(A,files.JPEG,'FOTOGRAFIA','image/jpeg')).r;
    const sketch=(await reserve(A,files.PNG,'CROQUIS','image/png')).r;
    for(const [rr,bytes] of [[jpeg,files.JPEG],[sketch,files.PNG]]){await upload(A,rr,bytes);await verify(A,rr);}
    const foreign=(await reserve(B,files.PNG)).r;
    await upload(B,foreign,files.PNG);await verify(B,foreign);
    await rpc(A,'finalizar_informe',{operation_id:op,payload:{...payload,archivos:[foreign.reserva_id]}},[422]);
    await rpc(A,'finalizar_informe',{operation_id:randomUUID(),payload:{...payload,archivos:[r.reserva_id]}},[422]);
    await rpc(A,'finalizar_informe',{operation_id:op,payload:{...payload,archivos:[r.reserva_id,r.reserva_id]}},[400]);
    check(sql('select count(*) from public.informes;')===initial,'Fallo Storage creo cabecera');
    check(sql('select ultimo_correlativo from app_private.contadores_gestion where gestion=2025;')===counter,'Fallo Storage consumio numero');
    const finalPayload={...payload,archivos:[r.reserva_id,jpeg.reserva_id,sketch.reserva_id]};
    const responses=await Promise.all([1,2].map(()=>rpc(A,'finalizar_informe',{operation_id:op,payload:finalPayload})));
    const report=responses[0].data;
    check(JSON.stringify(report)===JSON.stringify(responses[1].data),'Cierre con evidencia no idempotente');
    await rpc(A,'finalizar_informe',{operation_id:op,payload:{...finalPayload,archivos:[]}},[409]);
    await rpc(A,'finalizar_informe',{operation_id:op,payload:finalPayload});
    await rpc(A,'reservar_archivo',args); // reintento de reserva tras cierre
    await reserve(A,files.PNG,'FOTOGRAFIA','image/png',op,null,[409]);
    check(sql(`select count(*) from public.archivos_informe where id_informe=${report.id_informe};`)==='3','Archivos no vinculados');
    check(sql(`select count(*) from public.fotografias where id_informe=${report.id_informe};`)==='2','Fotos no vinculadas');
    // Segunda sesion real: refresh crea otro access token de la cuenta A.
    const newPassword=`Aa1!${randomUUID()}`;
    const reset=await http(A,'PUT',`/auth/v1/admin/users/${A.id}`,{password:newPassword},[200],{admin:true});
    rows.push({actor:'SERVICIO_LOCAL_FIXTURE',method:'PUT',endpoint:'/auth/v1/admin/users',status:reset.status,ok:reset.status===200});
    const email=JSON.parse(execFileSync('docker',['exec',db,'psql','-X','-q','-At','-U','postgres','-d','postgres','-c',`select to_json(email) from auth.users where id='${A.id}';`],{encoding:'utf8'}));
    const second=(await request(null,'POST','/auth/v1/token?grant_type=password',{email,password:newPassword})).data;
    const A2={...A,name:'POLICE_A_SEGUNDA_SESION',token:second.access_token};
    await verify(A,r,[403]); // GoTrue revoco la sesion anterior al cambiar password.
    await download(A,r,denied); // Storage tambien exige sesion real vigente.
    A.token=second.access_token; // Las verificaciones posteriores usan una sesion vigente.
    for(const rr of [r,jpeg,sketch]){
      for(const actor of [A2,admin])check((await download(actor,rr)).bytes.equals(rr===jpeg?files.JPEG:files.PNG),'Descarga altero bytes');
      for(const actor of [B,inactive,null])await download(actor,rr,denied);
    }
    const snapshot=sql(`select to_jsonb(i) from public.informes i where id_informe=${report.id_informe};`);
    const pdf=(await reserve(A,files.PDF,'PDF','application/pdf',randomUUID(),report.id_informe)).r;
    for(const actor of [admin,B])await reserve(actor,files.PDF,'PDF','application/pdf',randomUUID(),report.id_informe,denied);
    await rpc(A,'registrar_pdf',{p_reserva:pdf.reserva_id},[422]);
    await upload(A,pdf,files.PDF);await verify(A,pdf);
    for(const actor of [admin,B,inactive,null])await rpc(actor,'registrar_pdf',{p_reserva:pdf.reserva_id},denied);
    const pdfId=(await rpc(A,'registrar_pdf',{p_reserva:pdf.reserva_id})).data;
    check((await rpc(A,'registrar_pdf',{p_reserva:pdf.reserva_id})).data===pdfId,'PDF duplicado');
    for(const actor of [A2,admin])check((await download(actor,pdf)).bytes.equals(files.PDF),'PDF bytes diferentes');
    for(const actor of [B,inactive,null])await download(actor,pdf,denied);
    check(sql(`select to_jsonb(i) from public.informes i where id_informe=${report.id_informe};`)===snapshot,'PDF modifico informe');
    // Bytes falsos con MIME/extension validos: nunca verificarlos.
    const falseBytes=Buffer.from('no es una imagen ni un PDF');
    for(const [clase,mime,data,actual] of [
      ['FOTOGRAFIA','image/png',falseBytes,falseBytes],
      ['FOTOGRAFIA','image/png',files.PNG,files.JPEG],
      ['FOTOGRAFIA','image/jpeg',files.PNG,files.PNG],
      ['PDF','application/pdf',falseBytes,falseBytes],
      ['FOTOGRAFIA','image/png',files.PNG.subarray(0,30),files.PNG.subarray(0,30)]
    ]){
      const rr=(await reserve(A,data,clase,mime,randomUUID(),clase==='PDF'?report.id_informe:null)).r;
      await upload(A,rr,actual);await verify(A,rr,[422]);
      check(sql(`select estado from public.reservas_archivos where reserva_id='${rr.reserva_id}';`)==='RESERVADO','Archivo falso aceptado');
    }
    await reserve(A,files.PNG,'FOTOGRAFIA','application/pdf',randomUUID(),null,denied);
    await reserve(A,files.JPEG,'CROQUIS','image/jpeg',randomUUID(),null,denied);
    await reserve(A,files.PNG,'FOTOGRAFIA','image/png',randomUUID(),null,denied,{p_bytes:5242881});
    const oversized=(await reserve(A,files.PNG,'FOTOGRAFIA','image/png',randomUUID())).r;
    await upload(A,oversized,Buffer.alloc(5242881),denied);
    await upload(A,oversized,files.PNG,denied,{'Content-Type':'text/plain'});
    const expired=(await reserve(A,files.PNG,'FOTOGRAFIA','image/png',randomUUID())).r;
    sql(`update public.reservas_archivos set expira_en=clock_timestamp()-interval '1 second' where reserva_id='${expired.reserva_id}';`);
    await upload(A,expired,files.PNG,denied);await verify(A,expired,denied);
    const quotaOp=randomUUID();
    for(let i=0;i<12;i++)await reserve(A,files.PNG,'FOTOGRAFIA','image/png',quotaOp);
    await reserve(A,files.PNG,'FOTOGRAFIA','image/png',quotaOp,null,[400]);
    await reserve(A,files.PNG,'CROQUIS','image/png',quotaOp);
    await reserve(A,files.PNG,'CROQUIS','image/png',quotaOp,null,[400]);
    await reserve(A,files.PDF,'PDF','application/pdf',randomUUID(),report.id_informe);
    await reserve(A,files.PDF,'PDF','application/pdf',randomUUID(),report.id_informe,[400]);
    sql(`update public.usuarios set estado=0 where auth_uid='${A.id}';`);
    await download(A2,pdf,denied);await download(admin,pdf);
    sql(`update public.usuarios set estado=1 where auth_uid='${A.id}'; update public.informes set estado=0 where id_informe=${report.id_informe};`);
    await download(A2,pdf,denied);await download(admin,pdf,denied);
    check(sql(`select count(*) from public.archivos_informe where id_informe=${report.id_informe};`)==='4','Inactivacion borro archivo');
    check(sql(`select has_function_privilege('authenticated','public.confirmar_archivo_backend(uuid,uuid,bigint,text,text)','EXECUTE');`)==='f','Verifier accesible a cliente');
    const summary={fecha:new Date().toISOString(),status:'OK',new_http_checks:rows.length,passed:rows.filter(r=>r.ok).length,failed:rows.filter(r=>!r.ok).length,rows};
    writeFileSync(new URL('./storage_http_results.json',import.meta.url),JSON.stringify(summary,null,2)+'\n');
    console.log(JSON.stringify({storage_http:rows.length,status:'OK',statuses:[...new Set(rows.map(r=>r.status))]}));
  }finally{verifier.kill();}
}
