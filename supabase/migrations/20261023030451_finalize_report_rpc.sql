-- Intervencion 10, solo PostgreSQL local. No modifica la migracion 09.
-- Contrato v1: finalizar_informe(operation_id uuid, payload jsonb) -> jsonb
-- con id_informe, gestion, correlativo, numero_caso. JSON usa nombres SQL;
-- vehiculos.driver_index es el indice cero de DriverInput.driverIndex.
-- JSONB canoniza orden de claves/numeros, conserva orden de arrays y texto.
-- Omitido y null son contenidos distintos para idempotencia; conservar payload
-- y operation_id en reintentos. Una clave es global, vinculada a auth.uid().
-- Errores: 22023 validacion, 42501 identidad/permisos, PT409 conflicto,
-- PT422 adjuntos sin verificacion. 40001/40P01: reintentar misma clave/payload.
-- Fechas: ISO de Dart, YYYY-MM-DDTHH:mm:ss con .fff o .ffffff opcional,
-- Z opcional. Sin offset numerico: Dart local no lo emite. Se preserva texto
-- y anio civil expresado; NO se asigna zona ni se convierte el hecho a UTC.
-- Auditoria tecnica: instante UTC del servidor. Sin soporte Storage en esta fase.
begin;
create table app_private.operaciones_finalizacion (
  operation_id uuid primary key,
  auth_uid uuid not null references auth.users(id) on delete restrict,
  payload jsonb not null,
  resultado jsonb,
  creado_en timestamptz not null default clock_timestamp()
);
alter table app_private.operaciones_finalizacion enable row level security;
revoke all on app_private.operaciones_finalizacion from public, anon, authenticated;
-- No filas persistentes 'en curso': reserva y resultado se confirman juntos o
-- se revierten. No expirar/borrar claves confirmadas: romperian idempotencia.

create function app_private.validar_objeto(p jsonb, permitidas text[], obligatorias text[])
returns void language plpgsql set search_path = '' as $$
declare k text;
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'Se requiere objeto JSON' using errcode='22023';
  end if;
  for k in select jsonb_object_keys(p) loop
    if not (k=any(permitidas)) then
      raise exception 'Campo no permitido: %',k using errcode='22023';
    end if;
  end loop;
  foreach k in array obligatorias loop
    if jsonb_typeof(p->k) is distinct from 'string' or btrim(p->>k)='' then
      raise exception 'Texto obligatorio: %',k using errcode='22023';
    end if;
  end loop;
end $$;

create function app_private.validar_fecha_iso(v text) returns integer
language plpgsql immutable set search_path = '' as $$
declare y integer;
begin
  if v is null or v !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{3}([0-9]{3})?)?Z?$' then
    raise exception 'Fecha ISO incompatible con Dart' using errcode='22023';
  end if;
  y := substring(v,1,4)::integer;
  perform make_date(y,substring(v,6,2)::integer,substring(v,9,2)::integer);
  if substring(v,12,2)::integer > 23 or substring(v,15,2)::integer > 59 or
     substring(v,18,2)::integer > 59 then
    raise exception 'Hora fuera de rango' using errcode='22023';
  end if;
  return y;
exception when datetime_field_overflow then
  raise exception 'Fecha de calendario inexistente' using errcode='22023';
end $$;

-- Logica privada SECURITY INVOKER, inaccesible a clientes incluso por SQL.
-- Solo la fachada DEFINER puede invocarla con privilegios de escritura.
create function app_private.finalizar_informe_impl(op uuid, p jsonb) returns jsonb
language plpgsql set search_path = '' as $$
declare
  uid uuid := auth.uid(); u public.usuarios%rowtype; pol public.policias%rowtype;
  anterior app_private.operaciones_finalizacion%rowtype;
  k text; e jsonb; x numeric; y integer; n integer; informe bigint;
  conductor bigint; ids bigint[] := array[]::bigint[]; respuesta jsonb;
  fecha text := to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
