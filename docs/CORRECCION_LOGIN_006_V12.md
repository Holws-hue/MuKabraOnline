# KABRA Android v12 — corrección de código 006

## Qué confirmó el usuario
La APK v11 logró conectarse al GameServer pero obtuvo `F1:01 = 006` ("versión rechazada"). No fue un error de cuenta ni de contraseña: ese código es emitido por la validación inicial de versión **o serial**.

## Archivos originales revisados
- `MAIN_INFO v31 - Season 6.zip`: `ClientVersion=1.04.05` y serial de 16 bytes (no publicar el valor).
- `MuServer.zip` > `GameServer/Data/GameServerInfo - Common.dat`: `ServerVersion=1.04.05` y el mismo serial que MainInfo al momento de generar la copia.
- `KABRA_ONLINE_ANDROID_V11_ACCESO_DIAGNOSTICO.apk`: JSON `ClientVersion=1.04.05` y serial de 16 bytes idéntico a la copia anterior del MainInfo.

## Diagnóstico técnico
El código del GameServer de Louis compara **5 bytes de versión** y **16 bytes de serial** mediante `memcmp`. Ambos fallos emiten resultado `006`; por ello el mensaje "versión rechazada" no prueba por sí solo un error del número de versión.

Se encontró otra discrepancia: la v09-v11 sustituía el paquete `LoginLongPassword` (`C3 F1 01`, 60 bytes, campo contraseña 20) por `LoginShortPassword` (50 bytes, campo contraseña 10). En el protocolo fuente Louis S6 de `LouisEmulator/Main5.2` se define `PMSG_CONNECT_ACCOUNT_RECV.password[20]` para `GAMESERVER_LANGUAGE==1` (compilaciones EX603). El paquete corto coloca los bytes `ClientVersion` y `ClientSerial` 10 bytes antes que las posiciones que interpreta esta estructura de GameServer. Esto **puede** producir exactamente el rechazo 006, aunque el JSON del APK contenga la versión correcta.

## Parche
- Restaurar `LoginLongPassword` en `PacketBuilder.BuildLoginPacket`.
- Mantener la puesta a cero de los buffers antes de XOR3.
- Conservar `ClientVersion` (5 bytes de protocolo), `ClientSerial` (16 bytes) y resto del transporte Louis.
- Corregir texto de error 006 a "Versión o serial inválidos".
- No se hacen cambios en el GameServer, JoinServer, SQL ni MHP. No se publican seriales/contraseñas.

## Limitaciones
La fuente Louis usada es un **referente de protocolo cercano**, no el código fuente verificable del ejecutable GameServer de KABRA de noviembre de 2026. El parche requiere probarse con cuenta de prueba y confirmar resultado `F1:01=001` antes de declarar acceso solucionado. Si persiste 006, comparar versiones efectivamente cargadas en el servidor activo y sus logs; no alterar valores en producción sin verificarlos.
