# KABRA Android v14 — continuidad de descargas y login anticipado

## Problema observado
El usuario reportó que el ZIP de recursos (~1,7 GB) fallaba hacia la mitad y que cada APK volvía a descargar todo. El cliente Android había recibido `ApplicationId` nuevo en cada versión (`inicio11`, `inicio12`, `inicio13`), creando directorios privados separados; el cargador v13 también seguía eliminando los ZIP parciales después de varios errores.

## Cambios
- **Compatibilidad de actualización:** conservar `com.kabraonline.inicio13` (el identificador instalado en la v13) y subir `ApplicationVersion` a **14**. La APK distribuida DEBE firmarse con el certificado de la v13, no con el debug efímero de GitHub Actions. No desinstalar antes de actualizar, porque Android eliminaría los datos privados.
- Conservar `KabraData/Data.zip` incluso después de un error de red para que `Range` reanude desde el último byte. Comprobar origen mediante hash de URL para evitar mezclar fuentes. Si el ZIP ya está completo y es coherente, pasar a extracción sin volver a pedir ~1,7 GB.
- Comprobar espacio libre, mantener banderas de extracción pendiente/completa y no anunciar instalación completa antes del éxito.
- **Login antes de descargar**: modo 2D sin mundo para probar el acceso Louis31 antes de instalar recursos. Si el servidor rechaza el acceso, se muestra el código y **no** se descargan datos. Cuando se recibe la lista de personajes tras login válido, se inicia/retoma la descarga y se vuelve a la pantalla de login al finalizar.

## Limitaciones comprobables
- Si la v13 anterior ya borró físicamente el ZIP parcial, no es posible recuperarlo.
- Si el origen HTTP no admite `Range`, no se puede reanudar; el cliente deberá iniciar la descarga completa.
- Los recursos requieren almacenamiento suficiente para el ZIP (1,7 GB) y sus archivos extraídos. Además, el origen predeterminado del motor MonoGame es de MU Red, no un paquete confirmado de KABRA. Para despliegue final configurar una URL HTTPS directa en `KABRA_ASSETS_ZIP_URL`.
- La verificación de compilación no demuestra login real ni descarga de 1,7 GB en un dispositivo.

## Pruebas
- Actualización sobre `KABRA ONLINE v13 FONDO RESTAURADO`: debe conservar datos al instalar sobre la app, firmada con el certificado original.
- Cerrar con una descarga parcial, abrir nuevamente y comprobar HTTP 206 + progreso recuperado.
- Confirmar 001/006 del servidor antes de descargar; no guardar contraseñas ni desactivar antihack.
