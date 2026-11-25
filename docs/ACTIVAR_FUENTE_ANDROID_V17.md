# KABRA Android — bloqueo real de descarga (verificado)

La APK v16 compila pero el log de GitHub Actions (ejecución 45717461865) dice `KABRA_ASSETS_ZIP_URL:` **vacía**. Por ello el descargador apunta al ZIP predeterminado de MU Red, no al paquete propio de KABRA. No podemos presentar otra APK como "descarga reparada" mientras el origen real no exista o no pueda responder por HTTPS y HTTP Range.

## Solución preparada
1. El dueño del proyecto puede crear un ZIP con `Data/` del **cliente KABRA**, excluyendo ejecutables y configuraciones del GameServer. Las 15 partes aportadas del cliente Windows forman un ZIP íntegro, con 13.604 archivos dentro de Data, incluida `Gate.bmd` y `World*`, y ~713 MiB comprimidos. La compatibilidad completa con MonoGame Android **todavía no está validada**.
2. Alojar el ZIP en la web real (p. ej., static Apache XAMPP o almacenamiento de objetos con enlace directo) y verificar que GET con `Range: bytes=0-1023` devuelva HTTP 206 y la firma `PK 03 04`.
3. Configurar `KABRA_ASSETS_ZIP_URL` en GitHub → Settings → Secrets and variables → Actions → Variables.
4. Ejecutar `android-native.yml` de esta rama.

## Garantía nueva de CI
`scripts/validar-fuente-zip-v17.ps1` **falla de inmediato** si no existe URL, devuelve HTML/403/404 en vez de ZIP, no usa HTTPS, no permite reanudar o no declara longitud de un paquete de tamaño plausible. Se conecta ANTES de compilar, por lo que nunca más se certifica "APK lista" si sabemos que le faltan los archivos. Esto no resuelve por sí solo la compatibilidad de recursos, extracción o login real.

No cambiamos identificador Android ni firma, ni servidor/juego. No se publica ninguna URL inventada.

## Herramientas
Se creó además un pequeño paquete para PC del servidor con:
- `01_GENERAR_ZIP_ANDROID.bat` (Data del cliente)
- `03_PUBLICAR_EN_XAMPP.bat` para copiar de manera íntegra a la raíz web XAMPP si efectivamente aloja `mukabra.com`
- `02_VERIFICAR_ENLACE.ps1`
El usuario debe confirmar el dominio real del hosting; no se afirma que la ruta propuesta esté funcionando hasta comprobarla por HTTPS.
