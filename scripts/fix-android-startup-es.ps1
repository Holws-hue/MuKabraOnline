param([string]$ClientDirectory = "upstream")
$ErrorActionPreference = 'Stop'
function Edit-Kabra([string]$rel,[string]$before,[string]$after) {
  $path=Join-Path $ClientDirectory $rel
  if (!(Test-Path $path)) { throw "No existe archivo requerido: $rel" }
  $src=Get-Content $path -Raw
  if (!$src.Contains($before)) { throw "No se encontró código esperado en $rel : $before" }
  $src=$src.Replace($before,$after)
  Set-Content -Path $path -Value $src -Encoding utf8
}

# Android era enviado siempre al editor Host/Port tras la carga.
Edit-Kabra 'Client.Main/Scenes/LoadScene.cs' 'nextSceneType = typeof(ServerConfigScene);' 'nextSceneType = typeof(LoginScene);'

# Al abrir la APK, la configuración de conexión integrada prevalece sobre
# posibles preferencias locales anteriores. No afecta a gráficos o controles.
$path=Join-Path $ClientDirectory 'Client.Main/MuGame.cs'
$src=Get-Content $path -Raw
$needle='AppSettings = AppConfiguration.GetSection("MuOnlineSettings").Get<MuOnlineSettings>();'
if (!$src.Contains($needle)) { throw 'No se encontró carga de configuración de MuGame.' }
$replacement=@'
AppSettings = AppConfiguration.GetSection("MuOnlineSettings").Get<MuOnlineSettings>();
            if (OperatingSystem.IsAndroid() && AppSettings != null)
            {
                var bundled = new ConfigurationBuilder()
                    .SetBasePath(ConfigDirectory)
                    .AddJsonFile(configFileName, optional: false, reloadOnChange: false)
                    .Build()
                    .GetSection("MuOnlineSettings");
                string kabraHost = bundled["ConnectServerHost"];
                string kabraPortText = bundled["ConnectServerPort"];
                if (string.IsNullOrWhiteSpace(kabraHost)
                    || !int.TryParse(kabraPortText, out int kabraPort)
                    || kabraPort < 1 || kabraPort > 65535)
                {
                    throw new InvalidOperationException("Configuración de KABRA inválida en APK");
                }
                AppSettings.ConnectServerHost = kabraHost;
                AppSettings.ConnectServerPort = kabraPort;
                string kabraClientVersion = bundled["ClientVersion"];
                string kabraClientSerial = bundled["ClientSerial"];
                if (string.IsNullOrWhiteSpace(kabraClientVersion)
                    || string.IsNullOrWhiteSpace(kabraClientSerial)
                    || kabraClientSerial.Length != 16)
                {
                    throw new InvalidOperationException("Versión o serial KABRA inválidos en APK");
                }
                // No aceptar credenciales de cliente desactualizadas guardadas localmente.
                AppSettings.ClientVersion = kabraClientVersion;
                AppSettings.ClientSerial = kabraClientSerial;
            }
'@
$src=$src.Replace($needle,$replacement.TrimEnd())
Set-Content -Path $path -Value $src -Encoding utf8

# Pantalla de carga y primer acceso en castellano
$loadPath=Join-Path $ClientDirectory 'Client.Main/Scenes/LoadScene.cs'
$load=Get-Content $loadPath -Raw
$replace=@{
  '"Initializing..."'='"Iniciando MU KABRA..."';
  'Title = "Game Data"'='Title = "Archivos de KABRA"';
  '"Extracting: {entry.Name}"'='"Preparando: {entry.Name}"';
  'Subtitle = "Preparing"'='Subtitle = "Preparando KABRA"';
  '"Assets found – skipping download."'='"Archivos encontrados. Iniciando KABRA..."';
  '"Connecting..."'='"Conectando a KABRA..."';
  '"Trying alternative source..."'='"Probando otra fuente de descarga..."';
  '"Extracting..."'='"Preparando archivos..."';
  '"Cleaning up..."'='"Terminando preparación..."';
  '$"Loading {nextSceneType.Name}..."'='"Cargando inicio de KABRA..."';
  '"Starting..."'='"Abriendo MU KABRA ONLINE..."';
  '"Downloading..."'='"Descargando archivos..."';
  '"Download complete!"'='"Descarga completada"';
  '"Extraction complete!"'='"Archivos preparados"';
}
foreach ($k in $replace.Keys) { $load=$load.Replace($k,$replace[$k]) }
Set-Content -Path $loadPath -Value $load -Encoding utf8
if ((Get-Content $loadPath -Raw).Contains('nextSceneType = typeof(ServerConfigScene);')) {
    throw 'Fallo: Android aún envía al menú de IP/Port.'
}
Write-Host 'KABRA OK: Android pasa al login sin pantalla IP/Port y muestra textos iniciales en español.'


