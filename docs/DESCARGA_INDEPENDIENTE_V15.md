# KABRA Android v15 — descargar archivos también sin iniciar sesión

Problema reportado: la v14 habilitó el login previo a la descarga de recursos, pero al quedar rechazado el login el usuario no podía acceder a la descarga de 1,7 GB.

## Corrección
- Mantener el modo de login ligero sin datos para comprobar compatibilidad Louis31.
- Mostrar el botón **DESCARGAR ARCHIVOS** en la pantalla de acceso cuando aún faltan datos.
- Al pulsar el botón, marcar `LoadScene.DownloadAfterLogin = true` y abrir el descargador de recursos **sin requerir credenciales ni código 001**.
- Mantener el flujo existente que también inicia descarga al recibir correctamente la lista de personajes.
- Conservar identificador `com.kabraonline.inicio13`, subir `ApplicationVersion` de 14 a 15 y distribuir con el **mismo certificado de firma** de v13 y v14. No desinstalar.
- Mantener la imagen cinematográfica original, barra de progreso, ZIP reanudable y datos parciales.

## Límites aún sin resolver
- El origen de recursos predeterminado pertenece al motor MonoGame MU Red, no a un paquete validado de KABRA. Para juego completo deberá publicarse un ZIP compatible en una URL HTTPS directa y configurarse en `KABRA_ASSETS_ZIP_URL`.
- La descarga reanudable requiere un origen que permita solicitudes HTTP Range; si los datos ya fueron eliminados por una versión antigua no se recuperan.
- La compilación correcta no prueba descarga de 1,7 GB ni login Louis31 aceptado.