begin
  if uid is null then raise exception 'POLICE activo requerido' using errcode='42501'; end if;
  -- Orden de bloqueo estable usuario -> perfil -> operacion -> contador.
  -- FOR SHARE bloquea ediciones/desactivaciones, pero permite finalizaciones
  -- concurrentes del mismo autor. No se consulta rol de metadata JWT.
  select * into u from public.usuarios where auth_uid=uid for share;
  if not found or u.estado<>1 or u.rol<>'POLICE' then
    raise exception 'POLICE activo requerido' using errcode='42501';
  end if;
  select * into pol from public.policias where id_usuario=u.id_usuario for share;
  if not found or pol.estado<>1 then
    raise exception 'Perfil POLICE activo requerido' using errcode='42501';
  end if;
  if op is null then raise exception 'operation_id requerido' using errcode='22023'; end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'payload objeto requerido' using errcode='22023';
  end if;
  insert into app_private.operaciones_finalizacion(operation_id,auth_uid,payload)
    values(op,uid,p) on conflict (operation_id) do nothing;
  select * into anterior from app_private.operaciones_finalizacion where operation_id=op for update;
  if anterior.auth_uid<>uid then
    raise exception 'Operacion no autorizada' using errcode='42501';
  end if;
  if anterior.payload is distinct from p then
    raise exception 'operation_id ya utilizado con otro contenido' using errcode='PT409';
  end if;
  if anterior.resultado is not null then return anterior.resultado; end if;

  perform app_private.validar_objeto(p,array['epi','fecha_hora_llegada','fecha_hora_hecho',
    'naturaleza','lugar','latitud','longitud','denunciante_nombre','denunciante_documento',
    'denunciante_contacto','descripcion','condiciones_climaticas','vehiculos_movidos',
    'protagonistas_presentes','testigos','efectos_personales','conductores','vehiculos',
    'personas','fotografias','ruta_croquis','ruta_pdf'],
    array['epi','fecha_hora_llegada','fecha_hora_hecho','naturaleza','lugar',
    'denunciante_nombre','denunciante_contacto','descripcion','condiciones_climaticas',
    'testigos','efectos_personales']);
  -- Whitelist rechaza rol, autor, gestion, numero, now, auth_uid y snapshots,
  -- en snake_case o camelCase. Nunca se obtienen del cliente.
  foreach k in array array['ruta_croquis','ruta_pdf'] loop
    if coalesce(p->k,'null'::jsonb)<>'null'::jsonb then
      raise exception 'Adjuntos sin reserva verificada no admitidos' using errcode='PT422';
    end if;
  end loop;
  foreach k in array array['conductores','vehiculos','personas','fotografias'] loop
    if p ? k and jsonb_typeof(p->k) is distinct from 'array' then
      raise exception 'Se requiere array: %',k using errcode='22023';
    end if;
  end loop;
  if jsonb_array_length(coalesce(p->'fotografias','[]'::jsonb))>0 then
    raise exception 'Fotografias sin reserva verificada no admitidas' using errcode='PT422';
  end if;
  if p->>'naturaleza' <> all(array['Colisión','Choque','Choque a objeto fijo/vehículo detenido',
    'Atropello','Vuelco','Caída de persona o carga','Embarrancamiento / Deslizamiento',
    'Incendio de vehículo','Otros']) then
    raise exception 'Naturaleza no valida' using errcode='22023';
  end if;
  foreach k in array array['vehiculos_movidos','protagonistas_presentes'] loop
    if jsonb_typeof(p->k) is distinct from 'boolean' then
      raise exception 'Booleano requerido: %',k using errcode='22023';
    end if;
  end loop;
  if p ? 'denunciante_documento' and jsonb_typeof(p->'denunciante_documento') not in ('string','null') then
    raise exception 'Documento debe ser texto o null' using errcode='22023';
  end if;
  y := app_private.validar_fecha_iso(p->>'fecha_hora_hecho');
  perform app_private.validar_fecha_iso(p->>'fecha_hora_llegada');
  if y<2000 then raise exception 'Gestion no valida' using errcode='22023'; end if;
  if (coalesce(p->'latitud','null'::jsonb)='null'::jsonb) <>
     (coalesce(p->'longitud','null'::jsonb)='null'::jsonb) then
    raise exception 'Coordenadas deben ser un par' using errcode='22023';
  end if;
  foreach k in array array['latitud','longitud'] loop
    if coalesce(p->k,'null'::jsonb)<>'null'::jsonb then
      if jsonb_typeof(p->k)<>'number' then raise exception 'Coordenada numerica requerida' using errcode='22023'; end if;
      x := (p->>k)::numeric;
      if abs(x)>(case when k='latitud' then 90 else 180 end) then
        raise exception 'Coordenada fuera de rango' using errcode='22023';
      end if;
    end if;
  end loop;

  insert into app_private.contadores_gestion as c(gestion,ultimo_correlativo) values(y,1)
    on conflict (gestion) do update set ultimo_correlativo=c.ultimo_correlativo+1
    returning ultimo_correlativo into n;
  -- Contador transaccional: un rollback restaura el valor. IDs identity pueden
  -- tener huecos; no son el correlativo de negocio. Sin MAX+1.
  insert into public.informes(id_policia,gestion,correlativo,numero_caso,epi,
    fecha_hora_llegada,fecha_hora_hecho,naturaleza,lugar,latitud,longitud,
    denunciante_nombre,denunciante_documento,denunciante_contacto,descripcion,
    condiciones_climaticas,vehiculos_movidos,protagonistas_presentes,testigos,
    efectos_personales,fecha_creacion,fecha_modificacion,policia_nombre_snapshot,
    policia_grado_snapshot,policia_placa_snapshot,policia_unidad_snapshot)
  values(pol.id_policia,y,n,y::text||'-'||case when n<1000000 then lpad(n::text,6,'0') else n::text end,
    btrim(p->>'epi'),p->>'fecha_hora_llegada',p->>'fecha_hora_hecho',p->>'naturaleza',
    btrim(p->>'lugar'),(p->>'latitud')::double precision,(p->>'longitud')::double precision,
    btrim(p->>'denunciante_nombre'),nullif(btrim(p->>'denunciante_documento'),''),
    btrim(p->>'denunciante_contacto'),btrim(p->>'descripcion'),btrim(p->>'condiciones_climaticas'),
    (p->>'vehiculos_movidos')::boolean::integer,(p->>'protagonistas_presentes')::boolean::integer,
    btrim(p->>'testigos'),btrim(p->>'efectos_personales'),fecha,fecha,
    btrim(pol.nombres||' '||pol.apellidos),pol.grado,pol.numero_placa,pol.unidad)
  returning id_informe into informe;

  for e in select value from jsonb_array_elements(coalesce(p->'conductores','[]'::jsonb)) loop
    perform app_private.validar_objeto(e,array['nombre_completo','edad','licencia','categoria',
      'domicilio','zona','contactos','condicion_entrega'],array['nombre_completo','licencia','categoria']);
    foreach k in array array['domicilio','zona','contactos','condicion_entrega'] loop
      if e ? k and jsonb_typeof(e->k) not in ('string','null') then
        raise exception 'Texto opcional no valido: %',k using errcode='22023';
      end if;
    end loop;
    if coalesce(e->'edad','null'::jsonb)<>'null'::jsonb then
      if jsonb_typeof(e->'edad')<>'number' or (e->>'edad')::numeric<0 or
        (e->>'edad')::numeric<>trunc((e->>'edad')::numeric) or (e->>'edad')::numeric>2147483647 then
        raise exception 'Edad entera no negativa requerida' using errcode='22023';
      end if;
    end if;
    insert into public.conductores(id_informe,nombre_completo,edad,licencia,categoria,domicilio,zona,contactos,condicion_entrega,fecha_creacion)
      values(informe,e->>'nombre_completo',(e->>'edad')::numeric::integer,e->>'licencia',e->>'categoria',
        e->>'domicilio',e->>'zona',e->>'contactos',e->>'condicion_entrega',fecha)
      returning id_conductor into conductor;
    ids := array_append(ids,conductor);
  end loop;
  for e in select value from jsonb_array_elements(coalesce(p->'vehiculos','[]'::jsonb)) loop
    perform app_private.validar_objeto(e,array['driver_index','placa','marca','color','tipo','servicio'],
      array['placa','marca','color','tipo','servicio']);
    conductor := null;
    if coalesce(e->'driver_index','null'::jsonb)<>'null'::jsonb then
      if jsonb_typeof(e->'driver_index')<>'number' or (e->>'driver_index')::numeric<0 or
        (e->>'driver_index')::numeric<>trunc((e->>'driver_index')::numeric) or
        (e->>'driver_index')::numeric>=cardinality(ids) then
        raise exception 'driver_index no pertenece al informe' using errcode='22023';
      end if;
      conductor := ids[(e->>'driver_index')::numeric::integer+1];
    end if;
    insert into public.vehiculos(id_informe,id_conductor,placa,marca,color,tipo,servicio,fecha_creacion)
      values(informe,conductor,e->>'placa',e->>'marca',e->>'color',e->>'tipo',e->>'servicio',fecha);
  end loop;
  for e in select value from jsonb_array_elements(coalesce(p->'personas','[]'::jsonb)) loop
    perform app_private.validar_objeto(e,array['nombre','edad','tipo','lugar_evacuacion'],array['nombre','tipo']);
    if e->>'tipo' not in ('HERIDO','FALLECIDO') or jsonb_typeof(e->'edad') is distinct from 'number' or
      (e->>'edad')::numeric<0 or (e->>'edad')::numeric<>trunc((e->>'edad')::numeric) or
      (e->>'edad')::numeric>2147483647 then
      raise exception 'Tipo o edad de persona no valido' using errcode='22023';
    end if;
    if e ? 'lugar_evacuacion' and jsonb_typeof(e->'lugar_evacuacion') not in ('string','null') then
      raise exception 'Lugar evacuacion debe ser texto' using errcode='22023';
    end if;
    insert into public.personas_involucradas(id_informe,nombre,edad,tipo,lugar_evacuacion,fecha_creacion)
      values(informe,e->>'nombre',(e->>'edad')::numeric::integer,e->>'tipo',e->>'lugar_evacuacion',fecha);
  end loop;
  respuesta := jsonb_build_object('id_informe',informe,'gestion',y,'correlativo',n,
    'numero_caso',y::text||'-'||case when n<1000000 then lpad(n::text,6,'0') else n::text end);
  update app_private.operaciones_finalizacion set resultado=respuesta where operation_id=op;
  return respuesta;
end $$;

revoke all on function app_private.validar_objeto(jsonb,text[],text[]),
  app_private.validar_fecha_iso(text),app_private.finalizar_informe_impl(uuid,jsonb)
  from public, anon, authenticated;

-- Elevacion imprescindible: clientes no tienen INSERT/UPDATE en tablas.
-- Fachada minima, sin SQL dinamico ni actor parametrizable; todas las comprobaciones
-- se realizan en la logica privada. Nunca otorga un bypass CRUD generico.
create function public.finalizar_informe(operation_id uuid, payload jsonb) returns jsonb
language sql volatile security definer set search_path = ''
as $$ select app_private.finalizar_informe_impl(operation_id,payload) $$;
revoke all on function public.finalizar_informe(uuid,jsonb) from public, anon, authenticated;
grant execute on function public.finalizar_informe(uuid,jsonb) to authenticated;
comment on function public.finalizar_informe(uuid,jsonb) is
  'Contrato v1 POLICE activo; atomico e idempotente por UUID/contenido JSONB. Sin adjuntos no verificados.';
comment on table public.informes is
  'Sin borradores. Finalizacion por finalizar_informe v1: autor/snapshot servidor, validacion y contador atomicos; Storage y PDF diferidos.';
commit;
