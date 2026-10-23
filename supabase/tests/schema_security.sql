-- SQL equivalente a pruebas unitarias, sin extension pgTAP.
-- Ejecutar con psql -X -v ON_ERROR_STOP=1; cualquier fallo aborta y sale no cero.
-- Solo BD de prueba verificada vacia antes de migrar, nunca Cloud.
-- Todas las identidades/filas son sinteticas. Todo fixture se revierte.
-- En Supabase local NO ejecutar el bootstrap; usar auth.uid()/auth.users reales.
-- No prueba login, tokens, HTTP PostgREST, Storage, RPC ni concurrencia.
begin;
create temporary table resultados (nombre text not null);
grant select, insert on resultados to authenticated, anon;
create function pg_temp.comprobar(ok boolean, nombre text) returns void
language plpgsql security invoker as $$
begin
  if ok is distinct from true then raise exception 'FALLO: %', nombre; end if;
  insert into pg_temp.resultados values (nombre);
end $$;
create function pg_temp.rechaza(sentencia text, codigo text, nombre text) returns void
language plpgsql security invoker as $$
declare recibido text;
begin
  begin
    execute sentencia;
  exception when others then
    get stacked diagnostics recibido = returned_sqlstate;
  end;
  perform pg_temp.comprobar(recibido = codigo, nombre || ' SQLSTATE ' || coalesce(recibido, 'SIN ERROR'));
end $$;

-- Estructura, RLS, grants y secuencias, incluidas las heredadas por PUBLIC.
do $$
declare t text; r text; op text; s text;
begin
  foreach t in array array['usuarios','policias','informes','conductores','vehiculos',
    'personas_involucradas','fotografias','archivos_informe'] loop
    perform pg_temp.comprobar((select relrowsecurity from pg_class
      where oid = ('public.' || t)::regclass), t || ' RLS');
    perform pg_temp.comprobar(has_table_privilege('authenticated', 'public.' || t, 'SELECT'), t || ' SELECT authenticated');
    foreach r in array array['anon','authenticated'] loop
      foreach op in array array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
        perform pg_temp.comprobar(not has_table_privilege(r, 'public.' || t, op), t || ' sin ' || op || ' ' || r);
      end loop;
    end loop;
    perform pg_temp.comprobar(not has_table_privilege('anon', 'public.' || t, 'SELECT'), t || ' anon sin SELECT');
  end loop;
  for s in select pg_get_serial_sequence('public.' || v.t, v.id)
    from (values ('usuarios','id_usuario'),('policias','id_policia'),
      ('informes','id_informe'),('conductores','id_conductor'),('vehiculos','id_vehiculo'),
      ('personas_involucradas','id_persona'),('fotografias','id_fotografia'),
      ('archivos_informe','id_archivo')) v(t,id) loop
    foreach r in array array['anon','authenticated'] loop
      perform pg_temp.comprobar(not has_sequence_privilege(r,s,'USAGE,SELECT,UPDATE'), s || ' sin secuencia ' || r);
    end loop;
  end loop;
end $$;
select pg_temp.comprobar((select relrowsecurity from pg_class
  where oid = 'app_private.contadores_gestion'::regclass), 'contador RLS');
select pg_temp.comprobar(not has_table_privilege('authenticated',
  'app_private.contadores_gestion','SELECT,INSERT,UPDATE,DELETE'), 'contador privado');
select pg_temp.comprobar(not has_schema_privilege('anon','app_private','USAGE'), 'anon sin esquema privado');
select pg_temp.comprobar(not has_function_privilege('anon','app_private.actor()','EXECUTE'), 'anon sin helper');
select pg_temp.comprobar((select prosecdef and proconfig = array['search_path=""']
  from pg_proc where oid = 'app_private.actor()'::regprocedure), 'helper definer search_path fijo');