# Preparar también la pantalla de elección de personajes en español.
$selectPath=Join-Path $ClientDirectory 'Client.Main/Scenes/SelectCharacterScene.cs'
$select=Get-Content $selectPath -Raw
$translations=@{
  '"Loading Characters..."'='"Cargando personajes..."';
  'new OrnateButtonControl("ENTER GAME"'='new OrnateButtonControl("ENTRAR AL MUNDO"';
  'new OrnateButtonControl("Back"'='new OrnateButtonControl("VOLVER"';
  '"Initializing Character Selection..."'='"Preparando selección de personajes..."';
  '"Select World Initialized."'='"Preparando los personajes de KABRA..."';
  '"Character Objects Ready."'='"Personajes preparados"';
  '"No characters found on this account."'='"No hay personajes en esta cuenta."';
  '"Error loading character selection."'='"Error al cargar los personajes"';
  '"Character Selection Ready."'='"Personajes disponibles"';
  '$"Entering game as {characterName}..."'='$"Entrando al mundo con {characterName}..."';
  '"Returning to login..."'='"Volviendo al inicio..."';
}
foreach ($key in $translations.Keys) { $select=$select.Replace($key,$translations[$key]) }
Set-Content -Path $selectPath -Value $select -Encoding utf8

$rosterPath=Join-Path $ClientDirectory 'Client.Main/Controls/UI/SelectCharacter/CharacterRosterWindow.cs'
$roster=Get-Content $rosterPath -Raw
$roster=$roster.Replace('Title = "CHARACTERS";','Title = "PERSONAJES";')
$roster=$roster.Replace('{MaxSlots} characters','{MaxSlots} personajes')
$roster=$roster.Replace('"Create Character"','"Crear personaje"')
$roster=$roster.Replace('"Delete"','"Eliminar"')
Set-Content -Path $rosterPath -Value $roster -Encoding utf8

Write-Host 'KABRA OK: personajes y controles de seleccion traducidos al español.'

# Red de seguridad: aunque otra ruta abra ServerConfigScene, Android salta al login.
$serverConfigPath=Join-Path $ClientDirectory 'Client.Main/Scenes/ServerConfigScene.cs'
$serverConfig=Get-Content $serverConfigPath -Raw
$updateAnchor='        public override void Update(GameTime gameTime)'
if (!$serverConfig.Contains($updateAnchor)) { throw 'No se encontró punto de protección de ServerConfigScene.' }
$androidGuard=@'
        public override void AfterLoad()
        {
            base.AfterLoad();
            if (OperatingSystem.IsAndroid())
            {
                MuGame.ScheduleOnMainThread(() => MuGame.Instance.ChangeScene(new LoginScene()));
            }
        }

'@
$serverConfig=$serverConfig.Replace($updateAnchor,$androidGuard+$updateAnchor)
Set-Content -Path $serverConfigPath -Value $serverConfig -Encoding utf8

# No avanzar a una escena rota si no se pudieron cargar los recursos del juego.
$load=Get-Content $loadPath -Raw
$oldStatus='UpdateProgress(p => p.StatusText = $"Error: {ex.Message}");'
$oldTransition='await TransitionToNextSceneAsync(CancellationToken.None);'
if (!$load.Contains($oldStatus) -or !$load.Contains($oldTransition)) {
    throw 'Cambió el manejador de errores de LoadScene; revisar antes de aplicar.'
}
$load=$load.Replace($oldStatus, 'UpdateProgress(p => p.StatusText = "Error al preparar KABRA. Revisá la conexión y reiniciá la aplicación.");')
$load=$load.Replace($oldTransition, 'return;')
Set-Content -Path $loadPath -Value $load -Encoding utf8

