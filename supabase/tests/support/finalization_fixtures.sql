-- SOLO fixtures sinteticos en la BD descartable del harness; nunca migracion.
create schema test_support;
create function test_support.payload() returns jsonb language sql immutable as $$
select '{"epi":"EPI ficticia","fecha_hora_hecho":"2025-12-31T23:59:59.000",
"fecha_hora_llegada":"2026-01-01T00:01:00.000","naturaleza":"Colisión",
"lugar":"Lugar ficticio","denunciante_nombre":"Persona ficticia",
"denunciante_contacto":"Contacto ficticio","descripcion":"Descripcion ficticia",
"condiciones_climaticas":"Texto libre","vehiculos_movidos":false,
"protagonistas_presentes":true,"testigos":"Sin testigos","efectos_personales":"Sin efectos",
"conductores":[{"nombre_completo":"Conductor ficticio","licencia":"FICTICIA","categoria":"Texto libre"}],
"vehiculos":[{"driver_index":0,"placa":"FICTICIA","marca":"Texto libre","color":"Texto libre","tipo":"Texto libre","servicio":"Texto libre"}],
"personas":[{"nombre":"Persona ficticia","edad":0,"tipo":"HERIDO"}]}'::jsonb
$$;
grant usage on schema test_support to authenticated, anon;
grant execute on function test_support.payload() to authenticated, anon;
insert into auth.users(id) select ('10000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
  from generate_series(1,6) n;
insert into public.usuarios(id_usuario,auth_uid,nombre_usuario,rol,estado,fecha_creacion,fecha_modificacion)
overriding system value select 1000+n,('10000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  'rpc_ficticio_'||n,case when n=1 then 'ADMIN' else 'POLICE' end,
  case when n=5 then 0 else 1 end,'2026-10-22','2026-10-22' from generate_series(1,6) n;
insert into public.policias(id_policia,id_usuario,numero_placa,grado,nombres,apellidos,unidad,sigla,ci,
  estado,fecha_creacion,fecha_modificacion) overriding system value
select 1000+n,1000+n,'RPC-FICTICIA-'||n,'Grado ficticio','Nombre','Ficticio '||n,
  'Unidad ficticia','TEST','CI ficticio',case when n=6 then 0 else 1 end,'2026-10-22','2026-10-22'
  from (values (2),(3),(5),(6)) v(n);
