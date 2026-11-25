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
$project = $project.Replace('<ApplicationId>MuMono.MuMono</ApplicationId>', '<ApplicationId>com.kabraonline.inicio07</ApplicationId>')
$project = $project.Replace('<ApplicationDisplayVersion>1.0</ApplicationDisplayVersion>', '<ApplicationDisplayVersion>0.7-louis31</ApplicationDisplayVersion>')
$project = $project.Replace('<ApplicationVersion>1</ApplicationVersion>', '<ApplicationVersion>7</ApplicationVersion>')
Set-Content $projectPath -Value $project -Encoding utf8
$manifest = Get-Content $manifestPath -Raw
$manifest = $manifest.Replace('package="MuMono.MuMono"', 'package="com.kabraonline.inicio07"')
$manifest = $manifest.Replace('android:label="MuMono"', 'android:label="MU KABRA ONLINE"')
Set-Content $manifestPath -Value $manifest -Encoding utf8
Write-Output "Configuracion de KABRA ONLINE aplicada. Endpoint no mostrado."
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


# Mark all loading screens as MU KABRA, regardless of map illustration.
$loadView = Join-Path $ClientDirectory 'Client.Main/Controls/UI/Loading/LoadingScreenView.cs'
if (!(Test-Path $loadView)) { throw "Missing LoadingScreenView.cs" }
$screenSource = Get-Content $loadView -Raw
$footer = '            DrawFooter(sb, screen, barY, ui);'
if (!$screenSource.Contains($footer)) { throw "Loading screen footer anchor missing" }
$brandedFooter = @'
            DrawFooter(sb, screen, barY, ui);
            string kabraHeading = "MU KABRA ONLINE";
            float headingWidth = OrnateDraw.Measure(kabraHeading, 34f).X;
            OrnateDraw.Text(sb, kabraHeading,
                new Vector2((screen.X - headingWidth) * 0.5f, 28f),
                34f, OrnateStyle.Gold, ui, bold: true);
'@
$screenSource = $screenSource.Replace($footer, $brandedFooter.TrimEnd())
Set-Content -Path $loadView -Value $screenSource -Encoding utf8
Write-Host 'Brand MU KABRA aplicado también a todas las pantallas de carga.'


# Capa de compatibilidad del transporte Louis 31, exclusivamente del GameServer.
# El ConnectServer conserva su protocolo estándar. No sustituye MHP/antihack.
$pipeSource = 'patches/KabraLouis31Pipe.cs'
$pipeDest = Join-Path $ClientDirectory 'Client.Main/Networking/KabraLouis31Pipe.cs'
if (!(Test-Path $pipeSource)) { throw "Falta la implementacion del transporte Louis31" }
Copy-Item -Path $pipeSource -Destination $pipeDest -Force

$cmPath = Join-Path $ClientDirectory 'Client.Main/Networking/ConnectionManager.cs'
$cm = Get-Content $cmPath -Raw
$oldPipe = 'IDuplexPipe transportPipe = newSocketConn;'
if (!$cm.Contains($oldPipe)) { throw 'No se encontró punto de conexión al transporte del GameServer' }
$cm = $cm.Replace($oldPipe, 'IDuplexPipe transportPipe = useEncryption ? new KabraLouis31Pipe(newSocketConn) : newSocketConn;')
# No mostrar servidor/IP/puerto en logs de cliente.
$cm = $cm.Replace('\"🔌 Already connected. Disconnect first before connecting to {Host}:{Port}.\", host, port',
                  '\"Ya existe una conexión al servidor.\"')
$cm = $cm.Replace('\"🔌 Attempting connection infrastructure setup for {Host}:{Port} (Encryption: {UseEncryption})...\", host, port, useEncryption',
                  '\"Preparando la conexión a MU KABRA ONLINE...\"')
$cm = $cm.Replace('\"✔️ Socket connected to {EndPoint}. Socket HashCode: {HashCode}\", endPoint, newSocketConn.GetHashCode()',
                  '\"Conexión TCP establecida con KABRA.\"')
$cm = $cm.Replace('\"❓ Failed to resolve IPv4 address for host: {Host}\", host',
                  '\"No se pudo encontrar el servidor KABRA.\"')
Set-Content -Path $cmPath -Value $cm -Encoding utf8

$nmPath = Join-Path $ClientDirectory 'Client.Main/Networking/NetworkManager.cs'
$nm = Get-Content $nmPath -Raw
$nm = $nm.Replace('OnErrorOccurred($"Connection to Connect Server {_settings.ConnectServerHost}:{_settings.ConnectServerPort} failed.");',
                  'OnErrorOccurred("No se pudo conectar a KABRA ONLINE. Revisá tu conexión.");')
$nm = $nm.Replace('OnErrorOccurred($"Connection to Game Server {host}:{port} failed.");',
                  'OnErrorOccurred("No se pudo conectar al servidor de juego KABRA.");')
$nm = $nm.Replace('"Connecting to Game Server {Host}:{Port}...", host, port',
                  '"Conectando al servidor de juego KABRA..."')
$nm = $nm.Replace('"Force reconnecting to Connect Server {Host}:{Port}", _settings.ConnectServerHost, _settings.ConnectServerPort',
                  '"Reconectando a KABRA ONLINE..."')
Set-Content -Path $nmPath -Value $nm -Encoding utf8
Write-Host 'Louis31: transporte de GameServer integrado. Los detalles de red no aparecen en los mensajes visibles.'


# Nombres de canales sin exponer direcciones, puertos o identificadores de infraestructura.
$serverListPath = Join-Path $ClientDirectory 'Client.Main/Controls/UI/Login/ServerList.cs'
$serversUi = Get-Content $serverListPath -Raw
$target = 'AddServer((byte)server.ServerId, server.ServerName ?? $"Server {server.ServerId}", gauge);'
if (!$serversUi.Contains($target)) { throw "No se encontró la presentación de servidores." }
$serversUi = $serversUi.Replace($target, @'
string channelName = server.ServerId switch
                {
                    9 => "KABRA PVP",
                    19 => "KABRA CASTLE",
                    _ => "KABRA ONLINE"
                };
                AddServer((byte)server.ServerId, channelName, gauge);
'@.TrimEnd())
$serversUi = $serversUi.Replace('const string title = "SELECT SERVER";', 'const string title = "SERVIDORES KABRA";')
Set-Content -Path $serverListPath -Value $serversUi -Encoding utf8
Write-Host 'Menu: canales KABRA PVP / KABRA CASTLE, sin direcciones visibles.'
