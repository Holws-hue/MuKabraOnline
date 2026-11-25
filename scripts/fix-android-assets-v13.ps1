param([string]$ClientDirectory='upstream')
$ErrorActionPreference = 'Stop'

# KABRA Android: recursos en almacenamiento privado del dispositivo, NO en la ruta del ensamblado.
$constantsFile=Join-Path $ClientDirectory 'Client.Main/Constants.cs'
$c=Get-Content $constantsFile -Raw
$old='DataPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Data");'
$new='DataPath = OperatingSystem.IsAndroid() ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "KabraData") : Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Data");'
if (!$c.Contains($old)) { throw 'No se encontro el directorio de datos original' }
$c=$c.Replace($old,$new)
$old='public static string DataPathUrl = "http://192.168.55.220/Data.zip";'
if (!$c.Contains($old)) { throw 'No se encontro la URL local del motor' }
$url=[string]$env:KABRA_ASSETS_ZIP_URL
if (![string]::IsNullOrWhiteSpace($url)) {
  $uri=$null
  if (![Uri]::TryCreate($url,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'https') {
    throw 'KABRA_ASSETS_ZIP_URL debe apuntar a un ZIP directo por HTTPS'
  }
  if ($url.Contains('"') -or $url.Contains('\')) { throw 'URL ZIP invalida' }
} else { $url='' }
$c=$c.Replace($old,'public static string DataPathUrl = "' + $url + '";')
Set-Content $constantsFile -Value $c -Encoding utf8

$loadFile=Join-Path $ClientDirectory 'Client.Main/Scenes/LoadScene.cs'
$s=Get-Content $loadFile -Raw
if (!$s.Contains('//    _dataPathUrl,')) { throw 'No se encontro selector de URL' }
$s=$s.Replace('//    _dataPathUrl,','_dataPathUrl,')
# Si se publica un paquete de KABRA, usar SOLO ese paquete; no mezclar con otro juego.
$urls='string[] urls = {'+[char]10+'            //    _dataPathUrl,'+[char]10+'                Constants.DefaultDataPathUrl'+[char]10+'            };'
# Reemplazar el bloque a partir de sus marcadores para ignorar finales CRLF.
$start=$s.IndexOf('            string[] urls = {',[StringComparison]::Ordinal)
$end=if($start -ge 0){$s.IndexOf('            Exception lastError = null;',$start,[StringComparison]::Ordinal)}else{-1}
if($start -lt 0 -or $end -le $start){throw 'No se encontro lista de orígenes de descarga'}
$sourceChoice=@'
            string[] urls = string.IsNullOrWhiteSpace(_dataPathUrl)
                ? new[] { Constants.DefaultDataPathUrl }
                : new[] { _dataPathUrl };
'@
$s=$s.Substring(0,$start)+$sourceChoice+[Environment]::NewLine+$s.Substring($end)

# Android utiliza una descarga secuencial. Varios CDN no admiten Range y
# con la versión anterior los bloques repetidos dañaban el ZIP.
$s=$s.Replace('if (totalSize > 0 && supportsRanges && totalSize > ChunkSize * 2)','if (!IsAndroid && totalSize > 0 && supportsRanges && totalSize > ChunkSize * 2)')

# Si Content-Length existe, rechazar los truncamientos antes de marcar el 100%.
$anchor='                await dest.FlushAsync(ct);'
if(!$s.Contains($anchor)){throw 'No se encontro el final de DownloadSequentialAsync'}
$verify=@'
                if (totalBytes > 0 && downloadedBytes != totalBytes)
                    throw new IOException($"Descarga incompleta: {downloadedBytes} de {totalBytes} bytes.");
'@
$s=$s.Replace($anchor,$verify+$anchor)

# Reintentos automáticos para conexiones celulares intermitentes, sin reutilizar archivos corruptos.
$anchor='                    await DownloadFileAsync(url, localZip, ct);'
if(!$s.Contains($anchor)){throw 'No se encontro la llamada de descarga'}
$retries=@'
                    for (int attempt = 1; attempt <= 3; attempt++)
                    {
                        try
                        {
                            await DownloadFileAsync(url, localZip, ct);
                            break;
                        }
                        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
                        catch (Exception ex)
                        {
                            SafeDeleteFile(localZip);
                            if (attempt == 3) throw new IOException($"Descarga fallida tras 3 intentos: {ex.Message}", ex);
                            UpdateProgress(p => p.StatusText = $"Reintentando descarga ({attempt + 1}/3)...");
                            await Task.Delay(1500 * attempt, ct);
                        }
                    }
'@
$s=$s.Replace($anchor,$retries.TrimEnd())

# No confundir una página HTML de error (403/404) o ZIP truncado con recursos del juego.
$anchor='            // Extract'
if(!$s.Contains($anchor)){throw 'No se encontro inicio de extraccion'}
$validate=@'
            using (var zip = ZipFile.OpenRead(localZip))
            {
                bool hasGate = zip.Entries.Any(entry => entry.Name.Equals("Gate.bmd", StringComparison.OrdinalIgnoreCase));
                bool hasMaps = zip.Entries.Any(entry => entry.FullName.Replace('\\', '/').Split('/').Any(part => part.StartsWith("World", StringComparison.OrdinalIgnoreCase)));
                if (!hasGate || !hasMaps)
                    throw new InvalidDataException("El ZIP no tiene datos completos: faltan Gate.bmd o mapas World. No uses el Data.zip del GameServer.");
            }

'@
$s=$s.Replace($anchor,$validate+$anchor)

# Marcar como instalacion completa solamente si la extraccion realmente termina y existe Gate.bmd.
$anchor='            await ExtractZipWithProgressAsync(localZip, extractPath, ct);'
if(!$s.Contains($anchor)){throw 'No se encontro extraccion del ZIP'}
$completion=@'
            await ExtractZipWithProgressAsync(localZip, extractPath, ct);
            if (!File.Exists(Path.Combine(extractPath, "Gate.bmd")))
                throw new InvalidDataException("Falta Gate.bmd tras la extraccion.");
            if (!Directory.EnumerateDirectories(extractPath, "World*", SearchOption.TopDirectoryOnly).Any())
                throw new InvalidDataException("La extraccion no contiene mapas World.");
            File.WriteAllText(Path.Combine(extractPath, ".kabra-assets-complete"), "OK");
'@
$s=$s.Replace($anchor,$completion.TrimEnd())
$start=$s.IndexOf('        private static bool CheckAssetsExist(string dataPath)',[StringComparison]::Ordinal)
$end=if($start -ge 0){$s.IndexOf('        private static void SafeDeleteFile(string path)',$start,[StringComparison]::Ordinal)}else{-1}
if($start -lt 0 -or $end -le $start){throw 'Falta comprobador de datos de juego'}
$newChecker=@'
        private static bool CheckAssetsExist(string dataPath)
        {
            return File.Exists(Path.Combine(dataPath, ".kabra-assets-complete"))
                && File.Exists(Path.Combine(dataPath, "Gate.bmd"))
                && Directory.EnumerateDirectories(dataPath, "World*", SearchOption.TopDirectoryOnly).Any();
        }

'@
$s=$s.Substring(0,$start)+$newChecker+$s.Substring($end)

# Extraer ZIP de forma segura, detenerse en errores y acomodar los prefijos Data/ anidados.
$start=$s.IndexOf('        private async Task ExtractZipWithProgressAsync(',[StringComparison]::Ordinal)
$end=if($start -ge 0){$s.IndexOf('        #endregion',$start,[StringComparison]::Ordinal)}else{-1}
if($start -lt 0 -or $end -le $start){throw 'No se encontro bloque de extraccion'}
$newExtraction=@'
        private async Task ExtractZipWithProgressAsync(string zipPath, string outputDirectory, CancellationToken ct)
        {
            await Task.Run(() =>
            {
                using var archive = ZipFile.OpenRead(zipPath);
                var entries = archive.Entries.Where(e => !string.IsNullOrEmpty(e.Name)).ToArray();
                if (entries.Length == 0) throw new InvalidDataException("ZIP sin archivos.");
                string root = Path.GetFullPath(outputDirectory).TrimEnd(Path.DirectorySeparatorChar)
                    + Path.DirectorySeparatorChar;
                int processed = 0;
                foreach (var entry in entries)
                {
                    ct.ThrowIfCancellationRequested();
                    string relative = NormalizeEntryPath(entry.FullName);
                    if (string.IsNullOrWhiteSpace(relative)) continue;
                    string file = Path.GetFullPath(Path.Combine(root, relative));
                    if (!file.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException($"Ruta insegura en ZIP: {entry.FullName}");
                    string dir = Path.GetDirectoryName(file);
                    if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                    try { entry.ExtractToFile(file, overwrite: true); }
                    catch (Exception ex) { throw new InvalidDataException($"Error al extraer {entry.Name}: {ex.Message}", ex); }
                    processed++;
                    if (processed % 8 == 0 || processed == entries.Length)
                    {
                        float progress = (float)processed / entries.Length;
                        UpdateProgress(p => { p.Progress = progress; p.StatusText = $"Extrayendo archivos ({processed}/{entries.Length})"; });
                    }
                }
                UpdateProgress(p => { p.Progress = 1f; p.StatusText = "Archivos extraidos"; });
            }, ct);
        }

        private static string NormalizeEntryPath(string fullName)
        {
            string[] segments = fullName.Replace('\\', '/')
                .Split('/', StringSplitOptions.RemoveEmptyEntries);
            int index = Array.FindIndex(segments,
                x => x.Equals("Data", StringComparison.OrdinalIgnoreCase));
            if (index >= 0 && index + 1 < segments.Length)
                segments = segments[(index + 1)..];
            return segments.Length == 0 ? string.Empty : Path.Combine(segments);
        }

'@
$s=$s.Substring(0,$start)+$newExtraction+$s.Substring($end)

# Nunca continuar al login si se descargaron datos incompletos.
$errorOld='UpdateProgress(p => p.StatusText = "Error al preparar KABRA. Revisá la conexión y reiniciá la aplicación.");'
if(!$s.Contains($errorOld)){throw 'No se encontro salida de error KABRA'}
$s=$s.Replace($errorOld,'UpdateProgress(p => { p.IsDownloading = false; p.StatusText = $"Error de descarga: {ex.Message}"; });')
Set-Content $loadFile -Value $s -Encoding utf8

Write-Host 'KABRA v13: carpeta persistente Android, reintentos, ZIP validado, extraccion segura y marcador de instalacion.'
if ([string]::IsNullOrWhiteSpace($env:KABRA_ASSETS_ZIP_URL)) {
  Write-Warning 'No hay URL KABRA_ASSETS_ZIP_URL: se conserva el origen predeterminado del motor como prueba; necesita una descarga valida para jugar.'
}
