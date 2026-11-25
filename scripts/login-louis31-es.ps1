param([string]$ClientDirectory = "upstream")
$ErrorActionPreference = 'Stop'
function Patch([string]$path,[string]$old,[string]$new,[bool]$required=$true) {
  $file=Join-Path $ClientDirectory $path
  if (!(Test-Path $file)) { throw "Archivo faltante: $path" }
  $s=Get-Content $file -Raw
  if ($s.Contains($old)) {
    $s=$s.Replace($old,$new)
    Set-Content -Path $file -Value $s -Encoding utf8
  } elseif ($required) { throw "Texto esperado no encontrado en $path" }
}
# El cliente de OpenMU usa contraseña larga (60 bytes); los files Louis S6
# esperan el paquete S6 de contraseña corta (50 bytes).
Patch 'Client.Main/Networking/PacketHandling/PacketBuilder.cs' 'int length = LoginLongPassword.Length;' 'int length = LoginShortPassword.Length;'
Patch 'Client.Main/Networking/PacketHandling/PacketBuilder.cs' 'var packet = new LoginLongPassword(memory);' 'var packet = new LoginShortPassword(memory);'

Patch 'Client.Main/Networking/Services/LoginService.cs' "Sending login packet for user '{Username}'..." 'Enviando solicitud de acceso KABRA...' $false
Patch 'Client.Main/Networking/NetworkManager.cs' '"Sending login request for user: {Username}", username' '"Solicitando acceso a MU KABRA ONLINE"'
Patch 'Client.Main/Controls/UI/Login/LoginDialog.cs' 'Text = "User",' 'Text = "CUENTA",'
Patch 'Client.Main/Controls/UI/Login/LoginDialog.cs' 'Text = "Password",' 'Text = "CONTRASEÑA",'
Patch 'Client.Main/Controls/UI/Login/LoginDialog.cs' 'CreateClassicButton("CANCEL", ModernHudTheme.BgLight)' 'CreateClassicButton("VOLVER", ModernHudTheme.BgLight)'
Patch 'Client.Main/Controls/UI/Login/LoginDialog.cs' 'CreateClassicButton("OK", ModernHudTheme.Success)' 'CreateClassicButton("ENTRAR", ModernHudTheme.Success)'
Patch 'Client.Main/Scenes/LoginScene.cs' '_loginDialog.Visible = showLogin;' '_loginDialog.Visible = showLogin; _loginDialog.ServerName = "MU KABRA ONLINE | PVP";'
Patch 'Client.Main/Scenes/LoginScene.cs' 'MessageWindow.Show("Connection lost to the server.")' 'MessageWindow.Show("Conexión interrumpida. Verificá la conexión y volvé a ingresar a KABRA.")'
Patch 'Client.Main/Scenes/LoginScene.cs' 'mw.Text.Contains("Connection lost")' 'mw.Text.Contains("Conexión interrumpida")'
$statusSrc = 'if (_statusLabel != null) _statusLabel.Text = $"Status: {state}";'
$statusDst = @'
if (_statusLabel != null) _statusLabel.Text = state switch
                {
                    ClientConnectionState.ConnectingToConnectServer => "KABRA | Conectando...",
                    ClientConnectionState.ConnectedToConnectServer => "KABRA | Servidor disponible",
                    ClientConnectionState.RequestingServerList => "KABRA | Cargando servidores...",
                    ClientConnectionState.ReceivedServerList => "KABRA | Elegí tu servidor",
                    ClientConnectionState.RequestingConnectionInfo => "KABRA | Preparando partida...",
                    ClientConnectionState.ReceivedConnectionInfo => "KABRA | Preparando partida...",
                    ClientConnectionState.ConnectingToGameServer => "KABRA | Entrando al mundo...",
                    ClientConnectionState.ConnectedToGameServer => "KABRA | Ingresá tu cuenta",
                    ClientConnectionState.Authenticating => "KABRA | Verificando cuenta...",
                    ClientConnectionState.SelectingCharacter => "KABRA | Seleccioná tu personaje",
                    ClientConnectionState.Disconnected => "KABRA | Sin conexión",
                    _ => "MU KABRA ONLINE"
                };
'@
Patch 'Client.Main/Scenes/LoginScene.cs' $statusSrc $statusDst.TrimEnd()
Patch 'Client.Main/Scenes/LoginScene.cs' 'AddServer(i, $"Servers")' 'AddServer(i, "SERVIDORES")'
Patch 'Client.Main/Scenes/LoginScene.cs' 'AddServer(i, $"Events")' 'AddServer(i, "EVENTOS")'
Patch 'Client.Main/Controls/UI/Login/ServerList.cs' 'const string title = "SERVIDORES KABRA";' 'const string title = "ELEGÍ TU SERVIDOR";'
# No mostrar direcciones en los mensajes de consola que puedan aparecer en UI
$cmPath=Join-Path $ClientDirectory 'Client.Main/Networking/ConnectionManager.cs'
$cm=Get-Content $cmPath -Raw
$cm=$cm.Replace('"🔌 Attempting connection infrastructure setup for {Host}:{Port} (Encryption: {UseEncryption})...", host, port, useEncryption',
 '"Conectando a KABRA ONLINE..."')
$cm=$cm.Replace('"✔️ Socket connected to {EndPoint}. Socket HashCode: {HashCode}", endPoint, newSocketConn.GetHashCode()',
 '"Conexión con KABRA establecida."')
Set-Content -Path $cmPath -Value $cm -Encoding utf8
Write-Host 'KABRA: paquete de login corto, interfaz castellana, direcciones no visibles.'