select pg_temp.comprobar((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'app_private' and p.prosecdef), 'un solo definer acotado');
select pg_temp.comprobar(not exists(select 1 from information_schema.columns
  where table_schema='public' and column_name in ('contrasena_hash','ruta','ruta_pdf','ruta_croquis')), 'sin hashes ni rutas locales');
do $$
declare esperado record; actual text[];
begin
  for esperado in select * from (values
    ('usuarios', 'id_usuario,auth_uid,nombre_usuario,rol,estado,fecha_creacion,fecha_modificacion'),
    ('policias', 'id_policia,id_usuario,numero_placa,grado,nombres,apellidos,unidad,sigla,ci,estado,fecha_creacion,fecha_modificacion'),
    ('informes', 'id_informe,id_policia,gestion,correlativo,numero_caso,epi,fecha_hora_llegada,fecha_hora_hecho,naturaleza,lugar,latitud,longitud,denunciante_nombre,denunciante_documento,denunciante_contacto,descripcion,condiciones_climaticas,vehiculos_movidos,protagonistas_presentes,testigos,efectos_personales,estado,fecha_creacion,fecha_modificacion,policia_nombre_snapshot,policia_grado_snapshot,policia_placa_snapshot,policia_unidad_snapshot'),
    ('conductores', 'id_conductor,id_informe,nombre_completo,edad,licencia,categoria,domicilio,zona,contactos,condicion_entrega,fecha_creacion'),
    ('vehiculos', 'id_vehiculo,id_informe,id_conductor,placa,marca,color,tipo,servicio,fecha_creacion'),
    ('personas_involucradas', 'id_persona,id_informe,nombre,edad,tipo,lugar_evacuacion,fecha_creacion'),
    ('fotografias', 'id_fotografia,id_informe,id_archivo,clase_archivo,tipo,descripcion,fecha_creacion'),
    ('archivos_informe', 'id_archivo,id_informe,clase,bucket_id,objeto,fecha_creacion')
  ) v(tabla,columnas) loop
    select array_agg(column_name::text order by ordinal_position) into actual
      from information_schema.columns where table_schema='public' and table_name=esperado.tabla;
    perform pg_temp.comprobar(actual = string_to_array(esperado.columnas,','), esperado.tabla || ' columnas exactas');
  end loop;
end $$;
select pg_temp.comprobar((select count(*)=10 from pg_constraint
  where contype='f' and connamespace='public'::regnamespace), 'diez FK de dominio y archivos');
select pg_temp.comprobar(not exists(select 1 from pg_constraint
  where contype='f' and connamespace='public'::regnamespace and
    (confdeltype<>'r' or (conrelid<>'public.usuarios'::regclass and confupdtype<>'c'))), 'FK RESTRICT y CASCADE conservados');
select pg_temp.comprobar(exists(select 1 from pg_constraint
  where conrelid='public.informes'::regclass and contype='u' and
    pg_get_constraintdef(oid)='UNIQUE (gestion, correlativo)'), 'UNIQUE gestion correlativo explicita');
select pg_temp.comprobar(exists(select 1 from pg_constraint
  where conrelid='public.informes'::regclass and contype='u' and
    pg_get_constraintdef(oid)='UNIQUE (numero_caso)'), 'UNIQUE numero caso explicita');
select pg_temp.comprobar(exists(select 1 from pg_constraint
  where conrelid='public.vehiculos'::regclass and contype='f' and array_length(conkey,1)=2), 'FK compuesta conductor informe');

