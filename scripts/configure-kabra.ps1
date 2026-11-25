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
$project = $project.Replace('<ApplicationId>MuMono.MuMono</ApplicationId>', '<ApplicationId>com.kabraonline.mobilepreview</ApplicationId>')
$project = $project.Replace('<ApplicationDisplayVersion>1.0</ApplicationDisplayVersion>', '<ApplicationDisplayVersion>0.2-kabra</ApplicationDisplayVersion>')
Set-Content $projectPath -Value $project -Encoding utf8
$manifest = Get-Content $manifestPath -Raw
$manifest = $manifest.Replace('package="MuMono.MuMono"', 'package="com.kabraonline.mobilepreview"')
$manifest = $manifest.Replace('android:label="MuMono"', 'android:label="MU KABRA ONLINE"')
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


# Identidad visible de MU KABRA (sin cambiar el motor ni el protocolo)
$strings = Join-Path $ClientDirectory 'MuAndroid/Resources/Values/Strings.xml'
if (!(Test-Path $strings)) { throw "Missing Android Strings.xml" }
$str = Get-Content $strings -Raw
$str = $str.Replace('<string name="app_name">MuMono</string>', '<string name="app_name">MU KABRA ONLINE</string>')
Set-Content -Path $strings -Value $str -Encoding utf8

$loginDialog = Join-Path $ClientDirectory 'Client.Main/Controls/UI/Login/LoginDialog.cs'
if (!(Test-Path $loginDialog)) { throw "Missing LoginDialog.cs" }
$login = Get-Content $loginDialog -Raw
$login = $login.Replace('Text = "MU Online",', 'Text = "MU KABRA ONLINE",')
$login = $login.Replace('Text = "OpenMU Server 1",', 'Text = "KABRA ONLINE | PVP",')
Set-Content $loginDialog -Value $login -Encoding utf8

# Put a fixed KABRA brand header on top of the login world.
$loginScene = Join-Path $ClientDirectory 'Client.Main/Scenes/LoginScene.cs'
if (!(Test-Path $loginScene)) { throw "Missing LoginScene.cs" }
$ls = Get-Content $loginScene -Raw
$needle = '            Controls.Add(loginWorld);'
if (!$ls.Contains($needle)) { throw "Expected login world insertion not found" }
$replace = @'
            Controls.Add(loginWorld);
            Controls.Add(new LabelControl
            {
                Text = "MU KABRA ONLINE",
                Align = ControlAlign.HorizontalCenter,
                Y = 18,
                FontSize = 30,
                TextColor = new Color(249, 209, 119),
                Visible = true
            });
'@
$ls = $ls.Replace($needle,$replace.TrimEnd())
Set-Content $loginScene -Value $ls -Encoding utf8

$muLogo = Join-Path $ClientDirectory 'Client.Main/Controls/UI/Login/MuLogo.cs'
$logoSource = @'
using Client.Main.Models;
using Microsoft.Xna.Framework;
namespace Client.Main.Controls.UI.Login
{
    // Original engine-compatible public UI branding for KABRA.
    public class MuLogo : UIControl
    {
        public MuLogo()
        {
            Controls.Add(new LabelControl
            {
                Text = "MU KABRA ONLINE",
                Align = ControlAlign.HorizontalCenter,
                FontSize = 30,
                TextColor = new Color(252, 204, 115)
            });
        }
    }
}
'@
Set-Content $muLogo -Value $logoSource -Encoding utf8

Write-Output 'Identidad de KABRA aplicada a Android, login y logo UI.'
