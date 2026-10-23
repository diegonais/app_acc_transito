-- Intervencion 09: preparacion exclusivamente local, NO desplegar a Cloud.
-- Origen: app_database_migrations.dart v1-v3 y reglas del repositorio.
-- IDs bigint identity sustituyen INTEGER AUTOINCREMENT; estados/banderas siguen 0/1.
-- No se importan usuarios, hashes ni datos de dispositivos.
-- Fechas del hecho/llegada y auditoria siguen TEXT, como toIso8601String de Dart:
-- no se reinterpretan silenciosamente como timestamptz. La futura RPC validara
-- fecha, formato y zona antes de derivar gestion del anio civil del accidente.
-- CHECK gestion/fecha solo compara el anio representado; NO valida toda la fecha.
-- Sin RPC no se garantiza captura autentica de autor/snapshot, llenado completo,
-- asignacion concurrente del contador, ni idempotencia. No hay escritura cliente.
-- La RPC posterior debera obtener identidad desde auth.uid() y registros activos,
-- copiar snapshot en servidor, validar formulario y finalizar todo atomicamente.
-- No se agregan enums institucionales ausentes del esquema SQLite.
begin;

create schema app_private;
revoke all on schema app_private from public, anon, authenticated;
grant usage on schema app_private to authenticated;
-- app_private no debe figurar en schemas expuestos de PostgREST.

create table public.usuarios (
  id_usuario bigint generated always as identity primary key,
  auth_uid uuid not null unique references auth.users(id) on delete restrict,
  nombre_usuario text not null unique,
  rol text not null check (rol in ('ADMIN', 'POLICE')),
  estado integer not null default 1 check (estado in (0, 1)),
  fecha_creacion text not null,
  fecha_modificacion text not null
);

create table public.policias (
  id_policia bigint generated always as identity primary key,
  id_usuario bigint not null unique references public.usuarios(id_usuario)
    on update cascade on delete restrict,
  numero_placa text not null unique,
  grado text not null,
  nombres text not null,
  apellidos text not null,
  unidad text not null,
  sigla text not null,
  ci text not null,
  estado integer not null default 1 check (estado in (0, 1)),
  fecha_creacion text not null,
  fecha_modificacion text not null
);

create table public.informes (
  id_informe bigint generated always as identity primary key,
  id_policia bigint not null references public.policias(id_policia)
    on update cascade on delete restrict,
  gestion integer not null,
  correlativo integer not null check (correlativo > 0),
  numero_caso text not null unique,
  epi text not null,
  fecha_hora_llegada text,
  fecha_hora_hecho text,
  naturaleza text,
  lugar text,
  latitud double precision,
  longitud double precision,
  denunciante_nombre text,
  denunciante_documento text,
  denunciante_contacto text,
  descripcion text,
  condiciones_climaticas text,
  vehiculos_movidos integer check (vehiculos_movidos in (0, 1)),
  protagonistas_presentes integer check (protagonistas_presentes in (0, 1)),
  testigos text,
  efectos_personales text,
  estado integer not null default 1 check (estado in (0, 1)),
  fecha_creacion text not null,
  fecha_modificacion text not null,
  policia_nombre_snapshot text not null check (btrim(policia_nombre_snapshot) <> ''),
  policia_grado_snapshot text not null check (btrim(policia_grado_snapshot) <> ''),
  policia_placa_snapshot text not null check (btrim(policia_placa_snapshot) <> ''),
  policia_unidad_snapshot text not null check (btrim(policia_unidad_snapshot) <> ''),
  unique (gestion, correlativo),
  constraint gestion_anio_hecho check (
    fecha_hora_hecho is not null and
    fecha_hora_hecho ~ '^[0-9]{4}-' and
    gestion::text = substring(fecha_hora_hecho from 1 for 4)
  ),
  constraint numero_caso_coherente check (
    numero_caso = gestion::text || '-' ||
      case when correlativo < 1000000 then lpad(correlativo::text, 6, '0')
        else correlativo::text end
  )
);
-- No se decide un limite nuevo de seis digitos: Dart padLeft no trunca >999999.

create table public.conductores (
  id_conductor bigint generated always as identity primary key,
  id_informe bigint not null references public.informes(id_informe)
    on update cascade on delete restrict,
  nombre_completo text not null,
  edad integer check (edad >= 0),
  licencia text,
  categoria text,
  domicilio text,
  zona text,
  contactos text,
  condicion_entrega text,
  fecha_creacion text not null,
  unique (id_conductor, id_informe)
);
-- Se preserva nullabilidad SQLite; validaciones adicionales del formulario
-- (p.ej. licencia/categoria obligatorias) deben imponerse en la RPC futura.

