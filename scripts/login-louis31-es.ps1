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

# Mensajes de error en español sin exponer infraestructura ni credenciales.
Patch 'Client.Main/Scenes/LoginScene.cs' 'MessageWindow.Show("Please enter Username and Password.");' 'MessageWindow.Show("Ingresá tu cuenta y contraseña.");'
Patch 'Client.Main/Scenes/LoginScene.cs' 'MessageWindow.Show($"Cannot login in state: {_networkManager.CurrentState}");' 'MessageWindow.Show("Todavía no hay conexión con el servidor KABRA.");'
Patch 'Client.Main/Scenes/LoginScene.cs' 'MessageWindow.Show("Error preparing character selection scene.");' 'MessageWindow.Show("No se pudo abrir la selección de personajes.");'
Patch 'Client.Main/Scenes/LoginScene.cs' 'MessageWindow.Show("Error receiving character list data.");' 'MessageWindow.Show("No se pudo recibir la lista de personajes.");'
Patch 'Client.Main/Scenes/LoginScene.cs' 'MessageWindow.Show($"Network Error: {errorMessage}");' 'MessageWindow.Show("Error de conexión con MU KABRA. Revisá la red o la configuración del cliente.");'
Patch 'Client.Main/Scenes/LoginScene.cs' '"Status: Logged In - Requesting Characters..."' '"KABRA | Cargando personajes..."'
Patch 'Client.Main/Scenes/LoginScene.cs' '"Status: Login Failed!"' '"KABRA | Acceso rechazado"'
Patch 'Client.Main/Scenes/LoginScene.cs' '"Account is already connected."' '"La cuenta ya está conectada."'
Patch 'Client.Main/Scenes/LoginScene.cs' '"Login Failed. Check credentials or server status."' '"No se pudo iniciar sesión. Comprobá usuario, contraseña y versión del cliente."'
Patch 'Client.Main/Scenes/LoginScene.cs' 'MessageWindow.Show(messageToShow);' 'MessageWindow.Show(messageToShow);'

# Bloquear doble envío mientras autentica para prevenir el antiflood de Louis.
Patch 'Client.Main/Scenes/LoginScene.cs' 'if (_networkManager.CurrentState == ClientConnectionState.ConnectedToGameServer ||' 'if (_networkManager.CurrentState == ClientConnectionState.ConnectedToGameServer &&'
Patch 'Client.Main/Scenes/LoginScene.cs' '                _networkManager.CurrentState == ClientConnectionState.Authenticating)' '                _networkManager.CurrentState != ClientConnectionState.Authenticating)'
# La segunda condición se vuelve tautológica pero mantiene el flujo y evita el segundo login.

# Las cuentas y contraseñas de la Season 6 usan 10 bytes ANSI.
$anchor='if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))'
$source=Join-Path $ClientDirectory 'Client.Main/Scenes/LoginScene.cs'
$src=Get-Content $source -Raw
$needle='                _logger.LogInformation("Login attempt from dialog for user: {Username}", username);'
$replacement=@'
                if (username.Length > 10 || password.Length > 10)
                {
                    MessageWindow.Show("Máximo 10 caracteres para la cuenta y la contraseña.");
                    return;
                }
                _logger.LogInformation("Solicitud de login KABRA recibida.");
'@
if (!$src.Contains($needle)) { throw 'No se encontró control de envío login' }
$src=$src.Replace($needle,$replacement.TrimEnd())
Set-Content -Path $source -Value $src -Encoding utf8
Write-Host 'Interfaz de login española, evita duplicados y datos sensibles visibles.'


# Si se desconecta antes de la selección, no cerrar MU de golpe.
# El jugador puede tocar Aceptar y reintentar sin automatizar ciclos infinitos.
$scenePath=Join-Path $ClientDirectory 'Client.Main/Scenes/LoginScene.cs'
$scene=Get-Content $scenePath -Raw
$exitCmd='MuGame.ScheduleOnMainThread(() => MuGame.Instance.Exit());'
if (($scene.Split($exitCmd).Count - 1) -ne 2) { throw 'Estructura de cierre por desconexión cambió; revisar antes de editar.' }
$first=$scene.IndexOf($exitCmd,[StringComparison]::Ordinal)
$scene=$scene.Substring(0,$first)+'MuGame.ScheduleOnMainThread(() => { _ = _networkManager.ForceReconnectToConnectServerAsync(); });'+$scene.Substring($first+$exitCmd.Length)
$scene=$scene.Replace('Closing game after connection lost message.', 'Reintentando al aceptar mensaje de conexión interrumpida.')
Set-Content -Path $scenePath -Value $scene -Encoding utf8
Write-Host 'Reconexión manual habilitada al aceptar el aviso; sin bucles de reintento.'

