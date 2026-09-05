$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
$originalConfig = $null
try {
    # Flutter 3.47 retains the generated registrant URI in AOT. Give that
    # generated directory a package URI so no workstation path enters the APK.
    # This is a compiler mapping, not a dependency or a source-code change.
    $configPath = Join-Path (Get-Location) '.dart_tool/package_config.json'
    $originalConfig = [IO.File]::ReadAllBytes($configPath)
    $config = [Text.Encoding]::UTF8.GetString($originalConfig) | ConvertFrom-Json
    if ($config.packages.name -contains 'transito_generated') {
        throw 'Unexpected existing transito_generated package mapping.'
    }
    $config.packages += [pscustomobject]@{
        name = 'transito_generated'
        rootUri = 'flutter_build/'
        packageUri = './'
        languageVersion = '3.0'
    }
    [IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 20))
    flutter build apk --release --no-pub --build-name=1.0.0 --build-number=1 --obfuscate --split-debug-info=.release-private/symbols/1.0.0+1
    if ($LASTEXITCODE -ne 0) { throw 'APK release fallo' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $apk = [IO.Compression.ZipFile]::OpenRead(
        (Join-Path (Get-Location) 'build/app/outputs/flutter-apk/app-release.apk'))
    try {
        foreach ($entry in $apk.Entries) {
            if ($entry.FullName -notmatch 'libapp.so$') { continue }
            $stream = $entry.Open()
            $buffer = [IO.MemoryStream]::new()
            try {
                $stream.CopyTo($buffer)
                $binaryText = [Text.Encoding]::UTF8.GetString($buffer.ToArray())
                if ($binaryText -match 'file:///[A-Za-z]:/|file:///Users/|file:///home/' -or
                    $binaryText.Contains('.debug_info')) {
                    throw 'APK contiene rutas locales o simbolos. Repetir desde flutter clean.'
                }
            } finally {
                $stream.Dispose()
                $buffer.Dispose()
            }
        }
    } finally {
        $apk.Dispose()
    }
    Get-FileHash 'build/app/outputs/flutter-apk/app-release.apk' -Algorithm SHA256
} finally {
    if ($null -ne $originalConfig) {
        [IO.File]::WriteAllBytes($configPath, $originalConfig)
    }
    Pop-Location
}