create table public.vehiculos (
  id_vehiculo bigint generated always as identity primary key,
  id_informe bigint not null references public.informes(id_informe)
    on update cascade on delete restrict,
  id_conductor bigint,
  placa text,
  marca text,
  color text,
  tipo text,
  servicio text,
  fecha_creacion text not null,
  foreign key (id_conductor, id_informe)
    references public.conductores(id_conductor, id_informe)
    on update cascade on delete restrict
);
-- MATCH SIMPLE mantiene opcional id_conductor y asegura pertenencia si existe.

create table public.personas_involucradas (
  id_persona bigint generated always as identity primary key,
  id_informe bigint not null references public.informes(id_informe)
    on update cascade on delete restrict,
  nombre text not null,
  edad integer check (edad >= 0),
  tipo text not null check (tipo in ('HERIDO', 'FALLECIDO')),
  lugar_evacuacion text,
  fecha_creacion text not null
);

-- Sustituye rutas locales de fotos/croquis/PDF por referencias a objetos privados.
-- clase es un discriminador TECNICO de archivo, no un selector institucional.
-- No crea buckets ni asegura existencia/tipo/MIME del objeto en Storage.
create table public.archivos_informe (
  id_archivo bigint generated always as identity primary key,
  id_informe bigint not null references public.informes(id_informe)
    on update cascade on delete restrict,
  clase text not null check (clase in ('FOTOGRAFIA', 'CROQUIS', 'PDF')),
  bucket_id text not null check (bucket_id ~ '^[a-z0-9][a-z0-9_-]*$'),
  objeto text not null check (
    btrim(objeto) <> '' and objeto !~ '(^/|^[A-Za-z]:|\\|://)' and
    objeto !~ '(^|/)\.\.(/|$)'
  ),
  fecha_creacion text not null,
  unique (bucket_id, objeto),
  unique (id_archivo, id_informe, clase)
);

create table public.fotografias (
  id_fotografia bigint generated always as identity primary key,
  id_informe bigint not null references public.informes(id_informe)
    on update cascade on delete restrict,
  id_archivo bigint not null unique,
  clase_archivo text not null default 'FOTOGRAFIA' check (clase_archivo = 'FOTOGRAFIA'),
  tipo text not null check (tipo in ('PANORAMICA', 'LICENCIA', 'PLACA', 'OTRA')),
  descripcion text,
  fecha_creacion text not null,
  foreign key (id_archivo, id_informe, clase_archivo)
    references public.archivos_informe(id_archivo, id_informe, clase)
    on update cascade on delete restrict
);

-- Preparacion de un contador durable por gestion, sin algoritmo de asignacion.
-- La futura RPC debera bloquear/incrementar esta fila y persistir el informe en
-- la misma transaccion; NO usar MAX+1 concurrente ni aceptar gestion del cliente.
-- Idempotencia concreta se difiere: no se fija ahora un protocolo no ratificado.
create table app_private.contadores_gestion (
  gestion integer primary key,
  ultimo_correlativo integer not null check (ultimo_correlativo >= 0)
);
alter table app_private.contadores_gestion enable row level security;
revoke all on app_private.contadores_gestion from public, anon, authenticated;

create index idx_informes_estado_policia_fecha_hecho
  on public.informes(estado, id_policia, fecha_hora_hecho);
create index idx_informes_estado_fecha_hecho on public.informes(estado, fecha_hora_hecho);
create index idx_informes_policia on public.informes(id_policia);
create index idx_conductores_informe on public.conductores(id_informe);
create index idx_vehiculos_informe on public.vehiculos(id_informe);
create index idx_vehiculos_conductor_informe on public.vehiculos(id_conductor, id_informe);
create index idx_personas_informe on public.personas_involucradas(id_informe);
create index idx_fotografias_informe on public.fotografias(id_informe);
create index idx_archivos_informe on public.archivos_informe(id_informe);

-- Unico SECURITY DEFINER: lectura acotada de la identidad del solicitante.
-- Evita recursion usuarios<->policias en RLS. No recibe parametros ni modifica
-- datos. Solo devuelve IDs/rol del propio auth.uid(), nunca perfiles ajenos.
-- ADMIN no requiere perfil; POLICE requiere perfil activo. No usa metadata JWT.
create function app_private.actor()
returns table (id_usuario bigint, rol text, id_policia bigint)
language sql stable security definer set search_path = ''
as $$
  select u.id_usuario, u.rol, p.id_policia
  from public.usuarios u
  left join public.policias p on p.id_usuario = u.id_usuario and p.estado = 1
  where u.auth_uid = (select auth.uid()) and u.estado = 1
    and (u.rol = 'ADMIN' or (u.rol = 'POLICE' and p.id_policia is not null))
