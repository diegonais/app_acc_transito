-- Intervencion 12. Solo stack LOCAL descartable con Storage API real.
-- Defaults tecnicos de demo: 12 fotos + 1 croquis/operacion, 3 PDF/informe,
-- 5 MiB imagen, 10 MiB PDF, reserva 1 hora. No son limites institucionales.
begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('transito-evidencias','transito-evidencias',false,5242880,array['image/jpeg','image/png']),
       ('transito-pdf','transito-pdf',false,10485760,array['application/pdf']);

-- Manifest de cargas: separado de archivos_informe, que exige informe ya finalizado.
create table public.reservas_archivos (
  reserva_id uuid primary key,
  auth_uid uuid not null references auth.users(id) on delete restrict,
  operation_id uuid not null,
  id_informe bigint references public.informes(id_informe) on delete restrict,
  id_archivo bigint unique,
  clase text not null check (clase in ('FOTOGRAFIA','CROQUIS','PDF')),
  tipo text check (tipo in ('PANORAMICA','LICENCIA','PLACA','OTRA')),
  bucket_id text not null,
  objeto text not null,
  mime text not null,
  bytes_esperados bigint not null check (bytes_esperados > 0),
  sha256_esperado text not null check (sha256_esperado ~ '^[a-f0-9]{64}$'),
  bytes_verificados bigint,
  sha256_verificado text,
  estado text not null default 'RESERVADO' check (estado in ('RESERVADO','VERIFICADO','VINCULADO')),
  creado_en timestamptz not null default clock_timestamp(),
  expira_en timestamptz not null default clock_timestamp()+interval '1 hour',
  verificado_en timestamptz,
  vinculado_en timestamptz,
  unique (bucket_id,objeto),
  foreign key (id_archivo,id_informe,clase) references public.archivos_informe(id_archivo,id_informe,clase) on delete restrict,
  check ((clase='FOTOGRAFIA') = (tipo is not null)),
  check (clase<>'CROQUIS' or mime='image/png'), -- Captura cartografica PNG existente en Flutter.
  check ((clase='PDF' and bucket_id='transito-pdf' and mime='application/pdf' and bytes_esperados<=10485760)
    or (clase<>'PDF' and bucket_id='transito-evidencias' and mime in ('image/jpeg','image/png') and bytes_esperados<=5242880)),
  check (estado='RESERVADO' or (bytes_verificados=bytes_esperados and sha256_verificado=sha256_esperado
    and bytes_verificados is not null and sha256_verificado is not null and verificado_en is not null)),
  check ((estado='VINCULADO') = (id_archivo is not null and id_informe is not null and vinculado_en is not null))
);
alter table public.reservas_archivos enable row level security;
revoke all on public.reservas_archivos from public,anon,authenticated;
grant select on public.reservas_archivos to authenticated;
create index reservas_operacion on public.reservas_archivos(operation_id);
create index reservas_informe on public.reservas_archivos(id_informe);
create index reservas_usuario on public.reservas_archivos(auth_uid);
create policy leer_reservas on public.reservas_archivos for select to authenticated using (
  (auth_uid=(select auth.uid()) and exists(select 1 from app_private.actor() where rol='POLICE'))
  or (estado='VINCULADO' and exists(select 1 from public.informes i where i.id_informe=reservas_archivos.id_informe))
);

-- Facade de reserva: identidad real de tablas protegidas; serializa cupos por autor.
create function app_private.bloquear_policia() returns bigint
language plpgsql set search_path='' as $$
declare u public.usuarios; p public.policias;
begin
  select * into u from public.usuarios where auth_uid=auth.uid() for share;
  if not found or u.estado<>1 or u.rol<>'POLICE' then
    raise exception 'POLICE activo requerido' using errcode='42501'; end if;
  select * into p from public.policias where id_usuario=u.id_usuario for share;
  if not found or p.estado<>1 then raise exception 'Perfil activo requerido' using errcode='42501'; end if;
  return p.id_policia;
end $$;
revoke all on function app_private.bloquear_policia() from public,anon,authenticated;

create function public.reservar_archivo(p_reserva uuid,p_operacion uuid,p_clase text,
  p_tipo text,p_mime text,p_bytes bigint,p_sha256 text,p_informe bigint default null)
