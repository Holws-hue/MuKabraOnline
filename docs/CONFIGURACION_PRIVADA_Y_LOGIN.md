# Configuración del cliente MU KABRA Android

## Dirección y puerto (interfaz)
En el APK el usuario verá los canales **KABRA PVP** y **KABRA CASTLE**, no la dirección IP ni el puerto. Los errores se presentan sin detalles de host.

**Advertencia técnica:** cualquier cliente que se conecte directamente al GameServer revela el destino a quien inspeccione su APK, su DNS o su tráfico. Para ocultar la IP de origen frente a terceros se requiere infraestructura de relay/proxy y reglas de firewall configuradas por el administrador. No basta con esconder el texto en el menú.

El repositorio es público. Si querés que los scripts de configuración no sean públicos, cambialo a privado desde GitHub > Settings > General > Danger Zone > Change repository visibility. Eso tampoco oculta la IP de un GameServer al que se conecta directamente el cliente.

## Serial y versión del cliente
La versión del cliente se define como 1.04.05 (se normaliza al formato del paquete MU). El código intenta leer el serial desde un secreto de GitHub Actions **KABRA_CLIENT_SERIAL**.

Para configurar ese secreto sin publicarlo:
1. Abrir el repositorio y entrar a Settings > Secrets and variables > Actions.
2. Seleccionar New repository secret.
3. Nombre: `KABRA_CLIENT_SERIAL`.
4. Valor: el ClientSerial exacto de tu **MainInfo.ini** original (16 caracteres).
5. Guardar. El valor no debe publicarse en issues, chats públicos o commits.

**Importante:** la compilación actual no garantiza que ese secreto esté configurado. Si está vacío, el proyecto base utiliza un serial de ejemplo que no sirve para login Louis31.

## Estado de login real
- Confirmado: ConnectServer accesible y anuncia servidores, GameServer responde.
- Confirmado: la capa de transporte reconstruye el saludo inicial Louis31 (D0 → C1 F1 00); pruebas de ida y vuelta automatizadas.
- Pendiente: validar en Android el paso por antifraude/MHP, respuesta de desafío C3/10, resultados del login, listado de personajes, entrada a Lorencia.
- Pendiente: datos gráficos autorizados compatibles con el motor MonoGame.

No está implementada una forma de saltar el antihack, no se ha desactivado la protección y no se insertaron contraseñas en el APK ni en GitHub.

## Registros de fallos recomendados
Al probar la APK, registrar únicamente la etapa a la que llega: menú, selección de canal, login, lista de personajes o entrada al mapa. No registrar ni compartir contraseñas. Para diagnósticos detallados, usar un equipo Android de pruebas y logs sanitizados.