insert into auth.users(id) select ('00000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
  from generate_series(1,7) n;
insert into public.usuarios(id_usuario,auth_uid,nombre_usuario,rol,estado,fecha_creacion,fecha_modificacion)
  overriding system value
  select n, ('00000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
    'sintetico_' || n, case when n in (1,6) then 'ADMIN' else 'POLICE' end,
    case when n = 6 then 0 else 1 end, '2026-10-22T12:00:00', '2026-10-22T12:00:00'
  from generate_series(1,6) n;
insert into public.policias(id_policia,id_usuario,numero_placa,grado,nombres,apellidos,unidad,sigla,ci,
  estado,fecha_creacion,fecha_modificacion) overriding system value
  select n,n,'FICTICIA-' || n,'GRADO SINTETICO','Nombre','Sintetico ' || n,'Unidad ficticia','TEST','CI FICTICIO',
    case when n=5 then 0 else 1 end,'2026-10-22T12:00:00','2026-10-22T12:00:00'
  from (values (2),(3),(5)) v(n);
insert into public.informes(id_informe,id_policia,gestion,correlativo,numero_caso,epi,fecha_hora_hecho,
  estado,fecha_creacion,fecha_modificacion,policia_nombre_snapshot,policia_grado_snapshot,
  policia_placa_snapshot,policia_unidad_snapshot) overriding system value
  select n,case when n=2 then 3 else 2 end,2025,n,'2025-' || lpad(n::text,6,'0'),
    'EPI ficticia','2025-12-31T23:59:59-04:00',case when n=3 then 0 else 1 end,
    '2026-01-01T04:00:00Z','2026-01-01T04:00:00Z','Nombre historico',
    'Grado historico','Placa historica','Unidad historica'
  from generate_series(1,3) n;
insert into public.conductores(id_conductor,id_informe,nombre_completo,edad,licencia,categoria,fecha_creacion)
  overriding system value select n,n,'Conductor ficticio',0,'Licencia ficticia','Texto libre','2026-10-22'
  from generate_series(1,3) n;
insert into public.vehiculos(id_vehiculo,id_informe,id_conductor,fecha_creacion)
  overriding system value select n,n,n,'2026-10-22' from generate_series(1,3) n;
insert into public.personas_involucradas(id_persona,id_informe,nombre,edad,tipo,fecha_creacion)
  overriding system value select n,n,'Persona ficticia',0,'HERIDO','2026-10-22' from generate_series(1,3) n;
insert into public.archivos_informe(id_archivo,id_informe,clase,bucket_id,objeto,fecha_creacion)
  overriding system value select n,n,'FOTOGRAFIA','bucket-futuro','ficticio/' || n || '.jpg','2026-10-22'
  from generate_series(1,3) n;
select setval(pg_get_serial_sequence('public.archivos_informe','id_archivo'),3);
insert into public.archivos_informe(id_informe,clase,bucket_id,objeto,fecha_creacion)
  select 1,c,'bucket-futuro','ficticio/' || c,'2026-10-22' from (values ('PDF'),('CROQUIS')) v(c);
-- Las identidades explicitas de fixtures no se usan en operacion real.
insert into public.fotografias(id_fotografia,id_informe,id_archivo,tipo,fecha_creacion)
  overriding system value select n,n,n,'OTRA','2026-10-22' from generate_series(1,3) n;
select setval(pg_get_serial_sequence('public.usuarios','id_usuario'),6);
select setval(pg_get_serial_sequence('public.vehiculos','id_vehiculo'),3);
select setval(pg_get_serial_sequence('public.conductores','id_conductor'),3);
select setval(pg_get_serial_sequence('public.personas_involucradas','id_persona'),3);
select setval(pg_get_serial_sequence('public.fotografias','id_fotografia'),3);

select pg_temp.rechaza($q$insert into public.usuarios(auth_uid,nombre_usuario,rol,fecha_creacion,fecha_modificacion)
  values ('00000000-0000-4000-8000-000000000007','sintetico_2','ADMIN','x','x')$q$,'23505','usuario unico');
select pg_temp.rechaza($q$insert into public.usuarios(auth_uid,nombre_usuario,rol,fecha_creacion,fecha_modificacion)
  values ('00000000-0000-4000-8000-000000000002','otro','ADMIN','x','x')$q$,'23505','auth_uid unico');
select pg_temp.rechaza($q$insert into public.usuarios(auth_uid,nombre_usuario,rol,fecha_creacion,fecha_modificacion)
  values ('99999999-0000-4000-8000-000000000001','sin-auth','POLICE','x','x')$q$,'23503','FK auth');
select pg_temp.rechaza($q$update public.policias set numero_placa='FICTICIA-2' where id_policia=3$q$,'23505','placa unica');
select pg_temp.rechaza($q$insert into public.vehiculos(id_informe,id_conductor,fecha_creacion) values (2,1,'x')$q$,'23503','conductor ajeno rechazado');
insert into public.vehiculos(id_informe,id_conductor,fecha_creacion) values (1,null,'x');
select pg_temp.comprobar(exists(select 1 from public.vehiculos where id_conductor is null), 'conductor opcional');
select pg_temp.rechaza($q$insert into public.conductores(id_informe,nombre_completo,edad,fecha_creacion) values (1,'x',-1,'x')$q$,'23514','edad negativa');
select pg_temp.rechaza($q$insert into public.personas_involucradas(id_informe,nombre,tipo,fecha_creacion) values (1,'x','OTRO','x')$q$,'23514','tipo persona');
select pg_temp.rechaza($q$insert into public.archivos_informe(id_informe,clase,bucket_id,objeto,fecha_creacion) values (1,'PDF','futuro','C:\telefono\archivo.pdf','x')$q$,'23514','ruta telefono rechazada');
select pg_temp.rechaza($q$insert into public.fotografias(id_informe,id_archivo,tipo,fecha_creacion) values (2,4,'OTRA','x')$q$,'23503','archivo mismo informe y clase');
select pg_temp.rechaza($q$update public.informes set policia_nombre_snapshot='alterado' where id_informe=1$q$,'23514','snapshot inmutable incluso SQL privilegiado');
select pg_temp.rechaza($q$update public.informes set id_policia=3 where id_informe=1$q$,'23514','autor inmutable');
select pg_temp.rechaza($q$delete from public.informes where id_informe=1$q$,'23514','sin borrado fisico');
select pg_temp.rechaza($q$update public.conductores set nombre_completo='otro' where id_conductor=1$q$,'23514','hijo inmutable');
select pg_temp.rechaza($q$update public.archivos_informe set objeto='otro.jpg' where id_archivo=1$q$,'23514','referencia evidencia inmutable');
select pg_temp.rechaza($q$insert into public.policias(id_usuario,numero_placa,grado,nombres,apellidos,unidad,sigla,ci,fecha_creacion,fecha_modificacion)
  values (2,'OTRA','x','x','x','x','x','x','x','x')$q$,'23505','un perfil por usuario');
update public.policias set nombres='Perfil editado' where id_policia=2;
select pg_temp.comprobar((select policia_nombre_snapshot='Nombre historico' from public.informes where id_informe=1), 'snapshot sobrevive cambio perfil');
select pg_temp.comprobar((select gestion=2025 and fecha_creacion like '2026%' from public.informes where id_informe=1), 'gestion del hecho no del registro ni UTC');
insert into app_private.contadores_gestion values (2025,3);
select pg_temp.rechaza('update app_private.contadores_gestion set ultimo_correlativo=2','23514','contador no retrocede');
select pg_temp.rechaza('delete from app_private.contadores_gestion','23514','contador no se borra');

-- Copiar un informe permite probar constraints de INSERT sin disparar UPDATE.
select pg_temp.rechaza($q$insert into public.informes select (jsonb_populate_record(null::public.informes,
  (select to_jsonb(i) from public.informes i where id_informe=1) || '{"id_informe":99}'::jsonb)).* $q$,
  '428C9','identity protegida');
select pg_temp.rechaza($q$insert into public.informes overriding system value
  select (jsonb_populate_record(null::public.informes,
  (select to_jsonb(i) from public.informes i where id_informe=1) || '{"id_informe":99}'::jsonb)).* $q$,
  '23505','caso/gestion correlativo unicos');
select pg_temp.rechaza($q$insert into public.informes overriding system value
  select (jsonb_populate_record(null::public.informes,
  (select to_jsonb(i) from public.informes i where id_informe=1) ||
  '{"id_informe":99,"gestion":2026,"correlativo":99,"numero_caso":"2026-000099"}'::jsonb)).* $q$,
  '23514','gestion divergente del hecho');
select pg_temp.rechaza($q$insert into public.informes overriding system value
  select (jsonb_populate_record(null::public.informes,
  (select to_jsonb(i) from public.informes i where id_informe=1) ||
  '{"id_informe":99,"correlativo":99,"numero_caso":"2025-000099","policia_nombre_snapshot":null}'::jsonb)).* $q$,
  '23502','snapshot obligatorio');
select pg_temp.rechaza($q$insert into public.informes overriding system value
  select (jsonb_populate_record(null::public.informes,
  (select to_jsonb(i) from public.informes i where id_informe=1) ||
  '{"id_informe":99,"correlativo":99,"numero_caso":"2025-000099","estado":2}'::jsonb)).* $q$,
  '23514','estado solo 0 o 1');
select pg_temp.rechaza($q$insert into public.informes overriding system value
  select (jsonb_populate_record(null::public.informes,
  (select to_jsonb(i) from public.informes i where id_informe=1) ||
  '{"id_informe":99,"correlativo":99,"numero_caso":"2025-000099","vehiculos_movidos":2}'::jsonb)).* $q$,
  '23514','bandera solo 0 o 1');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select pg_temp.comprobar((select count(*)=2 from public.informes), 'ADMIN activo global solo activos');
select pg_temp.comprobar((select count(*)=6 from public.usuarios), 'ADMIN conjunto usuarios');
select pg_temp.comprobar((select count(*)=3 from public.policias), 'ADMIN conjunto policias incluso inactivos');
select pg_temp.comprobar((select count(*)=1 and min(rol)='ADMIN' and min(id_policia) is null from app_private.actor()), 'ADMIN sin perfil valido');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
select pg_temp.comprobar((select count(*)=1 and min(id_informe)=1 from public.informes), 'POLICE propio activo');
select pg_temp.comprobar((select count(*)=1 and min(id_usuario)=2 from public.usuarios), 'POLICE solo cuenta propia');
select pg_temp.comprobar((select count(*)=1 and min(id_policia)=2 from public.policias), 'POLICE solo perfil propio');
-- Metadata falsificada no altera el rol servidor.
select set_config('request.jwt.claims','{"user_metadata":{"rol":"ADMIN"}}',true);
select pg_temp.comprobar((select count(*)=1 from public.informes), 'metadata no eleva permisos');
do $$
declare t text; n bigint;
begin
  foreach t in array array['conductores','vehiculos','personas_involucradas','fotografias','archivos_informe'] loop
    execute format('select count(*) from public.%I where id_informe=1',t) into n;
    perform pg_temp.comprobar(n>0,t || ' hijo propio visible');
    execute format('select count(*) from public.%I where id_informe in (2,3)',t) into n;
    perform pg_temp.comprobar(n=0,t || ' ID directo ajeno/inactivo oculto');
  end loop;
  foreach t in array array['usuarios','policias','informes','conductores','vehiculos',
    'personas_involucradas','fotografias','archivos_informe'] loop
    perform pg_temp.rechaza(format('insert into public.%I default values',t),'42501',t || ' INSERT cliente');
    perform pg_temp.rechaza(format('delete from public.%I',t),'42501',t || ' DELETE cliente');
  end loop;
end $$;
select pg_temp.rechaza('update public.usuarios set rol=''ADMIN'' where id_usuario=2','42501','cliente no cambia rol');
select pg_temp.rechaza('update public.usuarios set auth_uid=null where id_usuario=2','42501','cliente no cambia auth_uid');
select pg_temp.rechaza('update public.informes set id_policia=3 where id_informe=1','42501','cliente no cambia autor');
select pg_temp.rechaza('update public.informes set policia_nombre_snapshot=''x'' where id_informe=1','42501','cliente no cambia snapshot');
select pg_temp.rechaza('update public.informes set descripcion=''x'' where id_informe=1','42501','cliente no cambia contenido');
select pg_temp.rechaza('select * from app_private.contadores_gestion','42501','cliente no ve contador');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
select pg_temp.comprobar((select count(*)=1 and min(id_informe)=2 from public.informes), 'POLICE ajeno solo su informe');
do $$
declare t text; n bigint;
begin
  foreach t in array array['conductores','vehiculos','personas_involucradas','fotografias','archivos_informe'] loop
    execute format('select count(*) from public.%I where id_informe=1',t) into n;
    perform pg_temp.comprobar(n=0,t || ' ajeno no accede por ID');
  end loop;
end $$;

-- POLICE sin perfil, perfil inactivo, ADMIN inactivo, Auth no aprovisionado,
-- identidad nula: no leen ninguna fila de negocio ni obtienen actor.
do $$
declare n integer; t text; total bigint;
begin
  foreach n in array array[4,5,6,7,0] loop
    perform set_config('request.jwt.claim.sub',case when n=0 then '' else
      '00000000-0000-4000-8000-' || lpad(n::text,12,'0') end,true);
    perform pg_temp.comprobar((select count(*)=0 from app_private.actor()), 'sin actor efectivo ' || n);
    foreach t in array array['usuarios','policias','informes','conductores','vehiculos',
      'personas_involucradas','fotografias','archivos_informe'] loop
      execute format('select count(*) from public.%I',t) into total;
      perform pg_temp.comprobar(total=0,t || ' sin acceso identidad ' || n);
    end loop;
  end loop;
end $$;

reset role;
set local role anon;
do $$
declare t text;
begin
  foreach t in array array['usuarios','policias','informes','conductores','vehiculos',
    'personas_involucradas','fotografias','archivos_informe'] loop
    perform pg_temp.rechaza(format('select * from public.%I',t),'42501',t || ' anon SELECT');
    perform pg_temp.rechaza(format('insert into public.%I default values',t),'42501',t || ' anon INSERT');
    perform pg_temp.rechaza(format('delete from public.%I',t),'42501',t || ' anon DELETE');
  end loop;
end $$;
select pg_temp.rechaza('select * from app_private.actor()','42501','anon helper denegado');
reset role;

-- Inactivar conserva filas/relaciones/numero y oculta hijos tambien al ADMIN.
update public.informes set estado=0,fecha_modificacion='2026-10-22' where id_informe=1;
select pg_temp.comprobar((select count(*)=3 from public.informes), 'inactivacion conserva informe');
select pg_temp.comprobar((select count(*)=3 from public.fotografias), 'inactivacion conserva archivos');
select pg_temp.rechaza('update public.informes set estado=1 where id_informe=1','23514','sin reactivacion');
select pg_temp.rechaza($q$insert into public.informes overriding system value
  select (jsonb_populate_record(null::public.informes,
  (select to_jsonb(i) from public.informes i where id_informe=1) || '{"id_informe":99}'::jsonb)).* $q$,
  '23505','numero inactivo no reutilizable');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select pg_temp.comprobar((select count(*)=1 from public.informes), 'ADMIN no ve inactivados');
select pg_temp.rechaza('update public.informes set estado=0 where id_informe=2','42501','ADMIN sin escritura directa');
do $$
declare t text; n bigint;
begin
  foreach t in array array['conductores','vehiculos','personas_involucradas','fotografias','archivos_informe'] loop
    execute format('select count(*) from public.%I where id_informe=1',t) into n;
    perform pg_temp.comprobar(n=0,t || ' ADMIN no ve hijos inactivos');
  end loop;
end $$;
reset role;
select count(*) as comprobaciones_correctas from pg_temp.resultados;
rollback;
