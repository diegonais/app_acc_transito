-- Catalogo y privilegios sobre stack local real, acumulado 09+10+12.
begin;
create temporary table checks12(ok boolean);
create function pg_temp.check12(ok boolean) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'Control de seguridad 12 fallido'; end if;
  insert into checks12 values(ok);
end $$;
select pg_temp.check12((select count(*)=2 and bool_and(not public) from storage.buckets where id in ('transito-evidencias','transito-pdf')));
select pg_temp.check12((select file_size_limit=5242880 and allowed_mime_types=array['image/jpeg','image/png'] from storage.buckets where id='transito-evidencias'));
select pg_temp.check12((select file_size_limit=10485760 and allowed_mime_types=array['application/pdf'] from storage.buckets where id='transito-pdf'));
select pg_temp.check12((select relrowsecurity from pg_class where oid='public.reservas_archivos'::regclass));
select pg_temp.check12((select relrowsecurity from pg_class where oid='app_private.cierres_archivos'::regclass));
select pg_temp.check12(not has_table_privilege('authenticated','public.reservas_archivos','INSERT,UPDATE,DELETE'));
select pg_temp.check12(not has_table_privilege('anon','public.reservas_archivos','SELECT,INSERT,UPDATE,DELETE'));
select pg_temp.check12(not has_table_privilege('authenticated','app_private.cierres_archivos','SELECT,INSERT,UPDATE,DELETE'));
select pg_temp.check12(not has_function_privilege('authenticated','app_private.bloquear_policia()','EXECUTE'));
select pg_temp.check12(not storage.allow_only_operation('object.upload'));
do $$
declare f text; r text; privileged boolean;
begin
  foreach f in array array[
    'public.reservar_archivo(uuid,uuid,text,text,text,bigint,text,bigint)',
    'public.consultar_reserva_verificacion(uuid)',
    'public.confirmar_archivo_backend(uuid,uuid,bigint,text,text)',
    'public.registrar_pdf(uuid)',
    'public.finalizar_informe(uuid,jsonb)',
    'app_private.archivo_permitido(text,text,boolean)'] loop
    select f like '%confirmar_archivo_backend%' into privileged;
    perform pg_temp.check12(not has_function_privilege('anon',f,'EXECUTE'));
    perform pg_temp.check12(has_function_privilege('authenticated',f,'EXECUTE')=not privileged);
    perform pg_temp.check12((select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid=f::regprocedure));
    perform pg_temp.check12(not exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
      where p.oid=f::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE'));
  end loop;
end $$;
select pg_temp.check12(has_function_privilege('service_role','public.confirmar_archivo_backend(uuid,uuid,bigint,text,text)','EXECUTE'));
select pg_temp.check12(not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname like 'transito_%' and cmd in ('UPDATE','DELETE','ALL')));
select count(*) as comprobaciones_storage_correctas from checks12;
rollback;
