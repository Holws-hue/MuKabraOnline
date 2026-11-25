param([string]$ClientDirectory='upstream')
$ErrorActionPreference = 'Stop'
$loadFile=Join-Path $ClientDirectory 'Client.Main/Scenes/LoadScene.cs'
$loginFile=Join-Path $ClientDirectory 'Client.Main/Scenes/LoginScene.cs'
$baseFile=Join-Path $ClientDirectory 'Client.Main/Scenes/BaseScene.cs'
$load=Get-Content $loadFile -Raw
$login=Get-Content $loginFile -Raw
$base=Get-Content $baseFile -Raw

# Permitimos probar la autenticación ANTES de descargar 1.7 GB.
$flag='        private static bool IsAndroid => OperatingSystem.IsAndroid();'
if (!$load.Contains($flag)) { throw 'No se encontro la marca de Android en LoadScene' }
$flagAdd=@'
        public static bool DownloadAfterLogin { get; set; }
        public static bool HasCompleteKabraAssets()
        {
            return File.Exists(Path.Combine(Constants.DataPath, ".kabra-assets-complete"))
                && !File.Exists(Path.Combine(Constants.DataPath, ".kabra-assets-installing"))
                && File.Exists(Path.Combine(Constants.DataPath, "Gate.bmd"))
                && Directory.Exists(Constants.DataPath)
                && Directory.EnumerateDirectories(Constants.DataPath, "World*", SearchOption.TopDirectoryOnly).Any();
        }
'@
$load=$load.Replace($flag,$flag+[Environment]::NewLine+$flagAdd)
$anchor='                EnsureDirectoryExists(extractPath);'
if(!$load.Contains($anchor)){throw 'No se encontro ruta de inicializacion de datos'}
$beforeDownload=@'
                // KABRA: comprobar las credenciales ANTES de descargar 1.7 GB.
                if (IsAndroid && !CheckAssetsExist(extractPath) && !DownloadAfterLogin)
                {
                    UpdateProgress(p => { p.StatusText = "Conectando al servidor..."; p.Progress = 1f; p.IsDownloading = false; });
                    await TransitionToNextSceneAsync(ct);
                    return;
                }
'@
$load=$load.Replace($anchor,$anchor+[Environment]::NewLine+$beforeDownload)
$afterDownload='                await SkillDatabase.Initialize();'
if(!$load.Contains($afterDownload)){throw 'No se encontro final de carga de datos'}
$load=$load.Replace($afterDownload,$afterDownload+[Environment]::NewLine+'                DownloadAfterLogin = false;')
Set-Content $loadFile -Value $load -Encoding utf8

# LoginScene usa un mundo 3D de gran tamaño en la pantalla de entrada. Si todavía
# faltan datos, usar controles 2D para login sin modelos, mapas ni música de Data.
$worldStart='            World?.Dispose();'
$worldEnd='            progressCallback?.Invoke("Login World Loaded.", 0.70f);'
$p1=$login.IndexOf($worldStart,[StringComparison]::Ordinal)
$p2=if($p1 -ge 0){$login.IndexOf($worldEnd,$p1,[StringComparison]::Ordinal)}else{-1}
if($p1 -lt 0 -or $p2 -le $p1){throw 'No se encontro inicializacion del mundo LoginScene'}
$worldBlock=$login.Substring($p1,($p2+$worldEnd.Length)-$p1)
$wrapper=@'
            bool kabraLiteLogin = OperatingSystem.IsAndroid() && !LoadScene.HasCompleteKabraAssets();
            if (kabraLiteLogin)
            {
                progressCallback?.Invoke("Login KABRA listo (sin descarga de archivos).", 0.70f);
            }
            else
            {
'@
$login=$login.Substring(0,$p1)+$wrapper+$worldBlock+[Environment]::NewLine+'            }'+$login.Substring($p2+$worldEnd.Length)
$music='            SoundController.Instance.PlayBackgroundMusic("Music/login_theme.mp3");'
if(!$login.Contains($music)){throw 'No se encontro música del login'}
$login=$login.Replace($music,'            if (!kabraLiteLogin) SoundController.Instance.PlayBackgroundMusic("Music/login_theme.mp3");')
# Si el servidor ACEPTÓ credenciales, recién ahí iniciar el instalador y reanudar.
$characterList='                if (characters != null)'
$successBranch=@'
                if (OperatingSystem.IsAndroid() && !LoadScene.HasCompleteKabraAssets())
                {
                    LoadScene.DownloadAfterLogin = true;
                    MessageWindow.Show("Inicio de sesion aceptado. Descargando archivos de KABRA. Podras reanudar si se corta Internet.");
                    _ = _networkManager.ForceReconnectToConnectServerAsync();
                    MuGame.Instance.ChangeScene(new LoadScene());
                    return;
                }
'@
if (!$login.Contains($characterList)){throw 'No se encontro lista de personajes'}
$login=$login.Replace($characterList,$successBranch+$characterList)
Set-Content $loginFile -Value $login -Encoding utf8

# BaseScene sin mundo debe renderizar igualmente UI 2D (botones de login).
$drawOld=@'
        public override void Draw(GameTime gameTime)
        {
            if (World == null)
                return;
'@
$drawNew=@'
        public override void Draw(GameTime gameTime)
        {
            if (World == null)
            {
                GraphicsDevice.Clear(new Color(12, 9, 24));
                if (DeferInterface) _interfacePending = true;
                else DrawInterface(gameTime);
                return;
            }
'@
if (!$base.Contains($drawOld.TrimEnd())) { throw 'No se encontro soporte de Draw sin mundo' }
$base=$base.Replace($drawOld.TrimEnd(),$drawNew.TrimEnd())
Set-Content $baseFile -Value $base -Encoding utf8

Write-Host 'KABRA v14: iniciar sesion primero sin descargar datos, y descargar despues de login OK; UI 2D sin mundo.'
