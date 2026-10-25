# Supabase LOCAL real: CLI 2.122.0, Docker Desktop Windows, Node >=20.
# Crear entorno nuevo, aplicar migraciones originales, probar y limpiar SOLO ese
# entorno. No link, reset de BD previa ni Cloud. Claves/salidas CLI solo temporales.
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$suffix=[guid]::NewGuid().ToString('N')
$taskDir=Join-Path ([IO.Path]::GetTempPath()) ('transito-edge-'+$suffix)
$project='transito_edge_test_'+$suffix.Substring(0,8)
$networkId=$null
$oldFlutterPdfs=$env:TRANSITO_FLUTTER_PDFS
$oldPythonBytecode=$env:PYTHONDONTWRITEBYTECODE
New-Item -ItemType Directory -Path $taskDir | Out-Null
try {
  if(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object LocalPort -in @(57520,57521,57522,57523)){throw 'Puertos de prueba ocupados; no tocar stack existente'}
  & npx --yes supabase@2.122.0 --workdir $taskDir init *> (Join-Path $taskDir 'init.log')
  if($LASTEXITCODE -ne 0){throw 'CLI init fallo'}
  # Ejecutar Dart sin editarlo ni crear caches/build en el arbol original.
  $flutterCopy=Join-Path $taskDir 'flutter-snapshot'
  $pdfOutput=Join-Path $taskDir 'flutter-pdf'
  New-Item -ItemType Directory -Path $flutterCopy,$pdfOutput | Out-Null
  & git -C $repo archive --format=tar --output (Join-Path $taskDir 'flutter.tar') HEAD
  if($LASTEXITCODE -ne 0){throw 'Snapshot Flutter fallo'}
  & tar -xf (Join-Path $taskDir 'flutter.tar') -C $flutterCopy
  if($LASTEXITCODE -ne 0){throw 'Extraccion Flutter fallo'}
  Push-Location $flutterCopy
  try {
    & flutter pub get --offline --enforce-lockfile
    if($LASTEXITCODE -ne 0){throw 'Dependencias Flutter offline no disponibles'}
    & flutter test --no-pub "--dart-define=PDF_REVIEW_OUTPUT=$($pdfOutput.Replace('\','/'))/informe.pdf" test/services/direct_action_report_pdf_service_test.dart
    if($LASTEXITCODE -ne 0){throw 'Generador PDF Flutter fallo'}
  } finally {Pop-Location}
  if(@(Get-ChildItem -LiteralPath $pdfOutput -Filter '*.pdf').Count -ne 7){throw 'Se requieren los siete PDF Flutter reales'}
  $env:TRANSITO_FLUTTER_PDFS=$pdfOutput
  $env:PYTHONDONTWRITEBYTECODE='1'
  $config=@"
project_id = "$project"
[api]
enabled = true
port = 57521
schemas = ["public"]
extra_search_path = ["public", "extensions"]
[db]
port = 57522
shadow_port = 57520
major_version = 17
[db.seed]
enabled = false
[auth]
enabled = true
site_url = "http://127.0.0.1:3000"
enable_signup = false
[auth.email]
enable_signup = true
enable_confirmations = false
[studio]
enabled = false
[inbucket]
enabled = false
[storage]
enabled = true
[realtime]
enabled = false
[analytics]
enabled = false
[edge_runtime]
enabled = true
"@
  [IO.File]::WriteAllText((Join-Path $taskDir 'supabase/config.toml'),$config,[Text.UTF8Encoding]::new($false))
  Copy-Item -LiteralPath (Join-Path $repo 'supabase/migrations') -Destination (Join-Path $taskDir 'supabase/migrations') -Recurse
  Copy-Item -LiteralPath (Join-Path $repo 'supabase/functions') -Destination (Join-Path $taskDir 'supabase/functions') -Recurse
  $env:TRANSITO_EDGE_FIXTURES=Join-Path $taskDir 'fixtures.json'
  & $env:TRANSITO_TEST_PYTHON (Join-Path $PSScriptRoot 'create_edge_fixtures.py') $env:TRANSITO_EDGE_FIXTURES
  if($LASTEXITCODE -ne 0){throw 'Fixtures/oraculo no disponibles'}
  & npx --yes deno@2.9.6 test --allow-read --allow-env --config (Join-Path $repo 'supabase/functions/verificar-archivo/deno.json') (Join-Path $repo 'supabase/functions/verificar-archivo/binary_test.ts')
  if($LASTEXITCODE -ne 0){throw 'Tests TS/Deno fallaron'}
  $networkId=(& docker network create --opt com.docker.network.bridge.host_binding_ipv4=127.0.0.1 $project).Trim()
  if($LASTEXITCODE -ne 0){throw 'Red dedicada no creada'}
  & npx --yes supabase@2.122.0 --workdir $taskDir --network-id $project start --exclude realtime,imgproxy,mailpit,studio,logflare,vector,supavisor,postgres-meta *> (Join-Path $taskDir 'start.log')
  if($LASTEXITCODE -ne 0){throw 'Supabase local no arranco; ninguna prueba HTTP declarada exitosa'}
  # Node limita binds a localhost antes de generar usuarios y renueva los pools.
  & node (Join-Path $PSScriptRoot 'run_edge_http_tests.mjs') $taskDir
  if($LASTEXITCODE -ne 0){throw 'Pruebas HTTP fallaron'}
  & (Join-Path $PSScriptRoot 'edge_concurrency_regression.ps1') -Container ('supabase_db_'+$project)
  if($LASTEXITCODE -ne 0){throw 'Regresion concurrente fallo'}
  & npx --yes supabase@2.122.0 --workdir $taskDir db advisors --local --type security *> (Join-Path $taskDir 'advisors.log')
  if($LASTEXITCODE -ne 0){throw 'Advisors no ejecutados correctamente'}
  $advisorText=[IO.File]::ReadAllText((Join-Path $taskDir 'advisors.log'))
  if($advisorText -match 'No issues found'){Write-Output 'Advisors security: sin hallazgos'}
  else{
    Write-Output 'Advisors security: revisar hallazgos del esquema/fixtures locales'
    Write-Output ($advisorText -replace 'postgresql://[^"\s]+|eyJ[A-Za-z0-9_.-]{30,}|sb_secret_[A-Za-z0-9_-]+','[REDACTED]')
    throw 'Advisors requiere revision'
  }
} finally {
  $env:TRANSITO_FLUTTER_PDFS=$oldFlutterPdfs
  $env:PYTHONDONTWRITEBYTECODE=$oldPythonBytecode
  # project se genero aqui; solo contenedores con su etiqueta exacta son elegibles.
  $own=@(& docker ps -a --filter "label=com.supabase.cli.project=$project" --format '{{.Names}}')
  if($own.Count){
    if(@($own | Where-Object {$_ -notlike "supabase_*_$project"}).Count){throw 'Contenedor inesperado; limpieza detenida'}
    & npx --yes supabase@2.122.0 --workdir $taskDir stop --project-id $project --no-backup *> (Join-Path $taskDir 'stop.log')
    if($LASTEXITCODE -ne 0){throw 'No se pudo retirar stack dedicado; revisar sin tocar otros proyectos'}
  }
  if($networkId){
    $netRaw=& docker network inspect $project 2>$null
    if($LASTEXITCODE -eq 0){
      $net=($netRaw | ConvertFrom-Json)[0]
      if($net.Id -ne $networkId -or @($net.Containers.PSObject.Properties).Count){throw 'Red inesperada o no vacia'}
      & docker network rm $project | Out-Null
    }
  }
  $resolved=[IO.Path]::GetFullPath($taskDir)
  if(-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -ne ('transito-edge-'+$suffix)){throw 'Ruta temporal inesperada'}
  Remove-Item -LiteralPath $resolved -Recurse
}
