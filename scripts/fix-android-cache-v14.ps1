param([string]$ClientDirectory='upstream')
$ErrorActionPreference = 'Stop'
$loadFile = Join-Path $ClientDirectory 'Client.Main/Scenes/LoadScene.cs'
$load = Get-Content $loadFile -Raw

function Replace-Kabra([string]$from,[string]$to,[string]$name) {
    if (!$script:load.Contains($from)) { throw "KABRA v14: no se encontro $name" }
    $script:load = $script:load.Replace($from,$to)
}

# En v13 el catch externo borraba el ZIP parcial después del error de red.
Replace-Kabra '                    SafeDeleteFile(localZip);' '                    // KABRA: NO borrar datos parciales; reanudar en el siguiente arranque.' 'borrado de ZIP parcial'

# Si ya se bajó todo el ZIP, reutilizarlo al siguiente intento de extracción.
$old=@'
                if (expectedSize > 0 && existing >= expectedSize)
                {
                    SafeDeleteFile(destination);
                    existing = 0;
                }
'@
$new=@'
                if (existing > 0 && (expectedSize <= 0 || existing >= expectedSize))
                {
                    bool completeZip = false;
                    try
                    {
                        using var candidateZip = ZipFile.OpenRead(destination);
                        completeZip = candidateZip.Entries.Any(e =>
                            e.Name.Equals("Gate.bmd", StringComparison.OrdinalIgnoreCase))
                            && candidateZip.Entries.Any(e =>
                                e.FullName.Replace('\\', '/').Split('/')
                                  .Any(x => x.StartsWith("World", StringComparison.OrdinalIgnoreCase)));
                    }
                    catch (InvalidDataException) { /* ZIP truncado; intentar reanudar */ }
                    if (completeZip)
                    {
                        ReportProgress(existing, existing);
                        UpdateProgress(p => p.StatusText = "Descarga anterior recuperada. Preparando archivos...");
                        return;
                    }
                    if (expectedSize > 0 && existing >= expectedSize)
                    {
                        SafeDeleteFile(destination);
                        existing = 0;
                    }
                }
'@
Replace-Kabra $old.Trim() $new.Trim() 'comprobar ZIP completo'

# Identificar la fuente sin registrar contraseñas ni URL en archivos públicos.
$startLine='                long existing = File.Exists(destination) ? new FileInfo(destination).Length : 0;'
$originCode=@'
                string originFile = destination + ".origin.sha256";
                string originHash = Convert.ToHexString(
                    System.Security.Cryptography.SHA256.HashData(
                        System.Text.Encoding.UTF8.GetBytes(url)));
                if (File.Exists(destination) && File.Exists(originFile) &&
                    !string.Equals(File.ReadAllText(originFile).Trim(), originHash,
                        StringComparison.OrdinalIgnoreCase))
                {
                    SafeDeleteFile(destination);
                }
                File.WriteAllText(originFile, originHash);
'@
Replace-Kabra $startLine ($originCode+$startLine) 'origen del ZIP'

# Comprobar si queda espacio en la memoria del dispositivo.
$spaceAnchor='                using var request = new HttpRequestMessage(HttpMethod.Get, url);'
$spaceCheck=@'
                if (expectedSize > 0)
                {
                    try
                    {
                        long free = new DriveInfo(Path.GetPathRoot(Path.GetFullPath(destination))!).AvailableFreeSpace;
                        long missing = Math.Max(0, expectedSize - existing);
                        if (free < missing + 512L * 1024 * 1024)
                            throw new IOException($"Espacio insuficiente: faltan al menos {(missing + 512L * 1024 * 1024 - free) / (1024 * 1024)} MB libres.");
                    }
                    catch (ArgumentException) { /* Algunas versiones Android no exponen DriveInfo */ }
                    catch (UnauthorizedAccessException) { /* DriveInfo no disponible */ }
                }
