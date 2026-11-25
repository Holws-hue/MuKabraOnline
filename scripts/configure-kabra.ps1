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
