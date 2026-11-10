-- Solo BD nueva descartable del harness. No ejecutar fixtures en Cloud.
begin;
\ir support/finalization_fixtures.sql
create temporary table catalog_expected(
  id bigint, payload jsonb, result jsonb, operation_id uuid
);
grant select, insert on catalog_expected to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
do $$
declare
  natures text[] := array['ARROLLAMIENTO','ATRICCION','ATROPELLO','CAIDA','CHOQUE',
    'COLISION','DESLIZAMIENTO','EMBARRANCAMIENTO','ENCUNETAMIENTO',
    'OTROS HECHOS DE TRANSITO','SUMERSION','VUELCO'];
  units text[] := array['EPI 3','EPI 5','EPI 6','EPI 8','EPI 9','EPI 11','RP 110',
    'TRANSITO','UPAR DELTA','PAC','DIPROVE','POFOMA','INTERPOL','BOMBEROS',
    'BATALLON DE SEGURIDAD FISICA'];
  categories text[] := array['A','B','C','M','P','T','Otros'];
  complainants text[] := array['BOL 110','DE OFICIO',
    'DENUNCIANTE: Persona ficticia Áñez','OTRO: Persona ficticia Muñoz'];
  p jsonb; r jsonb; op uuid; i integer; bad text; code text; before_count integer;
begin
  for i in 1..15 loop
    p := test_support.payload() || jsonb_build_object(
      'epi',units[i], 'naturaleza',natures[1+(i-1)%12],
      'denunciante_nombre',complainants[1+(i-1)%4],
      'descripcion',E'Texto dictado ficticio.\nTexto revisado con ñ y acentos.',
      'conductores',jsonb_build_array(jsonb_build_object(
        'nombre_completo','Conductor ficticio', 'licencia','FICTICIA',
        'categoria',categories[1+(i-1)%7], 'condicion_entrega','Observación ficticia')));
    op := gen_random_uuid();
    r := public.finalizar_informe(op,p);
    if r is distinct from public.finalizar_informe(op,p) then
      raise exception 'Replay del nuevo catalogo no es identico';
    end if;
    insert into catalog_expected values((r->>'id_informe')::bigint,p,r,op);
  end loop;
  -- Compatibilidad con APK anterior y ledger sin modificar payload historico.
  p := test_support.payload(); op := gen_random_uuid();
  r := public.finalizar_informe(op,p);
  if r is distinct from public.finalizar_informe(op,p) then
    raise exception 'Replay historico incompatible';
  end if;
  insert into catalog_expected values((r->>'id_informe')::bigint,p,r,op);
  select count(*) into before_count from public.informes;
  foreach bad in array array['NO EXISTE','COLISION ','', 'Colision'] loop
    code := null;
    begin
      perform public.finalizar_informe(gen_random_uuid(),
        test_support.payload() || jsonb_build_object('naturaleza',bad));
    exception when others then get stacked diagnostics code=returned_sqlstate;
    end;
    if code is distinct from '22023' then raise exception 'Naturaleza invalida aceptada: %',bad; end if;
  end loop;
  if (select count(*) from public.informes)<>before_count then
    raise exception 'Negativos dejaron informes parciales';
  end if;
end $$;

-- Otro contexto ADMIN recupera los valores exactamente como fueron enviados.
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
do $$
begin
  if (select count(*) from catalog_expected e join public.informes i on i.id_informe=e.id
      join public.conductores c on c.id_informe=i.id_informe
      where i.epi=e.payload->>'epi' and i.naturaleza=e.payload->>'naturaleza'
        and i.denunciante_nombre=e.payload->>'denunciante_nombre'
        and i.descripcion=e.payload->>'descripcion'
        and c.categoria=e.payload#>>'{conductores,0,categoria}'
        and c.condicion_entrega is not distinct from e.payload#>>'{conductores,0,condicion_entrega}')<>16 then
    raise exception 'ADMIN no recupera exactamente campos del formulario';
  end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
do $$
begin
  if exists(select 1 from public.informes where id_informe in(select id from catalog_expected))
    or exists(select 1 from public.conductores where id_informe in(select id from catalog_expected)) then
    raise exception 'POLICE B accede al informe o al conductor ajeno';
  end if;
end $$;
reset role;
do $$
begin
  if has_function_privilege('authenticated','app_private.finalizar_informe_impl(uuid,jsonb)','EXECUTE')
    or has_function_privilege('anon','public.finalizar_informe(uuid,jsonb)','EXECUTE')
    or has_table_privilege('authenticated','public.informes','INSERT,UPDATE,DELETE') then
    raise exception 'Se ampliaron privilegios';
  end if;
end $$;
select 'CATALOGO OK: 12 naturalezas, 15 unidades, 7 categorias, 4 denunciantes, texto revisado, observacion, replay y RLS' as resultado;
rollback;
