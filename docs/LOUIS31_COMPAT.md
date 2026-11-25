# Compatibilidad KABRA Louis 31 — diagnóstico previo a pruebas online

## Qué está confirmado
- KABRA utiliza MU Season 6 Episode 3, cliente Windows 1.04.05 con serial de MainInfo.
- ConnectServer configurado históricamente en 523.ddns.net:44405; el servidor puede cambiar de IP/puerto y se debe verificar.
- El Main.exe real pasa por una fase de negociación con el GameServer **antes del formulario de login**.
- Esa negociación observada no es equivalente al flujo de OpenMU. Una compilación correcta de MonoGame no confirma que pueda jugarse en KABRA.

## Fases de implementación

1. **Construcción**: compilar APK nativo ARM64 con MonoGame; verificar su firma e instalación en un dispositivo real.
2. **Gráficos**: comprobar que el cliente puede cargar los datos gráficos autorizados de MU. No incluir Data propietaria en GitHub.
3. **ConnectServer**: establecer TCP y parsear lista de servidores; sin credenciales y con control de reconexiones.
4. **Selección GameServer**: comparar formato y tamaño de los mensajes enviados por el cliente Windows de KABRA.
5. **Negotiación inicial**: identificar y reproducir el protocolo propio de Louis 31 en entorno de pruebas; no saltarse ni desactivar el sistema de seguridad del servidor.
6. **Login de pruebas**: validar versión y serial exactos de MainInfo, formato de cuenta, resultado del login, solo con una cuenta de pruebas y sin registrar contraseñas.
7. **Gameplay**: selección de personaje; entrar a Lorencia; movimiento; mobs y daños; inventario; skills; chat, party, PvP y eventos.

## Configuración

La compilación de laboratorio apunta al ConnectServer conocido. El valor ClientSerial **no se ha copiado** al repositorio público. Si se necesita en CI, cargarlo como secret GitHub Actions `KABRA_CLIENT_SERIAL`. La variable no debe imprimirse ni registrarse en logs. La versión deberá configurarse como `KABRA_CLIENT_VERSION` tras verificar el formato de cinco bytes esperado por el paquete de login (no asumir que la cadena INI se envía literalmente).

## Seguridad

- No tocar GameServer, SQL ni MHP en producción para forzar compatibilidad.
- No publicar capturas PCAP completas ni cuentas/contraseñas ni seriales internos.
- No intentar login masivo ni reconexiones automáticas sin límite.
- El cliente sigue siendo un laboratorio; antes de distribuirlo comercialmente hay que confirmar permisos sobre el código de origen y assets.
