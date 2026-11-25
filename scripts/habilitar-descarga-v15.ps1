param([string]$ClientDirectory = 'upstream')
$ErrorActionPreference='Stop'
$loginFile = Join-Path $ClientDirectory 'Client.Main/Scenes/LoginScene.cs'
$login=Get-Content $loginFile -Raw

# Mantener dos posibilidades: probar el login sin bajar datos y descargar ahora mismo.
# La descarga nunca depende de que el servidor autorice el login.
$usingAnchor='using Client.Main.Controls.UI.Login;'
if (!$login.Contains($usingAnchor)) { throw 'LoginScene cambio namespace; revisar patch' }
$login=$login.Replace($usingAnchor,$usingAnchor+[Environment]::NewLine+'using Client.Main.Controls.UI.Common;')

$fieldAnchor='        private LoginDialog _loginDialog;'
if (!$login.Contains($fieldAnchor)) { throw 'No se encontro LoginDialog' }
$login=$login.Replace($fieldAnchor,$fieldAnchor+[Environment]::NewLine+'        private ButtonControl _kabraDownloadButton;')

# Agregar boton al nivel raíz: se puede pulsar antes de elegir servidor o cuenta.
$afterDialog='            Controls.Add(_loginDialog);'
if (!$login.Contains($afterDialog)) { throw 'No se encontro el formulario de login' }
$button=@'

            // Descargar también SIN iniciar sesión. Permite aprovechar el progreso previo.
            _kabraDownloadButton = new ButtonControl
            {
                Text = "DESCARGAR ARCHIVOS",
                FontSize = 16f,
                AutoViewSize = false,
                ViewSize = new Point(320, 42),
                Align = ControlAlign.HorizontalCenter | ControlAlign.Bottom,
                BackgroundColor = new Color(50, 24, 76, 235),
                HoverBackgroundColor = new Color(82, 40, 109, 245),
                PressedBackgroundColor = new Color(36, 14, 55, 240),
                BorderColor = new Color(193, 133, 214),
                BorderThickness = 1,
                TextColor = Color.White,
                Interactive = true,
                Visible = OperatingSystem.IsAndroid() && !LoadScene.HasCompleteKabraAssets()
            };
            _kabraDownloadButton.Click += (s, e) =>
            {
                if (!_kabraDownloadButton.Enabled) return;
                _kabraDownloadButton.Enabled = false;
                _kabraDownloadButton.Text = "Preparando descarga...";
                LoadScene.DownloadAfterLogin = true;
                // No comprobar contraseña aquí: la descarga es independiente del login.
                MuGame.Instance.ChangeScene(new LoadScene());
            };
            Controls.Add(_kabraDownloadButton);
'@
$login=$login.Replace($afterDialog,$afterDialog+$button)

# Asegurar que login aceptado sigue iniciando descarga automáticamente si el usuario
# nunca pulsó el botón. No se quita la ruta del cliente v14.
if (!$login.Contains('LoadScene.DownloadAfterLogin = true;')) {
    throw 'Se perdio la descarga posterior al login de la v14'
}

# Al salir de login, quitar el manejador para evitar referencias al botón.
$disposeAnchor='            UiThemeManager.ThemeChanged -= LoginScene_ThemeChanged;'
if (!$login.Contains($disposeAnchor)) { throw 'No se encontro limpieza de eventos' }
$login=$login.Replace($disposeAnchor,'            if (_kabraDownloadButton != null) _kabraDownloadButton.Enabled = false;'+[Environment]::NewLine+$disposeAnchor)

Set-Content -Path $loginFile -Value $login -Encoding utf8
Write-Host 'KABRA v15: Descargar archivos desde login, sin contraseña; opción de login previo conservada.'
