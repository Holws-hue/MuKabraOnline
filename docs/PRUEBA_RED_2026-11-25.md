# KABRA — prueba de conectividad sin credenciales

Prueba realizada desde GitHub Actions el 25 de noviembre de 2026.

## Resultados comprobados
- TCP `523.ddns.net:44405`: conexión aceptada.
- Respuesta a solicitud de listado `C1 04 F4 06`: se recibieron cuatro bytes con cabecera `C1 04 00 01` (el resultado indica que el servicio responde, pero requiere interpretación completa del protocolo).
- TCP `523.ddns.net:55901`: conexión aceptada.
- Al conectar, el GameServer envió 12 bytes y una cabecera `D0 1B E0 EF`, coherente con la negociación propietaria observada en una captura previa del cliente Windows.

## Interpretación
- Los puertos responden externamente; no hay evidencia de que el problema del cliente Android sea la IP o un firewall en estos puertos.
- El cliente abierto MonoGame usa los paquetes de red OpenMU; **no está probado** que admita el intercambio propietario del GameServer Louis 31.
- La respuesta tipo `D2` al reto inicial debe implementarse correctamente y verificarse en un entorno de pruebas; no se deben eliminar los controles de integridad y protección existentes en producción.
- No se ha probado todavía el login, selección de personaje, ni juego real.

## Seguridad
No se usó ninguna cuenta, usuario, contraseña ni token durante esta prueba. No se enviarán credenciales por GitHub Actions, ni se incluirán en APKs, repositorios públicos o registros.

## Próxima prueba
Al disponer de una APK instalada y con recursos gráficos accesibles, probar primero apertura y carga 3D, luego conexión al ConnectServer y negociación del GameServer, y solo entonces ingresar una cuenta de prueba en el dispositivo.
