# Reutiliza las cuatro carreras de 10 sobre el stack completo acumulado de 12.
# Ningun DROP/reset: fixtures adicionales solo en contenedor dedicado descartable.
param([Parameter(Mandatory=$true)][string]$Container)
$ErrorActionPreference='Stop'
if($Container -notmatch '^supabase_db_transito_storage_test_[a-f0-9]{8}$'){throw 'Destino no dedicado'}
$info=(& docker inspect $Container | ConvertFrom-Json)[0]
$expected=$Container.Substring('supabase_db_'.Length)
if($info.Config.Labels.'com.supabase.cli.project' -ne $expected){throw 'Etiqueta de destino incompatible'}
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'run_finalization_tests.ps1'))
$main=[regex]::Match($source,'(?m)^try \{\r?\n  \$containerId')
if(-not $main.Success){throw 'Inicio de harness historico no localizado'}
$definitions=$source.Substring($source.IndexOf('function Db('),$main.Index-$source.IndexOf('function Db('))
if(-not $definitions){throw 'Harness historico cambio; revisar adaptador'}
$definitions=$definitions.Replace('-d acc_transito_test_09','-d postgres')
$container=$Container
$sessions=[System.Collections.Generic.List[object]]::new()
Invoke-Expression $definitions
$initialReports=[int](Db 'select count(*) from public.informes;')
$initialCounter=[int](Db 'select ultimo_correlativo from app_private.contadores_gestion where gestion=2025;')
$start=$source.IndexOf("  FileSql '/work/tests/support/finalization_fixtures.sql'")
$end=$source.IndexOf("  Write-Output (Db 'select version();")
if($start -lt 0 -or $end -le $start){throw 'Bloque de concurrencia no localizado'}
$body=$source.Substring($start,$end-$start)
$body=$body.Replace("-ne '3'",('-ne '+($initialReports+3))).Replace("-ne '4'",('-ne '+($initialCounter+4)))
# El helper sintetico de 10 no fijaba search_path. Ajuste SOLO del fixture
# efimero, para que el advisor posterior pueda revisar tambien ese esquema.
$fixtureLine="  FileSql '/work/tests/support/finalization_fixtures.sql'"
$body=$body.Replace($fixtureLine,$fixtureLine+"`n  [void](Db `"alter function test_support.payload() set search_path='';`")")
& docker exec $container mkdir -p /work
if($LASTEXITCODE -ne 0){throw 'Directorio temporal no creado'}
& docker cp (Join-Path (Split-Path $PSScriptRoot -Parent) 'tests') "${container}:/work/tests"
if($LASTEXITCODE -ne 0){throw 'No se copiaron fixtures sinteticos'}
try {Invoke-Expression $body}
finally {foreach($s in $sessions){if(-not $s.Process.HasExited){[void]$s.Process.WaitForExit(18000)}}}
