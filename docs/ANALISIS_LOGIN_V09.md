# KABRA Android v09 — compatibilidad de autenticación S6 Louis31

## Fuentes examinadas
- `MAIN_INFO v31 - Season 6.zip`: configuración original de KABRA (host/puerto, versión y serial), sin publicarlo.
- `MuServer.zip`: `GameServerInfo - Common.dat` y `Hack.dat` de pruebas del 22/11/2026.
- `winshark.pcapng` (captura privada): 1403 paquetes y la conexión del Main.exe original.
- Código del cliente `xulek/muonline`, commit `f3365cb1` (base de la APK).

## Hallazgos confirmados
- ConnectServer TCP 44405, GameServer código 9 TCP 55901, versión S6 1.04.05 (cinco bytes ASCII `10405`).
- La envoltura Louis31 aplica a cada byte: `wire=((MU-1) XOR 0x10)`; el proceso inverso es `MU=((wire XOR 0x10)+1)`.
- Respuesta de 24 bytes que comienza en `D2` se transforma a `C3` y se descifra con las claves estándar de SimpleModulus y XOR32. El resultado es **C3 0C 0E 00 (Ping)**, no un desafío de autenticación propietario.
- El ping original contiene TickCount y velocidades cero, y fue observado después de la bienvenida F1 00. Se agregó un envío inicial correspondiente en Android.
- El constructor de login del cliente upstream usaba dos `stackalloc` de diez bytes para usuario y contraseña sin poner a cero los bytes sobrantes; en la v09 ahora se limpian ambos buffers y el paquete completo *antes* de cifrar con XOR3.
- Se mantiene el paquete Season 6 `C3 F1 01 LoginShortPassword`, 50 bytes, con versión de 5 bytes y serial de 16 bytes. Esto no altera ni debilita la autenticación.
- Se impide enviar múltiples intentos mientras `Authenticating` y se evita duplicar un rechazo de login como si fuera error de red.

## Qué NO demuestra la prueba
- La captura histórica **no contiene un login nuevo realizado con la APK v08/v09**. No se conoce el código preciso devuelto por Louis31 a esa instalación.
- El serial y la versión son necesarios pero insuficientes si existen otras verificaciones del GameServer y MHP en producción.
- El cliente puede compilar sin que la sesión esté autenticada. No afirmar que hay ingreso a personajes, Lorencia o juego real sin prueba de dispositivo.

## Prueba de regresión recomendada
1. Compilar Android ARM64 en CI con firmas oficiales y firmar la distribución con las herramientas de Android después de integrar el MainInfo local.
2. En una cuenta de prueba, realizar **un único intento de login**. Si hay rechazo, registrar sólo el valor del resultado F1 01 (0 contraseña; 1 éxito; 2 cuenta; 3 conectada; 6 versión; 7 error de conexión, etc.).
3. Comparar ese código con el log del GameServer de la misma hora. No almacenar contraseñas, paquetes completos de autenticación ni desactivar el antihack de producción.
