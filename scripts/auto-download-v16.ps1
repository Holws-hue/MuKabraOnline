param([string]$ClientDirectory='upstream')
$ErrorActionPreference = 'Stop'
$loadFile=Join-Path $ClientDirectory 'Client.Main/Scenes/LoadScene.cs'
$source=Get-Content $loadFile -Raw

function Replace-Kabra([string]$old, [string]$new,[string]$label){
 if(!$script:source.Contains($old)){throw "KABRA v16: falta $label"}
 $script:source=$script:source.Replace($old,$new)
}

# v14 arrancaba en el login 2D, por eso la v15 no descargaba automaticamente.
# Descarga al abrir Android, con salida opcional para probar el login.
Replace-Kabra 'public static bool DownloadAfterLogin { get; set; }' 'public static bool DownloadAfterLogin { get; set; } = OperatingSystem.IsAndroid();' 'auto-descarga'

$usingAnchor='using Client.Main.Controls.UI;'
Replace-Kabra $usingAnchor ($usingAnchor+[Environment]::NewLine+'using Client.Main.Controls.UI.Common;') 'controles'

$fields='        private LoadingScreenView _loadingView;'
Replace-Kabra $fields ($fields+[Environment]::NewLine+'        private ButtonControl _skipDownloadButton;'+[Environment]::NewLine+'        private ButtonControl _retryDownloadButton;') 'botones de carga'

$loadAnchor='            Controls.Add(_loadingView);'
$addButtons=@'
            if (IsAndroid)
            {
                _skipDownloadButton = new ButtonControl
                {
                    Text = "ENTRAR SIN DESCARGAR",
                    FontSize = 13f,
                    AutoViewSize = false,
                    ViewSize = new Point(285, 38),
                    Align = ControlAlign.Right | ControlAlign.Top,
                    BackgroundColor = new Color(36, 22, 58, 215),
                    HoverBackgroundColor = new Color(76, 50, 103, 230),
                    TextColor = Color.White,
                    Interactive = true,
                    Visible = !HasCompleteKabraAssets()
                };
                _skipDownloadButton.Click += (s, e) =>
                {
                    if (!_skipDownloadButton.Enabled) return;
                    _skipDownloadButton.Enabled = false;
                    DownloadAfterLogin = false;
                    _loadingCts.Cancel();
                    MuGame.ScheduleOnMainThread(
                        () => MuGame.Instance.ChangeScene(new LoginScene()));
                };
                Controls.Add(_skipDownloadButton);

                _retryDownloadButton = new ButtonControl
                {
                    Text = "REINTENTAR DESCARGA",
                    FontSize = 13f,
                    AutoViewSize = false,
                    ViewSize = new Point(285, 38),
                    Align = ControlAlign.Left | ControlAlign.Top,
                    BackgroundColor = new Color(62, 30, 76, 230),
                    HoverBackgroundColor = new Color(98, 50, 113, 240),
                    TextColor = Color.White,
                    Interactive = true,
                    Visible = false
                };
                _retryDownloadButton.Click += (s, e) =>
                {
                    if (!_retryDownloadButton.Enabled) return;
                    _retryDownloadButton.Enabled = false;
                    DownloadAfterLogin = true;
                    _loadingCts.Cancel();
                    MuGame.ScheduleOnMainThread(
                        () => MuGame.Instance.ChangeScene(new LoadScene()));
                };
                Controls.Add(_retryDownloadButton);
            }
'@
Replace-Kabra $loadAnchor ($loadAnchor+[Environment]::NewLine+$addButtons) 'botones de descarga'

# Si hay error HTTP, mantenerlo en la pantalla y dejar reintentar sin borrar el parcial.
$failure='UpdateProgress(p => { p.IsDownloading = false; p.StatusText = $"Error de descarga: {ex.Message}"; });'
if(!$source.Contains($failure)){throw 'KABRA: manejador de error de carga cambiado'}
$source=$source.Replace($failure,$failure+[Environment]::NewLine+@'
                if (IsAndroid)
                    MuGame.ScheduleOnMainThread(() =>
                    {
                        if (_retryDownloadButton != null)
                        {
                            _retryDownloadButton.Enabled = true;
                            _retryDownloadButton.Visible = true;
                        }
                    });
'@)
Set-Content -Path $loadFile -Value $source -Encoding utf8
Write-Host 'KABRA v16: descarga automatica al abrir, login sin descarga y reintento manual conservando ZIP.'
