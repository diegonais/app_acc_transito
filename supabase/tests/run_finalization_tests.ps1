# Harness local reproducible. Ejecutar desde cualquier directorio con Docker.
# No usa conexiones remotas, puertos, credenciales ni volumen persistente.
# Auth/JWT/PostgREST NO se prueban: bootstrap simulado sobre PostgreSQL real.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$container = 'acc-transito-test-10-' + [guid]::NewGuid().ToString('N').Substring(0,10)
$containerId = $null
$sessions = [System.Collections.Generic.List[object]]::new()
function Db([string]$sql) {
  $result = $sql | & docker exec -i $container psql -X -q -At -U postgres -d acc_transito_test_09 -v ON_ERROR_STOP=1
  if ($LASTEXITCODE -ne 0) { throw 'SQL de test fallo' }
  return ($result -join "`n")
}
function FileSql([string]$path) {
  & docker exec $container psql -X -q -U postgres -d acc_transito_test_09 -v ON_ERROR_STOP=1 -f $path
  if ($LASTEXITCODE -ne 0) { throw "Prueba fallo: $path" }
}
function Session([string]$app,[string]$sql) {
  $info = [System.Diagnostics.ProcessStartInfo]::new()
  $info.FileName = 'docker'
  $info.Arguments = "exec -i $container psql -X -q -At -U postgres -d acc_transito_test_09 -v ON_ERROR_STOP=1 -v VERBOSITY=verbose"
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $proc = [System.Diagnostics.Process]::new()
  $proc.StartInfo = $info
  [void]$proc.Start()
  $outTask = $proc.StandardOutput.ReadToEndAsync()
  $errTask = $proc.StandardError.ReadToEndAsync()
  $proc.StandardInput.Write("set application_name='$app'; set statement_timeout='15s'; $sql")
  $proc.StandardInput.Close()
  $s = [pscustomobject]@{Process=$proc; Output=$outTask; Error=$errTask}
  $sessions.Add($s)
  return $s
}
function Finish($s,[string]$expectedError='') {
  if (-not $s.Process.WaitForExit(20000)) { throw 'Sesion excedio tiempo' }
  $output = $s.Output.GetAwaiter().GetResult()
  $err = $s.Error.GetAwaiter().GetResult()
  if ($expectedError) {
    if ($s.Process.ExitCode -eq 0 -or $err -notmatch $expectedError) { throw "Se esperaba $expectedError; recibido $err" }
  } elseif ($s.Process.ExitCode -ne 0) { throw $err }
  return ($output -split '\r?\n' | Where-Object { $_.StartsWith('{') } | Select-Object -First 1)
}
function WaitEvent([string]$app,[string]$column,[string]$value) {
  for ($i=0; $i -lt 50; $i++) {
    if ((Db "select count(*) from pg_stat_activity where application_name='$app' and $column='$value';") -eq '1') { return }
    Start-Sleep -Milliseconds 40
  }
  throw "No se observo concurrencia real: $app $column $value"
}
function ActorSql([int]$actor,[string]$op,[string]$extra='') {
  return "begin; set local role authenticated; select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-00000000000$actor',true); select public.finalizar_informe('$op',test_support.payload()$extra);"
}
try {
  $containerId = (& docker run --detach --name $container --network none --tmpfs /var/lib/postgresql/data -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'No se creo contenedor' }
  $inspect = (& docker inspect $container | ConvertFrom-Json)[0]
  if ($inspect.Id -ne $containerId -or $inspect.HostConfig.NetworkMode -ne 'none' -or
    $inspect.Mounts.Count -ne 0 -or $inspect.HostConfig.PortBindings.PSObject.Properties.Count -gt 0) {
    throw 'Destino no cumple aislamiento'
  }
  for ($i=0; $i -lt 60; $i++) {
    & docker exec $container pg_isready -U postgres 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Milliseconds 250
  }
  & docker exec $container createdb -U postgres acc_transito_test_09
  if ($LASTEXITCODE -ne 0) { throw 'No se creo BD vacia' }
  & docker cp (Join-Path $repo 'supabase') "${container}:/work"
  if ($LASTEXITCODE -ne 0) { throw 'No se copiaron artefactos' }
  FileSql '/work/tests/support/plain_postgres_bootstrap.sql'
  # Acumuladas desde cero; nunca reset/DROP sobre BD preexistente.
  foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $repo 'supabase/migrations') -Filter '*.sql' | Sort-Object Name)) {
    FileSql ("/work/migrations/" + $f.Name)
  }
  FileSql '/work/tests/schema_security.sql'
  FileSql '/work/tests/finalization_rpc.sql'
  # Fixtures de concurrencia confirmados SOLO dentro del contenedor descartable.
  FileSql '/work/tests/support/finalization_fixtures.sql'
  $a = Session 'race_a' ((ActorSql 2 '30000000-0000-4000-8000-000000000001') + 'select pg_sleep(2); commit;')
  WaitEvent 'race_a' 'wait_event' 'PgSleep'
  $b = Session 'race_b' ((ActorSql 3 '30000000-0000-4000-8000-000000000002') + 'commit;')
  WaitEvent 'race_b' 'wait_event_type' 'Lock'
  $ra = (Finish $a) | ConvertFrom-Json
  $rb = (Finish $b) | ConvertFrom-Json
  if ($ra.correlativo -eq $rb.correlativo -or $ra.gestion -ne 2025 -or $rb.gestion -ne 2025) { throw 'Colision de correlativo' }
  Write-Output 'CONCURRENCIA 1 OK: autores distintos, misma gestion, numeros distintos; espera de bloqueo observada.'

  $a = Session 'idem_a' ((ActorSql 2 '30000000-0000-4000-8000-000000000003') + 'select pg_sleep(2); commit;')
  WaitEvent 'idem_a' 'wait_event' 'PgSleep'
  $b = Session 'idem_b' ((ActorSql 2 '30000000-0000-4000-8000-000000000003') + 'commit;')
  WaitEvent 'idem_b' 'wait_event_type' 'Lock'
  $ra = Finish $a
  $rb = Finish $b
  if ($ra -ne $rb) { throw 'Reintento concurrente devuelve otro caso' }
  if ((Db 'select count(*) from public.informes;') -ne '3') { throw 'Informe duplicado' }
  Write-Output 'CONCURRENCIA 2 OK: misma clave/actor/contenido, un solo informe y resultado identico.'

  $a = Session 'conflict_a' ((ActorSql 2 '30000000-0000-4000-8000-000000000004') + 'select pg_sleep(2); commit;')
  WaitEvent 'conflict_a' 'wait_event' 'PgSleep'
  $b = Session 'conflict_b' ((ActorSql 2 '30000000-0000-4000-8000-000000000004' "||jsonb_build_object('lugar','Distinto')") + 'commit;')
  WaitEvent 'conflict_b' 'wait_event_type' 'Lock'
  [void](Finish $a)
  [void](Finish $b 'PT409')
  if ((Db 'select ultimo_correlativo from app_private.contadores_gestion where gestion=2025;') -ne '4') { throw 'Conflicto consume numero' }
  Write-Output 'CONCURRENCIA 3 OK: misma clave con contenido distinto da PT409 y no consume numero.'

  $a = Session 'snapshot_a' ((ActorSql 2 '30000000-0000-4000-8000-000000000005') + 'select pg_sleep(2); commit;')
  WaitEvent 'snapshot_a' 'wait_event' 'PgSleep'
  $b = Session 'snapshot_b' "update public.policias set nombres='Perfil cambiado' where id_policia=1002;"
  WaitEvent 'snapshot_b' 'wait_event_type' 'Lock'
  $ra = (Finish $a) | ConvertFrom-Json
  [void](Finish $b)
  if ((Db "select policia_nombre_snapshot from public.informes where id_informe=$($ra.id_informe);") -ne 'Nombre Ficticio 2') { throw 'Snapshot inconsistente' }
  Write-Output 'CONCURRENCIA 4 OK: edicion de perfil espera captura, snapshot anterior preservado.'
  Write-Output (Db 'select version(); select count(*) as informes from public.informes;')
} finally {
  foreach ($s in $sessions) { if (-not $s.Process.HasExited) { [void]$s.Process.WaitForExit(18000) } }
  if ($containerId) {
    $actual = & docker inspect $container --format '{{.Id}}' 2>$null
    if ($actual -eq $containerId) { & docker rm -f $container | Out-Null }
  }
}
