-- SOLO en un contenedor PostgreSQL NUEVO, sin red/volumen persistente y con
-- base vacia acc_transito_test_09. Nunca ejecutar en Supabase ni una BD existente.
-- Contrato minimo Auth para pruebas SQL: NO es el servicio Supabase Auth ni JWT.
-- Reproduccion (PowerShell; nombre de contenedor nuevo/exclusivo por ejecucion):
-- docker run -d --name acc-transito-test-09 --network none
--   --tmpfs /var/lib/postgresql/data -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine
-- docker exec acc-transito-test-09 createdb -U postgres acc_transito_test_09
-- Verificar container nuevo, NetworkMode=none, sin puertos/mounts persistentes.
-- Get-Content -Raw supabase/tests/support/plain_postgres_bootstrap.sql |
--   docker exec -i acc-transito-test-09 psql -X -U postgres -d acc_transito_test_09 -v ON_ERROR_STOP=1
-- Get-Content -Raw supabase/migrations/20261023022705_initial_remote_schema.sql |
--   docker exec -i acc-transito-test-09 psql -X -U postgres -d acc_transito_test_09 -v ON_ERROR_STOP=1
-- Get-Content -Raw supabase/tests/schema_security.sql |
--   docker exec -i acc-transito-test-09 psql -X -U postgres -d acc_transito_test_09 -v ON_ERROR_STOP=1
-- Tras verificar que es el contenedor exclusivo creado para esta prueba:
-- docker rm -f acc-transito-test-09
-- Sin contrasenas: trust SOLO en ese contenedor sin red/puertos ni datos reales.
begin;
do $$
begin
  if current_database() <> 'acc_transito_test_09' or
     exists (select 1 from pg_namespace where nspname = 'auth') or
     exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind in ('r','v','m','S','p')) then
    raise exception 'Destino no es la BD vacia aislada esperada';
  end if;
end $$;
create role anon nologin;
create role authenticated nologin;
-- Simula defaults historicos de Supabase para probar revocaciones explicitas.
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable set search_path = '' as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid
$$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
commit;