# Corregir también textos persistentes del módulo de carga y consejos.
$tipPath=Join-Path $ClientDirectory 'Client.Main/Controls/UI/Loading/LoadingScreenView.cs'
$tip=Get-Content $tipPath -Raw
if (!$tip.Contains('"TIP"')) { throw 'No se encontró etiqueta TIP.' }
$tip=$tip.Replace('"TIP"','"CONSEJO"')
Set-Content -Path $tipPath -Value $tip -Encoding utf8
$loadingControlPath=Join-Path $ClientDirectory 'Client.Main/Controls/UI/LoadingScreenControl.cs'
$loadingControl=Get-Content $loadingControlPath -Raw
$loadingControl=$loadingControl.Replace('"Loading..."','"Cargando..."')
Set-Content -Path $loadingControlPath -Value $loadingControl -Encoding utf8
Write-Host 'KABRA v06: acceso directo reforzado, error de carga visible y consejos en español.'

# KABRA v07 - Unico grupo de servidor; ID 9 KABRA PVP, sin EVENT
$loginFile=Join-Path $ClientDirectory 'Client.Main/Scenes/LoginScene.cs'
$loginSource=Get-Content $loginFile -Raw
$patches = @(
    @('Controls.Add(_eventGroup);','// KABRA: no se agrega el grupo EVENT a la interfaz'),
    @('_nonEventGroup.AddServer(i, "SERVIDORES");','_nonEventGroup.AddServer(i, "SERVIDOR");'),
    @('_nonEventGroup.Margin = new Margin { Left = -groupOffset };','_nonEventGroup.Margin = new Margin { Left = 0 };'),
    @('_serverList.AddServer((byte)server.ServerId, $"Server {server.ServerId}", server.LoadPercentage);','if (server.ServerId == 9) _serverList.AddServer((byte)server.ServerId, "KABRA PVP", server.LoadPercentage);'),
    @('"No se pudo iniciar sesión. Comprobá usuario, contraseña y versión del cliente."','$"KABRA: acceso rechazado (código {(byte)reason}). Revisá los datos o comunicate con soporte."'),
    @('MuGame.ScheduleOnMainThread(() => MuGame.Instance.Exit());','MuGame.ScheduleOnMainThread(() => { _ = _networkManager.ForceReconnectToConnectServerAsync(); });')
)
foreach ($pair in $patches) {
    if (!$loginSource.Contains($pair[0])) { throw "No se encontró código KABRA v07: $($pair[0])" }
    $loginSource=$loginSource.Replace($pair[0],$pair[1])
}
Set-Content -Path $loginFile -Value $loginSource -Encoding utf8
$serverListFile=Join-Path $ClientDirectory 'Client.Main/Controls/UI/Login/ServerList.cs'
$serverListSrc=Get-Content $serverListFile -Raw
$serverAnchor = 'var server = servers[i];'
if (!$serverListSrc.Contains($serverAnchor)) { throw 'No se encontró lista de servidores de KABRA' }
$serverListSrc=$serverListSrc.Replace($serverAnchor,$serverAnchor+[Environment]::NewLine+'                if (server.ServerId != 9) continue;')
Set-Content -Path $serverListFile -Value $serverListSrc -Encoding utf8
if ([string]::IsNullOrWhiteSpace($env:KABRA_CLIENT_SERIAL)) {
    Write-Warning 'La compilación CI requiere el ClientSerial original de MainInfo para autenticarse. No se publica en GitHub.'
}
elseif ($env:KABRA_CLIENT_SERIAL.Length -ne 16) {
    throw 'ClientSerial privado inválido: requiere 16 caracteres.'
}
Write-Host 'KABRA v07: grupo SERVIDOR único, PVP code 9, mensaje con código de error del servidor.'

# KABRA v10: legibilidad de rechazo; no se falsifica el resultado del servidor.
$loginPath = Join-Path $ClientDirectory 'Client.Main/Scenes/LoginScene.cs'
$login = Get-Content $loginPath -Raw
$gold=@'
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
if (!$login.Contains($gold)) { throw 'Falta etiqueta dorada del login: revisar upstream antes de cambiarla' }
$login=$login.Replace($gold,'')
$login=$login.Replace('TextColor = Color.Yellow,','TextColor = Color.LightGray,')
$login=$login.Replace('_statusLabel.TextColor = Color.Yellow;','_statusLabel.TextColor = Color.LightGray;')
$oldError=@'
                if (_statusLabel != null) _statusLabel.Text = "KABRA | Acceso rechazado";

                string messageToShow = reason == LoginResponse.LoginResult.AccountAlreadyConnected
                    ? "La cuenta ya está conectada."
                    : $"KABRA: acceso rechazado (código {(byte)reason}). Revisá los datos o comunicate con soporte.";
                MessageWindow.Show(messageToShow);