returns public.reservas_archivos language plpgsql security definer set search_path='' as $$
declare a record; r public.reservas_archivos; b text; ruta text;
begin
  select app_private.bloquear_policia() as id_policia into a;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,12));
  if p_reserva is null or p_operacion is null or p_clase is null or p_mime is null
    or p_bytes is null or p_sha256 is null then raise exception 'Reserva incompleta' using errcode='22023'; end if;
  if p_clase='PDF' then
    if not exists(select 1 from public.informes where id_informe=p_informe and id_policia=a.id_policia and estado=1) then
      raise exception 'Informe propio activo requerido' using errcode='42501'; end if;
    b:='transito-pdf';
  else
    if p_informe is not null then raise exception 'Evidencias solo prefinalizacion' using errcode='22023'; end if;
    b:='transito-evidencias';
  end if;
  ruta:=auth.uid()::text||'/'||p_operacion::text||'/'||p_reserva::text;
  select * into r from public.reservas_archivos where reserva_id=p_reserva;
  if found then
    if r.auth_uid<>auth.uid() then raise exception 'Reserva ajena' using errcode='42501'; end if;
    if row(r.operation_id,r.clase,r.tipo,r.mime,r.bytes_esperados,r.sha256_esperado,
      case when r.clase='PDF' then r.id_informe else null end)
      is distinct from row(p_operacion,p_clase,p_tipo,p_mime,p_bytes,p_sha256,p_informe) then
      raise exception 'Reserva reutilizada con otro contenido' using errcode='PT409'; end if;
    return r;
  end if;
  if p_clase<>'PDF' and exists(select 1 from app_private.operaciones_finalizacion where operation_id=p_operacion) then
    raise exception 'Operacion ya finalizada' using errcode='PT409'; end if;
  if (p_clase='FOTOGRAFIA' and (select count(*) from public.reservas_archivos where operation_id=p_operacion and auth_uid=auth.uid() and clase=p_clase and (estado='VINCULADO' or expira_en>clock_timestamp()))>=12)
    or (p_clase='CROQUIS' and exists(select 1 from public.reservas_archivos where operation_id=p_operacion and auth_uid=auth.uid() and clase=p_clase and (estado='VINCULADO' or expira_en>clock_timestamp())))
    or (p_clase='PDF' and (select count(*) from public.reservas_archivos where id_informe=p_informe and clase='PDF' and (estado='VINCULADO' or expira_en>clock_timestamp()))>=3) then
    raise exception 'Cupo tecnico alcanzado' using errcode='22023'; end if;
  insert into public.reservas_archivos(reserva_id,auth_uid,operation_id,id_informe,clase,tipo,bucket_id,objeto,mime,bytes_esperados,sha256_esperado)
    values(p_reserva,auth.uid(),p_operacion,p_informe,p_clase,p_tipo,b,ruta,p_mime,p_bytes,p_sha256) returning * into r;
  return r;
end $$;

-- Solo helpers acotados para Storage. Sin UPDATE/DELETE: no overwrite, move ni upsert.
create function app_private.archivo_permitido(b text,n text,carga boolean) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from auth.sessions s where s.user_id=auth.uid()
    and s.id::text=auth.jwt()->>'session_id' and (s.not_after is null or s.not_after>clock_timestamp()))
  and exists(select 1 from public.reservas_archivos r where r.bucket_id=b and r.objeto=n
    and exists(select 1 from app_private.actor() a where
      (r.auth_uid=auth.uid() and a.rol='POLICE' and
        (case when carga then r.estado='RESERVADO' and r.expira_en>clock_timestamp()
         else r.estado<>'VINCULADO' and r.expira_en>clock_timestamp() end)
        and (r.clase<>'PDF' or exists(select 1 from public.informes i where i.id_informe=r.id_informe and i.estado=1 and i.id_policia=a.id_policia)))
      or (not carga and r.estado='VINCULADO' and exists(select 1 from public.informes i
        where i.id_informe=r.id_informe and i.estado=1 and (a.rol='ADMIN' or a.id_policia=i.id_policia)))))
$$;
revoke all on function app_private.archivo_permitido(text,text,boolean) from public,anon,authenticated;
grant execute on function app_private.archivo_permitido(text,text,boolean) to authenticated;
create policy transito_subir on storage.objects for insert to authenticated
  with check (storage.allow_only_operation('object.upload') and app_private.archivo_permitido(bucket_id,name,true));
