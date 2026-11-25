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
$oldError=@'
                UpdateProgress(p => p.StatusText = $"Error: {ex.Message}");
                await Task.Delay(5000, CancellationToken.None);
                await TransitionToNextSceneAsync(CancellationToken.None);
'@
$newError=@'
                UpdateProgress(p =>
                {
                    p.StatusText = "No se pudieron preparar los archivos de KABRA. Revisá la conexión y reiniciá.";
                    p.IsDownloading = false;
                });
                return;
'@
if (!$load.Contains($oldError.Trim())) { throw 'Cambió el manejador de errores de LoadScene; revisar antes de aplicar.' }
$load=$load.Replace($oldError.Trim(),$newError.Trim())
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