$$;
revoke all on function app_private.actor() from public, anon, authenticated;
grant execute on function app_private.actor() to authenticated;

-- Triggers SECURITY INVOKER: ninguna elevacion ni punto de entrada RPC.
create function app_private.proteger_informe() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Informe no eliminable' using errcode = '23514';
  end if;
  if (to_jsonb(new) - 'estado' - 'fecha_modificacion') is distinct from
     (to_jsonb(old) - 'estado' - 'fecha_modificacion') or
     not (old.estado = 1 and new.estado = 0) then
    raise exception 'Contenido finalizado inmutable; solo inactivacion' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger proteger_informe before update or delete on public.informes
  for each row execute function app_private.proteger_informe();
-- El ADMIN efectivo para inactivar debe validarse en la RPC posterior.
-- Ningun cliente (tampoco ADMIN) tiene UPDATE directo.

create function app_private.proteger_contenido() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'Contenido finalizado inmutable' using errcode = '23514';
end $$;
-- Inserciones de hijos/archivos siguen reservadas al servidor. El cierre de ese
-- conjunto, y la carga diferida de PDF, requieren protocolo RPC/Storage futuro.
create function app_private.proteger_contador() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Contador no eliminable' using errcode = '23514';
  end if;
  if new.gestion <> old.gestion or new.ultimo_correlativo < old.ultimo_correlativo then
    raise exception 'Contador no puede retroceder' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger proteger_contador before update or delete on app_private.contadores_gestion
  for each row execute function app_private.proteger_contador();
revoke all on function app_private.proteger_informe(), app_private.proteger_contenido(),
  app_private.proteger_contador() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['usuarios','policias','informes','conductores',
    'vehiculos','personas_involucradas','fotografias','archivos_informe'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant select on table public.%I to authenticated', t);
  end loop;
  foreach t in array array['conductores','vehiculos','personas_involucradas','fotografias','archivos_informe'] loop
    execute format('create trigger proteger_contenido before update or delete on public.%I
      for each row execute function app_private.proteger_contenido()', t);
  end loop;
end $$;
-- Revoca solo nuestras secuencias, sin alterar objetos ajenos/defaults globales.
do $$
declare s record;
begin
  for s in select pg_get_serial_sequence('public.' || t, id) as nombre
    from (values ('usuarios','id_usuario'),('policias','id_policia'),
      ('informes','id_informe'),('conductores','id_conductor'),
      ('vehiculos','id_vehiculo'),('personas_involucradas','id_persona'),
      ('fotografias','id_fotografia'),('archivos_informe','id_archivo')) v(t,id)
  loop
    execute format('revoke all on sequence %s from public, anon, authenticated', s.nombre);
  end loop;
end $$;

create policy leer_usuarios on public.usuarios for select to authenticated
  using (exists (select 1 from app_private.actor() a
    where a.rol = 'ADMIN' or a.id_usuario = usuarios.id_usuario));
create policy leer_policias on public.policias for select to authenticated
  using (exists (select 1 from app_private.actor() a
    where a.rol = 'ADMIN' or a.id_policia = policias.id_policia));
create policy leer_informes on public.informes for select to authenticated
  using (estado = 1 and exists (select 1 from app_private.actor() a
    where a.rol = 'ADMIN' or a.id_policia = informes.id_policia));
-- La subconsulta usa RLS de informes: ID directo de hijo no evita autorizacion.
do $$
declare t text;
begin
  foreach t in array array['conductores','vehiculos','personas_involucradas',
    'fotografias','archivos_informe'] loop
    execute format('create policy leer_por_informe on public.%I for select to authenticated
      using (exists (select 1 from public.informes i where i.id_informe = %I.id_informe))', t, t);
  end loop;
end $$;
comment on function app_private.actor() is
  'Solo identidad activa propia; SECURITY DEFINER acotado para evitar recursion RLS. Esquema NO expuesto.';
comment on table public.archivos_informe is
  'Referencias de Storage privado; sin buckets, permisos ni validacion fisica de objetos en esta fase.';
comment on table public.informes is
  'Sin borradores. RPC de finalizacion aun ausente: no garantiza captura de snapshot/autor ni validacion completa.';
commit;
