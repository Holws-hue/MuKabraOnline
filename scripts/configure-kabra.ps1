param(
  [string]$ClientDirectory = "upstream"
)
$ErrorActionPreference = 'Stop'
$settingsPath = Join-Path $ClientDirectory 'Client.Main/appsettings.json'
$projectPath = Join-Path $ClientDirectory 'MuAndroid/MuAndroid.csproj'
$manifestPath = Join-Path $ClientDirectory 'MuAndroid/AndroidManifest.xml'
if (!(Test-Path $settingsPath)) { throw "No se encuentra appsettings.json de MonoGame" }
if (!(Test-Path $projectPath)) { throw "No se encuentra MuAndroid.csproj" }

$cfg = Get-Content $settingsPath -Raw | ConvertFrom-Json
$hostname = if ($env:KABRA_CONNECT_HOST) { $env:KABRA_CONNECT_HOST } else { '523.ddns.net' }
[int]$port = if ($env:KABRA_CONNECT_PORT) { $env:KABRA_CONNECT_PORT } else { 44405 }
if ($port -lt 1 -or $port -gt 65535) { throw "Puerto de ConnectServer invalido" }
$cfg.MuOnlineSettings.ConnectServerHost = $hostname
$cfg.MuOnlineSettings.ConnectServerPort = $port
# No inventar ClientVersion ni ClientSerial: son específicos de Louis 31.
if (![string]::IsNullOrWhiteSpace($env:KABRA_CLIENT_VERSION)) {
  $cfg.MuOnlineSettings.ClientVersion = $env:KABRA_CLIENT_VERSION
}
if (![string]::IsNullOrWhiteSpace($env:KABRA_CLIENT_SERIAL)) {
  $cfg.MuOnlineSettings.ClientSerial = $env:KABRA_CLIENT_SERIAL
}
$cfg | ConvertTo-Json -Depth 100 | Set-Content -Path $settingsPath -Encoding utf8

$project = Get-Content $projectPath -Raw
$project = $project.Replace('<ApplicationId>MuMono.MuMono</ApplicationId>', '<ApplicationId>com.kabraonline.nativepreview</ApplicationId>')
$project = $project.Replace('<ApplicationDisplayVersion>1.0</ApplicationDisplayVersion>', '<ApplicationDisplayVersion>0.1-preview</ApplicationDisplayVersion>')
Set-Content $projectPath -Value $project -Encoding utf8
$manifest = Get-Content $manifestPath -Raw
$manifest = $manifest.Replace('package="MuMono.MuMono"', 'package="com.kabraonline.nativepreview"')
$manifest = $manifest.Replace('android:label="MuMono"', 'android:label="KABRA ONLINE Preview"')
Set-Content $manifestPath -Value $manifest -Encoding utf8
Write-Output "Preparada configuracion de compilacion. Endpoint ConnectServer: ${hostname}:${port}."
Write-Output "NOTA: esta preparacion no verifica la conectividad ni el protocolo Louis 31."

# Parche Android: MonoGame Android no contiene Graphics.OcclusionQuery
$profilerPath = Join-Path $ClientDirectory 'Client.Main/Controllers/RenderPassProfiler.cs'
if (!(Test-Path $profilerPath)) { throw "No se encuentra RenderPassProfiler.cs" }
$profiler = Get-Content $profilerPath -Raw
$startToken = '    private static Microsoft.Xna.Framework.Graphics.OcclusionQuery _gpuFence;'
$endToken = '    public static PassToken Start()'
$startAt = $profiler.IndexOf($startToken, [StringComparison]::Ordinal)
$endAt = if ($startAt -ge 0) { $profiler.IndexOf($endToken, $startAt, [StringComparison]::Ordinal) } else { -1 }
if ($startAt -lt 0 -or $endAt -lt $startAt) {
  throw "No es posible localizar el bloque de GPU diagnostics: cambiar revision del motor antes de continuar"
}
$replacement = @'
#if ANDROID
    // El depurador de GPU no está soportado por MonoGame Android.
    public static double GpuFenceTimeoutCount;
    public static void WaitForGpu() { }
#else
'@
$replacement += "`n"
$replacement += $profiler.Substring($startAt, $endAt - $startAt)
$replacement += "`n#endif`n`n"
$profiler = $profiler.Substring(0, $startAt) + $replacement + $profiler.Substring($endAt)
Set-Content -Path $profilerPath -Value $profiler -Encoding utf8
Write-Output 'GPU profiler parcheado: diagnostico de sincronizacion omitido en Android.'