'@
$seqStart=$load.IndexOf('private async Task DownloadSequentialAsync(',[StringComparison]::Ordinal)
$seqEnd=if($seqStart -ge 0){$load.IndexOf('        #endregion',$seqStart,[StringComparison]::Ordinal)}else{-1}
if($seqStart -lt 0 -or $seqEnd -le $seqStart){throw 'No se encontro descarga secuencial'}
$before=$load.Substring(0,$seqStart)
$seq=$load.Substring($seqStart,$seqEnd-$seqStart)
$after=$load.Substring($seqEnd)
if (!$seq.Contains($spaceAnchor)) { throw 'No se encontro HTTP GET secuencial' }
$seq=$seq.Replace($spaceAnchor,$spaceCheck+$spaceAnchor)
$load=$before+$seq+$after

# Marcador de extracción incompleta, con verificación de instalación.
$completeOld='            File.WriteAllText(Path.Combine(extractPath, ".kabra-assets-complete"), "OK");'
if (!$load.Contains($completeOld)) { throw 'No se encontro sello completo' }
$completeNew=@'
            File.WriteAllText(Path.Combine(extractPath, ".kabra-assets-complete"), "OK");
            SafeDeleteFile(Path.Combine(extractPath, ".kabra-assets-installing"));
'@
$load=$load.Replace($completeOld,$completeNew.TrimEnd())
$extractStart='            await ExtractZipWithProgressAsync(localZip, extractPath, ct);'
if (!$load.Contains($extractStart)) { throw 'No se encontro extracción' }
$load=$load.Replace($extractStart,'            File.WriteAllText(Path.Combine(extractPath, ".kabra-assets-installing"), "EXTRACTING");'+[Environment]::NewLine+$extractStart)
$checkMarker='return File.Exists(Path.Combine(dataPath, ".kabra-assets-complete"))'
if (!$load.Contains($checkMarker)) { throw 'No se encontro verificador de recursos' }
$load=$load.Replace($checkMarker,'return !File.Exists(Path.Combine(dataPath, ".kabra-assets-installing"))'+[Environment]::NewLine+'                && File.Exists(Path.Combine(dataPath, ".kabra-assets-complete"))')


# Comprobar espacio de extracción además del espacio para el ZIP.
# Un archivo de 1,7 GB puede requerir varios GB extra una vez descomprimido.
$validatePoint='            // Extract'
$uncompressed=@'
            using (var resourceZip = ZipFile.OpenRead(localZip))
            {
                long expanded = resourceZip.Entries.Sum(e => e.Length);
                try
                {
                    long free = new DriveInfo(Path.GetPathRoot(Path.GetFullPath(extractPath))!).AvailableFreeSpace;
                    if (expanded > 0 && free < expanded + 256L * 1024 * 1024)
                        throw new IOException($"Espacio insuficiente para descomprimir recursos: se necesitan aproximadamente {expanded / (1024 * 1024)} MB libres más 256 MB de seguridad.");
                }
                catch (ArgumentException) { /* DriveInfo no disponible en Android */ }
                catch (UnauthorizedAccessException) { /* No hay estadísticas de almacenamiento */ }
            }

'@
if (!$load.Contains($validatePoint)) { throw 'No se encontro inicio de extracción' }
$load=$load.Replace($validatePoint,$uncompressed+$validatePoint)
# Si la estructura del ZIP está corrupta, no insistir con un archivo inválido en cada inicio.
$extractLine='            await ExtractZipWithProgressAsync(localZip, extractPath, ct);'
$extractChecked=@'
            try
            {
                await ExtractZipWithProgressAsync(localZip, extractPath, ct);
            }
            catch (InvalidDataException)
            {
                SafeDeleteFile(localZip);
                SafeDeleteFile(localZip + ".origin.sha256");
                throw;
            }
'@
if (!$load.Contains($extractLine)) { throw 'Falta la extracción esperada' }
$load=$load.Replace($extractLine,$extractChecked.TrimEnd())

Set-Content $loadFile -Value $load -Encoding utf8
Write-Host 'KABRA v14: ZIP parcial persistente, origen verificado y recuperación de extracción.'
