$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    if (!(Test-Path 'android/key.properties')) {
        throw 'Configure android/key.properties con el keystore release privado.'
    }
    flutter clean
    if ($LASTEXITCODE -ne 0) { throw 'flutter clean fallo' }
    flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) {
        throw 'pub get fallo. En Windows habilite soporte de symlinks (Modo desarrollador).'
    }
    dart format .
    if ($LASTEXITCODE -ne 0) { throw 'dart format fallo' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze fallo' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test fallo' }
    & (Join-Path $PSScriptRoot 'package_release.ps1')
} finally {
    Pop-Location
}