create policy transito_leer on storage.objects for select to authenticated
  using (storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info','object.head_authenticated_info'])
    and app_private.archivo_permitido(bucket_id,name,false));

-- Verificador local confiable obtiene descriptor como usuario y descarga por Storage API.
create function public.consultar_reserva_verificacion(p_reserva uuid) returns public.reservas_archivos
language plpgsql security definer set search_path='' as $$
declare r public.reservas_archivos;
begin
  select * into r from public.reservas_archivos where reserva_id=p_reserva and auth_uid=auth.uid();
  if not found or not exists(select 1 from app_private.actor() where rol='POLICE')
    or (r.estado<>'VINCULADO' and r.expira_en<=clock_timestamp())
    or (r.clase='PDF' and not exists(select 1 from public.informes i join app_private.actor() a on a.id_policia=i.id_policia where i.id_informe=r.id_informe and i.estado=1)) then
    raise exception 'Reserva no autorizada o caducada' using errcode='42501'; end if;
  return r;
end $$;

-- Entrada exclusiva del componente servidor, NO confirmacion declarativa del cliente.
-- auth_uid solo lo envía ese servicio tras validar JWT con GoTrue y descargar bytes.
create function public.confirmar_archivo_backend(p_reserva uuid,p_uid uuid,p_bytes bigint,p_sha256 text,p_mime text)
returns text language plpgsql security definer set search_path='' as $$
declare r public.reservas_archivos;
begin
  perform 1 from public.usuarios where auth_uid=p_uid and estado=1 and rol='POLICE' for share;
  if not found then raise exception 'Actor inactivo' using errcode='42501'; end if;
  perform 1 from public.policias p join public.usuarios u using(id_usuario)
    where u.auth_uid=p_uid and p.estado=1 for share of p;
  if not found then raise exception 'Perfil inactivo' using errcode='42501'; end if;
  select * into r from public.reservas_archivos where reserva_id=p_reserva and auth_uid=p_uid for update;
  if not found or (r.estado<>'VINCULADO' and r.expira_en<=clock_timestamp()) then
    raise exception 'Reserva no vigente' using errcode='42501'; end if;
  if row(r.bytes_esperados,r.sha256_esperado,r.mime) is distinct from row(p_bytes,p_sha256,p_mime) then
    raise exception 'Bytes no coinciden con reserva' using errcode='22023'; end if;
  if not exists(select 1 from storage.objects where bucket_id=r.bucket_id and name=r.objeto) then
    raise exception 'Objeto inexistente' using errcode='22023'; end if;
  if r.estado='RESERVADO' then
    update public.reservas_archivos set estado='VERIFICADO',bytes_verificados=p_bytes,
      sha256_verificado=p_sha256,verificado_en=clock_timestamp() where reserva_id=p_reserva;
    return 'VERIFICADO';
  end if;
  return r.estado;
end $$;

create table app_private.cierres_archivos (
  operation_id uuid primary key,
  auth_uid uuid not null references auth.users(id),
  payload jsonb not null
);
alter table app_private.cierres_archivos enable row level security;
revoke all on app_private.cierres_archivos from public,anon,authenticated;
create index cierres_archivos_usuario on app_private.cierres_archivos(auth_uid);

