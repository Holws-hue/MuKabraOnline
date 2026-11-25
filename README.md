# KABRA ONLINE — Cliente Android nativo (laboratorio)

Proyecto de evaluación para adaptar un cliente **MU Online MonoGame (C#/.NET 10)** a KABRA Online Season 6 E3 con files Louis 31. **No utiliza Babylon/WebView.**

Fuente técnica usada durante compilación: https://github.com/xulek/muonline (commit f3365cb1f5231d26979f16813204ab55ced699b7).
La fuente original declara uso educativo/no comercial; antes de publicar comercialmente un derivado hay que confirmar permisos de autores y de los recursos de MU Online.

## Estado
- Infraestructura de compilación Android real: preparada con GitHub Actions.
- Conexión prevista: 523.ddns.net:44405 (ConnectServer, validar puerto actual).
- **Login Louis 31, selección de personaje y gameplay: NO verificados**.
- El cliente base usa protocolo S6 destinado a OpenMU, y podría requerir adaptar cifrado, versión, serial, selección de servidor y paquetes personalizados.
- Recursos 3D: el código base necesita datos gráficos de MU; no se adjunta ningún paquete propietario en este repositorio.
- El APK de laboratorio es de depuración, no un release firmado para distribución.

## Compilar
Abrir **Actions** > **KABRA Android - compilacion de prueba** > Run workflow.
La acción descarga una revisión fija del cliente upstream, configura el host KABRA y crea el artefacto `Kabra-Android-Nativo-Preview` si la compilación pasa.
No se conecta ni modifica el GameServer, y no utiliza ninguna cuenta de jugadores.

## Datos pendientes para compatibilidad real
- ClientVersion y ClientSerial exactos de la configuración Louis 31 (no poner contraseñas personales).
- Confirmar endpoint público ConnectServer y puertos que devuelve la lista de servidores.
- Obtener logs de handshake de una cuenta de pruebas; primero probar sin iniciar sesión.

Si la compilación falla, usar los registros de **Actions**. Compilar un APK no prueba compatibilidad con KABRA.

## Primer resultado (25/11/2026)

- ✅ Compilación Android ARM64 en .NET 10 y MonoGame, APK Debug firmado mediante GitHub Actions: [run 45555318875](https://github.com/Holws-hue/MuKabraOnline/actions/runs/45555318875).
- ✅ Instalador verificado como archivo APK válido; contiene librerías ARM64 y recursos de interfaz.
- ✅ Conectividad TCP a ConnectServer 44405 y GameServer 55901 confirmada (sin credenciales), ver [diagnóstico](docs/PRUEBA_RED_2026-11-25.md).
- ⚠️ **No está comprobado que el APK inicie sesión o permita jugar en Louis 31**. El servidor anuncia un handshake propio tipo D0/D2 anterior al login que el cliente MonoGame de OpenMU no implementa todavía.
- ⚠️ Requiere datos gráficos de MU autorizados. Compilar con éxito no asegura que todos los mapas, personajes y animaciones carguen en Android.
- 🔒 No incorporar contraseñas de usuarios en el código, APK ni flujos de GitHub Actions. Las credenciales de prueba solo se ingresarán localmente cuando el protocolo esté implementado.
