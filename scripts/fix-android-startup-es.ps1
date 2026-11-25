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