-- Preserva impl 10 intacta y su idempotencia. Nueva fachada añade UUIDs de reservas.
create or replace function public.finalizar_informe(operation_id uuid,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.reservas_archivos; ids uuid[]; id uuid; res jsonb; f bigint; prev record;
begin
  perform app_private.bloquear_policia();
  if operation_id is null then raise exception 'Operacion requerida' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(operation_id::text,12));
  select * into prev from app_private.cierres_archivos c where c.operation_id=finalizar_informe.operation_id;
  if found and prev.auth_uid<>auth.uid() then
    raise exception 'Operacion ajena' using errcode='42501'; end if;
  if found and prev.payload is distinct from payload then
    raise exception 'Operacion/contenido incompatible' using errcode='PT409'; end if;
  if payload ? 'archivos' then
    if jsonb_typeof(payload->'archivos')<>'array' then raise exception 'archivos requiere array UUID' using errcode='22023'; end if;
    select array_agg(value::uuid order by value) into ids from jsonb_array_elements_text(payload->'archivos');
    if cardinality(ids)>13 or cardinality(ids)<>(select count(distinct x) from unnest(ids) x) then
      raise exception 'Reservas duplicadas o excesivas' using errcode='22023'; end if;
  end if;
  if ids is not null and not exists(select 1 from app_private.cierres_archivos c where c.operation_id=finalizar_informe.operation_id)
    and exists(select 1 from app_private.operaciones_finalizacion o where o.operation_id=finalizar_informe.operation_id) then
    raise exception 'No agregar evidencias a cierre historico' using errcode='PT409'; end if;
  foreach id in array coalesce(ids,array[]::uuid[]) loop
    select * into r from public.reservas_archivos where reserva_id=id for update;
    if not found or r.auth_uid<>auth.uid() or r.operation_id<>operation_id or r.clase='PDF'
      or r.estado not in ('VERIFICADO','VINCULADO') or (r.estado='VERIFICADO' and r.expira_en<=clock_timestamp())
      or not exists(select 1 from storage.objects where bucket_id=r.bucket_id and name=r.objeto) then
      raise exception 'Evidencia no verificada o ajena' using errcode='PT422'; end if;
  end loop;
  res:=app_private.finalizar_informe_impl(operation_id,payload-'archivos');
  insert into app_private.cierres_archivos values(operation_id,auth.uid(),payload) on conflict do nothing;
  foreach id in array coalesce(ids,array[]::uuid[]) loop
    select * into r from public.reservas_archivos where reserva_id=id;
    if r.estado='VINCULADO' then
      if r.id_informe<>(res->>'id_informe')::bigint then raise exception 'Vinculo incompatible' using errcode='PT409'; end if;
      continue;
    end if;
    insert into public.archivos_informe(id_informe,clase,bucket_id,objeto,fecha_creacion)
      values((res->>'id_informe')::bigint,r.clase,r.bucket_id,r.objeto,to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')) returning id_archivo into f;
    if r.clase='FOTOGRAFIA' then
      insert into public.fotografias(id_informe,id_archivo,tipo,fecha_creacion)
        values((res->>'id_informe')::bigint,f,r.tipo,to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'));
    end if;
    update public.reservas_archivos set estado='VINCULADO',id_archivo=f,id_informe=(res->>'id_informe')::bigint,vinculado_en=clock_timestamp() where reserva_id=id;
  end loop;
  return res;
end $$;

create function public.registrar_pdf(p_reserva uuid) returns bigint
language plpgsql security definer set search_path='' as $$
declare r public.reservas_archivos; f bigint;
begin
  perform app_private.bloquear_policia();
  select * into r from public.reservas_archivos where reserva_id=p_reserva and auth_uid=auth.uid() for update;
  if not found or r.clase<>'PDF' or not exists(select 1 from public.informes i join app_private.actor() a
    on a.id_policia=i.id_policia and a.rol='POLICE' where i.id_informe=r.id_informe and i.estado=1) then
    raise exception 'PDF propio requerido' using errcode='42501'; end if;
  if r.estado='VINCULADO' then return r.id_archivo; end if;
  if r.estado<>'VERIFICADO' or r.expira_en<=clock_timestamp() or not exists(select 1 from storage.objects where bucket_id=r.bucket_id and name=r.objeto) then
    raise exception 'PDF no verificado' using errcode='PT422'; end if;
  insert into public.archivos_informe(id_informe,clase,bucket_id,objeto,fecha_creacion)
    values(r.id_informe,'PDF',r.bucket_id,r.objeto,to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')) returning id_archivo into f;
  update public.reservas_archivos set estado='VINCULADO',id_archivo=f,vinculado_en=clock_timestamp() where reserva_id=p_reserva;
  return f;
end $$;

revoke all on function public.reservar_archivo(uuid,uuid,text,text,text,bigint,text,bigint),
  public.consultar_reserva_verificacion(uuid),public.confirmar_archivo_backend(uuid,uuid,bigint,text,text),
  public.registrar_pdf(uuid) from public,anon,authenticated;
grant execute on function public.reservar_archivo(uuid,uuid,text,text,text,bigint,text,bigint),
  public.consultar_reserva_verificacion(uuid),public.registrar_pdf(uuid) to authenticated;
grant execute on function public.confirmar_archivo_backend(uuid,uuid,bigint,text,text) to service_role;
commit;
