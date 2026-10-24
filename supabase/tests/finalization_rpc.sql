-- psql -X -v ON_ERROR_STOP=1 -f .../tests/finalization_rpc.sql en BD descartable.
begin;
\ir support/finalization_fixtures.sql
create temporary table resultados(nombre text);
grant select,insert on resultados to authenticated,anon;
create function pg_temp.check_it(ok boolean,n text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'FALLO: %',n; end if;
  insert into pg_temp.resultados values(n);
end $$;
create function pg_temp.error_rpc(p jsonb,c text) returns void language plpgsql as $$
declare recibido text;
begin
  begin perform public.finalizar_informe(gen_random_uuid(),p);
  exception when others then get stacked diagnostics recibido=returned_sqlstate; end;
  perform pg_temp.check_it(recibido=c,'RPC error esperado '||c||' recibido '||coalesce(recibido,'NINGUNO'));
end $$;
select pg_temp.check_it(not has_function_privilege('anon','public.finalizar_informe(uuid,jsonb)','EXECUTE'),'anon sin EXECUTE');
select pg_temp.check_it(has_function_privilege('authenticated','public.finalizar_informe(uuid,jsonb)','EXECUTE'),'authenticated EXECUTE');
select pg_temp.check_it(not has_function_privilege('authenticated','app_private.finalizar_informe_impl(uuid,jsonb)','EXECUTE'),'impl privada');
select pg_temp.check_it(not has_table_privilege('authenticated','app_private.operaciones_finalizacion','SELECT,INSERT,UPDATE,DELETE'),'operaciones sin CRUD');
select pg_temp.check_it((select prosecdef and proconfig=array['search_path=""'] from pg_proc
 where oid='public.finalizar_informe(uuid,jsonb)'::regprocedure),'fachada definer search_path fijo');
select pg_temp.check_it((select not prosecdef from pg_proc
 where oid='app_private.finalizar_informe_impl(uuid,jsonb)'::regprocedure),'impl invoker');

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
create temporary table respuesta as select public.finalizar_informe('20000000-0000-4000-8000-000000000001',test_support.payload()) r;
select pg_temp.check_it((select r->>'numero_caso'='2025-000001' from respuesta),'primer caso anio accidente');
select pg_temp.check_it((select r=public.finalizar_informe('20000000-0000-4000-8000-000000000001',test_support.payload()) from respuesta),'reintento respuesta perdida identico');
select pg_temp.check_it((select r=public.finalizar_informe('20000000-0000-4000-8000-000000000001',
  jsonb_set(test_support.payload(),'{personas,0,edad}','0.0')) from respuesta),'comparacion canonica JSONB de numeros');
do $$
declare code text;
begin
  begin perform public.finalizar_informe('20000000-0000-4000-8000-000000000001',test_support.payload()||'{"lugar":"Otro"}');
  exception when others then get stacked diagnostics code=returned_sqlstate; end;
  perform pg_temp.check_it(code='PT409','clave misma contenido diferente');
end $$;
select pg_temp.check_it((select count(*)=1 from public.informes),'un informe tras reintentos');
select pg_temp.check_it((select id_policia=1002 and policia_nombre_snapshot='Nombre Ficticio 2'
  and policia_grado_snapshot='Grado ficticio' and policia_placa_snapshot='RPC-FICTICIA-2'
  and policia_unidad_snapshot='Unidad ficticia' from public.informes),'snapshot servidor propio');
select pg_temp.check_it((select count(*)=1 from public.conductores),'conductor persistido');
select pg_temp.check_it((select count(*)=1 from public.vehiculos v join public.conductores c
  on c.id_conductor=v.id_conductor and c.id_informe=v.id_informe),'vehiculo vinculado propio');
select pg_temp.check_it((select count(*)=1 from public.personas_involucradas),'persona persistida');
select pg_temp.check_it((select count(*)=0 from public.archivos_informe),'sin archivos falsos');
do $$
declare k text;
begin
  foreach k in array array['id_policia','idPolicia','rol','gestion','auth_uid','now','correlativo',
    'policia_nombre_snapshot','snapshot','numero_caso'] loop
    perform pg_temp.error_rpc(test_support.payload()||jsonb_build_object(k,'MANIPULADO'),'22023');
  end loop;
  foreach k in array array['epi','fecha_hora_hecho','fecha_hora_llegada','naturaleza','lugar',
    'denunciante_nombre','denunciante_contacto','descripcion','condiciones_climaticas','testigos','efectos_personales'] loop
    perform pg_temp.error_rpc(test_support.payload()-k,'22023');
  end loop;
  foreach k in array array['2025-02-29T12:00:00.000','2026-02-30T12:00:00.000','2026-13-01T12:00:00.000',
    '2026-01-01T24:00:00.000','2026-01-01T23:60:00.000','2026-01-01T23:59:60.000',
    '2026-01-01','2026-01-01T12:00:00-04:00','1999-12-31T23:59:59.000'] loop
    perform pg_temp.error_rpc(test_support.payload()||jsonb_build_object('fecha_hora_hecho',k),'22023');
  end loop;
end $$;
select pg_temp.error_rpc(test_support.payload()||'{"latitud":91,"longitud":0}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"latitud":0}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"latitud":"NaN","longitud":0}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"vehiculos_movidos":1}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"conductores":null}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"naturaleza":"No existe"}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"fotografias":[{"bucket_id":"inventado","objeto":"ajeno.jpg"}]}','PT422');
select pg_temp.error_rpc(test_support.payload()||'{"ruta_croquis":"telefono.png"}','PT422');
select pg_temp.error_rpc(test_support.payload()||'{"ruta_pdf":"telefono.pdf"}','PT422');
-- Fallo de relacionado ocurre DESPUES de reservar operacion, incrementar contador
-- e insertar cabecera/conductor. Debe revertirse todo el substatement RPC.
select pg_temp.error_rpc(test_support.payload()||'{"vehiculos":[{"driver_index":9,"placa":"x","marca":"x","color":"x","tipo":"x","servicio":"x"}]}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"personas":[{"nombre":"x","edad":1.5,"tipo":"HERIDO"}]}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"conductores":[{"nombre_completo":"x","licencia":"x","categoria":"x","edad":-1}]}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"conductores":[{"nombre_completo":"x","licencia":"x","categoria":"x","edad":"abc"}]}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"personas":[{"nombre":"x","edad":"abc","tipo":"HERIDO"}]}','22023');
select pg_temp.error_rpc(test_support.payload()||'{"vehiculos":[{"driver_index":"abc","placa":"x","marca":"x","color":"x","tipo":"x","servicio":"x"}]}','22023');
select pg_temp.check_it((select count(*)=1 from public.informes),'sin cabecera parcial');
select pg_temp.check_it((select count(*)=1 from public.conductores),'sin hijo parcial');
select pg_temp.check_it((public.finalizar_informe('20000000-0000-4000-8000-000000000002',
  test_support.payload()||'{"fecha_hora_hecho":"2024-02-29T23:59:59.123456Z"}')->>'numero_caso')='2024-000001','bisiesto UTC explicito sin conversion');
select pg_temp.check_it((public.finalizar_informe('20000000-0000-4000-8000-000000000003',
  test_support.payload()||'{"lugar":"Segundo"}')->>'numero_caso')='2025-000002','rollback no consume numero');

-- Negativos y aislamiento del resultado de otro autor.
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
do $$
declare code text;
begin
  begin perform public.finalizar_informe('20000000-0000-4000-8000-000000000001',test_support.payload());
  exception when others then get stacked diagnostics code=returned_sqlstate; end;
  perform pg_temp.check_it(code='42501','ajeno no recupera resultado');
end $$;
select pg_temp.check_it((select count(*)=0 from public.informes),'ajeno no consulta por RLS');
do $$
declare n integer;
begin
  foreach n in array array[1,4,5,6] loop
    perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
    perform pg_temp.error_rpc(test_support.payload(),'42501');
  end loop;
  perform set_config('request.jwt.claim.sub','',true);
  perform pg_temp.error_rpc(test_support.payload(),'42501');
end $$;
reset role;
set local role anon;
select pg_temp.error_rpc(test_support.payload(),'42501');
reset role;
select pg_temp.check_it((select count(*)=3 and bool_and(resultado is not null) from app_private.operaciones_finalizacion),'solo operaciones confirmadas');
select pg_temp.check_it((select ultimo_correlativo=2 from app_private.contadores_gestion where gestion=2025),'contador confirmado 2');
update public.policias set nombres='Editado' where id_policia=1002;
select pg_temp.check_it((select bool_and(policia_nombre_snapshot='Nombre Ficticio 2') from public.informes),'perfil editado no altera snapshots');
update public.informes set estado=0 where id_informe=(select (r->>'id_informe')::bigint from respuesta);
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select pg_temp.check_it((select r=public.finalizar_informe('20000000-0000-4000-8000-000000000001',test_support.payload()) from respuesta),'reintento inactivo conserva resultado historico');
select pg_temp.check_it((public.finalizar_informe('20000000-0000-4000-8000-000000000004',test_support.payload())->>'correlativo')='3','numero inactivo no reutilizado');
reset role;
select count(*) as comprobaciones_rpc_correctas from pg_temp.resultados;
rollback;
