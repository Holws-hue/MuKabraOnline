# KABRA Android v18 — recursos de descarga propios (2026-11-25)

Se corrigió el bloqueo de distribución: la compilación anterior tenía `KABRA_ASSETS_ZIP_URL` vacía y recurría a MU Red 1.20.61 (1,7 GB), cuya descarga fallaba.

## Recurso publicado y verificado
- Origen: el cliente completo que ya estaba publicado por el dueño del servidor en MediaFire (archivo RAR).
- Pipeline: `.github/workflows/publicar-assets-android.yml` extrae únicamente `Data/`, genera ZIP y lo publica en GitHub Releases.
- Archivo: `https://github.com/Holws-hue/MuKabraOnline/releases/download/android-recursos-kabra-2026-11/KABRA_ANDROID_DATA.zip`
- Tamaño: 754.017.830 bytes, ~719 MiB.
- SHA256: `b1f26547c0d5474348130e350b8a45c9b7c854b7f20c6b22875cf487763525a6`
- Pruebas ejecutadas: integridad ZIP y presencia de Gate.bmd / World*, HTTP GET con Range=0-1023 devuelve 206 y cabecera PK 03 04.
- La compilación v18 utiliza la URL explícita en el flujo de validación y en `fix-android-assets-v13.ps1`.

## Instalación y limitaciones
- `ApplicationId` continúa `com.kabraonline.inicio13` y versión interna 18; firmar la distribución con el mismo certificado de v13-v16.
- Actualizar ENCIMA de la APK anterior, sin desinstalarla. Datos parciales de la fuente anterior no son compatibles y no se reutilizan si cambia el hash de origen.
- La descarga es propia, pero **todavía no se confirmó la compatibilidad completa** de archivos Season 6 del cliente Windows con el motor MonoGame, cuyo proyecto original usaba recursos Season 20.
- La compilación tampoco prueba que Louis31 acepte el login desde un dispositivo. Confirmar código `001` y entrada a personajes con una cuenta de prueba, nunca publicar contraseñas.

No declarar el APK como jugable al 100% hasta validar ambas cosas en dispositivo real.