# v09: stackalloc NO garantiza bytes en cero. Ambos campos S6 de 10 bytes
# deben completarse con 0 antes del XOR3 para no alterar credenciales cortas.
$packetPath=Join-Path $ClientDirectory 'Client.Main/Networking/PacketHandling/PacketBuilder.cs'
$packetSrc=Get-Content $packetPath -Raw
$loginConstructor='var packet = new LoginShortPassword(memory);'
if (!$packetSrc.Contains($loginConstructor)) { throw 'No se encontró constructor LoginShortPassword' }
$packetSrc=$packetSrc.Replace($loginConstructor, 'memory.Span.Clear();'+[Environment]::NewLine+'            '+$loginConstructor)
$uSpan='Span<byte> userSpan = stackalloc byte[packet.Username.Length];'
$pSpan='Span<byte> passSpan = stackalloc byte[packet.Password.Length];'
if (!$packetSrc.Contains($uSpan) -or !$packetSrc.Contains($pSpan)) { throw 'No se encontraron campos de 10 bytes' }
$packetSrc=$packetSrc.Replace($uSpan,$uSpan+[Environment]::NewLine+'            userSpan.Clear();')
$packetSrc=$packetSrc.Replace($pSpan,$pSpan+[Environment]::NewLine+'            passSpan.Clear();')
Set-Content -Path $packetPath -Value $packetSrc -Encoding utf8

# Impedir un segundo envío si el primer login aún está autenticando.
$netPath=Join-Path $ClientDirectory 'Client.Main/Networking/NetworkManager.cs'
$netSrc=Get-Content $netPath -Raw
$oldGuard='if (_currentState != ClientConnectionState.ConnectedToGameServer && _currentState != ClientConnectionState.Authenticating)'
$newGuard='if (_currentState != ClientConnectionState.ConnectedToGameServer)'
if (!$netSrc.Contains($oldGuard)) { throw 'El estado de login de NetworkManager cambió' }
$netSrc=$netSrc.Replace($oldGuard,$newGuard)
# Un rechazo de credenciales no es un error de transporte: evita dos mensajes de error.
$oldFailure='OnErrorOccurred($"Login failed: {reasonString}");'
if (!$netSrc.Contains($oldFailure)) { throw 'No se encontró alerta duplicada del login' }
$netSrc=$netSrc.Replace($oldFailure,'// KABRA: el rechazo lo muestra LoginFailed con código exacto; sin duplicar NetworkError.')
Set-Content -Path $netPath -Value $netSrc -Encoding utf8
Write-Host 'KABRA v09: login normalizado, sin bytes residuales ni intentos duplicados.'

# v09: el Main.exe original envía Ping C3 0E 00 tras F1 00.
# Se observó en PCAP y se descifró con SimpleModulus + XOR32 estándar:
# transmite TickCount y velocidades 0/0 antes de elegir personaje.
$packetSrc=Get-Content $packetPath -Raw
$pingAnchor='        public static int BuildRequestCharacterListPacket('
if (!$packetSrc.Contains($pingAnchor)) { throw 'No se encontró punto para Ping S6' }
$pingCode=@'
        // Ping del protocolo MU S6: C3 0C 0E 00, TickCount LE, velocidades 0 hasta elegir personaje.
        public static int BuildKabraInitialPingPacket(IBufferWriter<byte> writer)
        {
            const int length = 12;
            var memory = writer.GetMemory(length).Slice(0, length);
            var span = memory.Span;
            span.Clear();
            span[0] = 0xC3;
            span[1] = length;
            span[2] = 0x0E;
            span[3] = 0x00;
            System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(
                span.Slice(4, 4), unchecked((uint)Environment.TickCount));
            return length;
        }

'@
$packetSrc=$packetSrc.Replace($pingAnchor,$pingCode+$pingAnchor)
Set-Content -Path $packetPath -Value $packetSrc -Encoding utf8

$netSrc=Get-Content $netPath -Raw
$readyAnchor='            UpdateState(ClientConnectionState.ConnectedToGameServer);'
# La primera ocurrencia está dentro de ProcessGameServerEntered, antes de login.
$index=$netSrc.IndexOf('internal void ProcessGameServerEntered()', [StringComparison]::Ordinal)
if ($index -lt 0) { throw 'Falta ProcessGameServerEntered' }
$ready=$netSrc.IndexOf($readyAnchor,$index,[StringComparison]::Ordinal)
if ($ready -lt 0) { throw 'Falta estado ConnectedToGameServer tras bienvenida' }
$netSrc=$netSrc.Substring(0,$ready)+'            _ = SendKabraInitialPingAsync();'+[Environment]::NewLine+$netSrc.Substring($ready)
$helperAnchor='        internal void ProcessLoginSuccess()'
if (!$netSrc.Contains($helperAnchor)) { throw 'Falta punto de insercion para Ping inicial' }
$helper=@'
        // Un solo Ping por conexión. No modifica credenciales ni controles del GameServer.
        private async Task SendKabraInitialPingAsync()
        {
            try
            {
                if (_connectionManager.IsConnected)
                {
                    await _connectionManager.Connection.SendAsync(
                        () => PacketBuilder.BuildKabraInitialPingPacket(_connectionManager.Connection.Output));
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudo enviar Ping inicial de KABRA.");
            }
        }

'@
$netSrc=$netSrc.Replace($helperAnchor,$helper+$helperAnchor)
Set-Content -Path $netPath -Value $netSrc -Encoding utf8
Write-Host 'KABRA: Ping inicial real del cliente Windows agregado con límite de un envío por conexion.'
