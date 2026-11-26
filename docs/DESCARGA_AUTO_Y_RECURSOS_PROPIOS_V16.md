# KABRA Android v16 — diagnóstico y distribución de recursos

## Incidente verificado (2026-11-25)
La v15 no inicia la descarga automáticamente porque `DownloadAfterLogin` empezaba en `false`; la pantalla de inicio derivaba al login sin ejecutar el descargador. El botón de la v15 permitía pedir la descarga, pero no corregía el arranque automático. Esta rama cambia el valor inicial a `true` en Android y añade los controles **ENTRAR SIN DESCARGAR** y **REINTENTAR DESCARGA** a `LoadScene`.

**Segundo bloqueo, independiente del anterior:** los logs de GitHub Actions de la v15 muestran `KABRA_ASSETS_ZIP_URL:` vacío. Por ello la descarga utiliza `https://full-wkr.mu.webzen.co.kr/muweb/full/MU_Red_1_20_61_Full.zip`, el paquete externo de MU Red del motor MonoGame; no se verificó como recurso completo, estable ni compatible con KABRA S6. Reintentar el mismo origen no asegura que finalice.

## Recursos propios encontrados
Se recuperaron las 15 partes del archivo `KABRA_CLIENTE.zip` que el usuario había subido. El ZIP reconstruido pasó `testzip`, con **13.604 archivos regulares** en `Data`, **1.006,5 MiB sin comprimir**, **712,6 MiB comprimidos**; incluye `Data/Gate.bmd` y mapas `Data/World*`. Son datos del cliente Windows, no datos del GameServer. La compatibilidad de TODOS esos archivos con el motor MonoGame multiplataforma sigue por validar.

Para generar el paquete correctamente en la PC del servidor, sin volver a subir las 15 partes al chat:
```powershell
pwsh -File .\scripts\preparar-datos-kabra-android.ps1 -ClientDataDirectory "D:\MU KABRA\Data" -OutputZip "D:\KABRA_ANDROID_DATA.zip"
```
Reemplazar la carpeta de ejemplo por la ubicación real de `Data` del CLIENTE KABRA. El script comprueba `Gate.bmd` y `World*`, calcula SHA-256 y presenta tamaño y cantidad de archivos.

Subir `KABRA_ANDROID_DATA.zip` como **archivo estático** a HTTPS (Apache/Cloudflare R2/S3 o hosting propio con HTTP Range). El enlace debe descargar bytes ZIP directamente y responder correctamente a GET y Range. Para evitar las redescargas de 1,7 GB, publicar **tu ZIP de ~713 MiB**, no un ejecutable ni una página de MediaFire.

Configurar en GitHub → Settings → Secrets and variables → Actions → Variables:
`KABRA_ASSETS_ZIP_URL` = la URL HTTPS real al ZIP subido.
Volver a compilar el workflow de Android. El enlace de ejemplo NO existe hasta que se publique el ZIP; no codificar URLs inventadas en el APK.

## Instalación / login
Mantener `com.kabraonline.inicio13` y mismo certificado de firma de v13–v15, versión de paquete 16. Instalar arriba de v15, sin desinstalar ni borrar datos. El archivo parcial se conserva entre actualizaciones. **ENTRAR SIN DESCARGAR** permite probar login Louis31 (paquete S6 de 60 bytes) sin gastar datos. No confundir compilación correcta con login aprobado: confirmar código 001 real y selección de personaje en un dispositivo; ante 006 revisar valores del servidor activo y el paquete de autenticación.

## Límites
- No se probó descarga completa desde un dispositivo ni que esos datos Windows sean 100% compatibles con MonoGame.
- Si la versión anterior borró el ZIP parcial no hay forma de reconstruir bytes perdidos.
- Sin fuente HTTPS propia confirmada, la app sigue intentando la fuente MU Red que puede fallar.
