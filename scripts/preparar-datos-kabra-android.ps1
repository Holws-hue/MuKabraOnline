param(
    [Parameter(Mandatory=$true)][string]$ClientDataDirectory,
    [string]$OutputZip = (Join-Path (Get-Location).Path 'KABRA_ANDROID_DATA.zip')
)
$ErrorActionPreference = 'Stop'

# Empaquetar la carpeta Data del CLIENTE KABRA S6 (no GameServer/Data ni la raiz del cliente).
$dir = (Resolve-Path -LiteralPath $ClientDataDirectory).Path
$gate = Join-Path $dir 'Gate.bmd'
$maps = @(Get-ChildItem -LiteralPath $dir -Directory | Where-Object { $_.Name -match '^World\d+$' })
if (!(Test-Path -LiteralPath $gate) -or $maps.Count -eq 0) {
    throw 'Faltan Gate.bmd y directorios World*; el origen debe ser el Data del CLIENTE MU KABRA.'
}

$dest = [IO.Path]::GetFullPath($OutputZip)
if (Test-Path -LiteralPath $dest) { throw "Ya existe $dest; elegi otro nombre para no sobrescribir." }
$parent = Split-Path -Path $dest -Parent
if (!(Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

Add-Type -AssemblyName System.IO.Compression
[System.IO.Compression.ZipFile]::CreateFromDirectory(
  $dir, $dest, [System.IO.Compression.CompressionLevel]::Optimal, $false)

$archive = [System.IO.Compression.ZipFile]::OpenRead($dest)
try {
    $entries = @($archive.Entries)
    if (!($entries | Where-Object { $_.FullName -ieq 'Gate.bmd' })) { throw 'Gate.bmd ausente del ZIP generado' }
    if (!($entries | Where-Object { $_.FullName -match '^World\d+/' })) { throw 'Mapas ausentes del ZIP generado' }
    $count = $entries.Count
    $expanded = ($entries | Measure-Object Length -Sum).Sum
} finally { $archive.Dispose() }

$hash = Get-FileHash -LiteralPath $dest -Algorithm SHA256
$mb = [Math]::Round((Get-Item -LiteralPath $dest).Length / 1MB, 1)
Write-Host "OK: $dest"
Write-Host "Archivos: $count | ZIP: $mb MiB | Datos descomprimidos: $([Math]::Round($expanded/1MB,1)) MiB"
Write-Host "SHA256: $($hash.Hash)"
Write-Host 'Subi este ZIP a un hosting HTTPS que soporte descargas Range (HTTP 206).'
Write-Host 'Luego configura la variable GitHub Actions KABRA_ASSETS_ZIP_URL con el enlace DIRECTO al archivo.'
Write-Host 'No uses un enlace de vista previa o landing de MediaFire; debe devolver bytes ZIP.'
