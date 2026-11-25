param([string]$Url = [string]$env:KABRA_ASSETS_ZIP_URL)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Url)) {
    throw 'FALTA KABRA_ASSETS_ZIP_URL. No compilar una APK que intenta bajar 1.7 GB de una fuente externa no verificada. Publica antes el ZIP real del cliente KABRA en HTTPS y configura la variable de GitHub Actions.'
}
$u=$null
if (![Uri]::TryCreate($Url,[UriKind]::Absolute,[ref]$u) -or $u.Scheme -ne 'https') {
    throw 'KABRA_ASSETS_ZIP_URL debe ser una URL HTTPS directa al ZIP real.'
}
$client=[System.Net.Http.HttpClient]::new()
$client.Timeout=[TimeSpan]::FromSeconds(30)
try {
    $req=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get,$Url)
    $req.Headers.Range=[System.Net.Http.Headers.RangeHeaderValue]::new([Nullable[long]]0,[Nullable[long]]1023)
    try {
        $resp=$client.SendAsync($req,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            $finalUri=$resp.RequestMessage.RequestUri
            if ($finalUri.Scheme -ne 'https') {throw 'La URL redirige a HTTP inseguro.'}
            if ([int]$resp.StatusCode -ne 206) {
                throw "El archivo no permite continuar descargas por HTTP Range. GET bytes=0-1023 respondio $([int]$resp.StatusCode) en lugar de 206."
            }
            $len=$resp.Content.Headers.ContentRange.Length
            if (!$len.HasValue -or $len.Value -lt 100MB) {
                throw "No se pudo verificar un archivo completo de recursos: Content-Range total=$len"
            }
            $stream=$resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            try {
                $buffer=New-Object byte[] 4
                $n=$stream.Read($buffer,0,4)
                if ($n -ne 4 -or $buffer[0] -ne 0x50 -or $buffer[1] -ne 0x4B -or $buffer[2] -ne 0x03 -or $buffer[3] -ne 0x04) {
                    throw 'El enlace no devuelve un ZIP real (cabecera PK 03 04); puede estar devolviendo una pagina HTML.'
                }
            } finally { $stream.Dispose() }
            Write-Host "FUENTE KABRA OK: HTTPS, Range=206, archivo ZIP, tamano $([Math]::Round($len.Value/1MB,1)) MiB"
            Write-Host 'La cabecera es valida. La descarga completa y compatibilidad MonoGame requieren prueba real.'
        } finally { $resp.Dispose() }
    } finally { $req.Dispose() }
} finally { $client.Dispose() }
