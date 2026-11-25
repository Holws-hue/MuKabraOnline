# MU KABRA — Android v0.5: corrección del inicio

## Reporte reproducible
En la APK anterior aparecía una ventana **Server IP / Port** en inglés. Al pulsar OK, el usuario no podía continuar al menú de acceso. Esto impedía probar la autenticación real.

## Causa exacta localizada
En la base MonoGame `Client.Main/Scenes/LoadScene.cs`, `TransitionToNextSceneAsync` elegía siempre `ServerConfigScene` si el sistema era Android. Por eso el servidor integrado en `appsettings.json` no evitaba que apareciera la ventana de configuración.

## Corrección incluida en v0.5
- Android pasa directamente de `LoadScene` a `LoginScene`, utilizando el ConnectServer y puerto incluidos en el APK.
- Al iniciar, la conexión de Android utiliza los valores del archivo de configuración base de KABRA, sin dejar que una preferencia local antigua los cambie.
- Menú de carga, formulario de cuenta, errores de conexión y selección de personajes traducidos al español.
- Canal PVP/CASTLE con nombres KABRA; no se muestra la IP ni el puerto en el menú.
- El aviso de desconexión antes del login permite reintentar manualmente al aceptar, sin reconexiones infinitas.
- APK de laboratorio con ApplicationId `com.kabraonline.inicio05` y versionCode 5.

## Verificaciones necesarias y limitaciones
- Los parches se validan durante la compilación en GitHub Actions y se confirma un APK Android firmado.
- **Todavía no hay una comprobación en un dispositivo Android real de un login exitoso, de la lista de personajes ni de entrada a Lorencia.**
- La transformación de transporte Louis 31 existente no equivale por sí sola a reproducir el protocolo completo de validación del GameServer/MHP.
- No se envían claves personales a GitHub ni se guardan contraseñas en código o logs. El ClientSerial se aplica de forma privada al APK final.

## Prueba de usuario sin contraseñas
1. Instalar la v0.5 y abrir esa aplicación (las versiones anteriores pueden coexistir).
2. Confirmar que **no** aparece ninguna pantalla Server IP / Port.
3. Seleccionar KABRA PVP, esperar al formulario de cuenta y probar el acceso con una cuenta de pruebas.
4. Si se desconecta al enviar, anotar el texto exacto y el momento, sin compartir contraseñas.
5. No repetir decenas de intentos: las protecciones antiflood de Louis pueden bloquear temporalmente los accesos.