'@
$newError=@'
                byte rawCode = (byte)reason;
                if (_statusLabel != null)
                {
                    _statusLabel.Text = $"CODIGO {rawCode:D3}";
                    _statusLabel.FontSize = 22;
                    _statusLabel.TextColor = Color.White;
                }
                string detail = rawCode switch
                {
                    0 => "Contrasena incorrecta",
                    2 => "Cuenta no valida",
                    3 => "Cuenta ya conectada",
                    4 => "Servidor lleno",
                    5 => "Cuenta bloqueada",
                    6 => "Version rechazada",
                    7 => "Error de conexion",
                    8 => "Demasiados intentos",
                    14 => "Bloqueo temporal",
                    _ => "Rechazo del servidor"
                };
                // Formato corto para moviles: el codigo no queda fuera de pantalla.
                MessageWindow.Show($"CODIGO {rawCode:D3}: {detail}");
                _logger.LogWarning("Codigo de login Louis31: {Code} ({Reason})", rawCode, reason);
'@
# Localizar por marcas, sin depender de CRLF/LF entre líneas.
$startMark='                if (_statusLabel != null) _statusLabel.Text = "KABRA | Acceso rechazado";'
$endMark='                MessageWindow.Show(messageToShow);'
$start=$login.IndexOf($startMark,[StringComparison]::Ordinal)
$end=if($start -ge 0){$login.IndexOf($endMark,$start,[StringComparison]::Ordinal)}else{-1}
if($start -lt 0 -or $end -le $start){throw 'La rutina de error de login cambio; revisar codigo'}
$login=$login.Substring(0,$start)+$newError.TrimEnd()+$login.Substring($end+$endMark.Length)
Set-Content -Path $loginPath -Value $login -Encoding utf8

# KABRA v10: vista simple, sin titulo dorado, circulo, barra ni pie.
$viewPath=Join-Path $ClientDirectory 'Client.Main/Controls/UI/Loading/LoadingScreenView.cs'
$view=Get-Content $viewPath -Raw
$drawStart=$view.IndexOf('            DrawTitle(sb, barY, ui);',[StringComparison]::Ordinal)
$drawEnd=$view.IndexOf('            if (intro < 1f)',$drawStart,[StringComparison]::Ordinal)
if ($drawStart -lt 0 -or $drawEnd -le $drawStart) { throw 'Cambió la vista de carga. No aplicar reemplazo a ciegas.' }
$view=$view.Substring(0,$drawStart)+'            DrawKabraSimpleLoading(sb, screen, ui);'+[Environment]::NewLine+[Environment]::NewLine+$view.Substring($drawEnd)
$anchor='        private void DrawTitle(SpriteBatch sb, int barY, float a)'
if (!$view.Contains($anchor)) { throw 'No existe DrawTitle para insertar el titulo simple' }
$simple=@'
        private void DrawKabraSimpleLoading(SpriteBatch sb, Point screen, float opacity)
        {
            const string text = "Cargando";
            const float fontSize = 18f;
            float width = OrnateDraw.Measure(text, fontSize).X;
            OrnateDraw.Text(sb, text, new Vector2((screen.X - width) * 0.5f, screen.Y - 50),
                fontSize, OrnateStyle.TextLight, opacity);
        }

'@
$view=$view.Replace($anchor,$simple+$anchor)
Set-Content -Path $viewPath -Value $view -Encoding utf8

# Los textos de presentación amarillos no deben cubrir el logo original.
$dialogPath=Join-Path $ClientDirectory 'Client.Main/Controls/UI/Login/LoginDialog.cs'
$dialog=Get-Content $dialogPath -Raw
if(!$dialog.Contains('Text = "MU KABRA ONLINE",')) { throw 'No se encontró titulo del login' }
$dialog=$dialog.Replace('Text = "MU KABRA ONLINE",','Text = "INICIAR SESION",')
Set-Content -Path $dialogPath -Value $dialog -Encoding utf8
$logoClass=Join-Path $ClientDirectory 'Client.Main/Controls/UI/Login/MuLogo.cs'
$logo=Get-Content $logoClass -Raw
if($logo.Contains('Text = "MU KABRA ONLINE",')){
    $logo=$logo.Replace('Text = "MU KABRA ONLINE",','Text = "",')
    Set-Content -Path $logoClass -Value $logo -Encoding utf8
}

Write-Host 'KABRA v10: errores legibles y carga simplificada, sin texto dorado ni barras.'
