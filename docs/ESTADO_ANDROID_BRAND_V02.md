# MU KABRA ONLINE — Android nativo | Marca v0.2

## Entregable verificado (25/11/2026)
- APK nativo Android ARM64 compilado correctamente mediante .NET 10 y MonoGame.
- Paquete Android `com.kabraonline.mobilepreview`; nombre visible `MU KABRA ONLINE`.
- Nuevo icono K dorado sobre rojo y negro para todas las densidades Android y variantes adaptativas.
- Imagen de inicio de fantasia oscura KABRA; nueva marca en pantalla de login y en todas las pantallas de carga.
- Se sustituyeron las referencias visibles `MuMono` en nombre de Android y login; no se renombraron espacios de nombres internos para evitar romper el motor.
- Compilación: [GitHub Actions #45557715827](https://github.com/Holws-hue/MuKabraOnline/actions/runs/45557715827).
- Verificación en APK: manifiesto, identificador, recursos mipmap y Content/Background.xnb.
- Nota: compilación exitosa no equivale a prueba de instalación en dispositivo real ni a gameplay confirmado.

## Protocolo del servidor real
- ConnectServer `523.ddns.net:44405`: contestó a un sondeo acotado sin credenciales.
- GameServer `523.ddns.net:55901`: recibe TCP y envía formato original `D0` anterior a login.
- Diagnóstico D0/D2 con capturas del cliente Windows: cuatro pruebas de decodificador exitosas.
- **Pendiente:** respuesta legítima a negociación previa al login, validación de cuenta de pruebas, personaje, mapa Lorencia, movimiento y combate.
- **Pendiente:** proporcionar datos gráficos autorizados en Android y comprobar carga de assets.
- Nunca poner contraseñas ni secretos de cuentas en GitHub ni compilaciones.

## Limitación de licencia
El cliente base xulek/muonline se presenta para uso educativo/no comercial. MU y sus recursos tienen titulares de derechos. No distribuir públicamente una edición comercial hasta obtener las autorizaciones pertinentes.

## Instalación
Es un build de laboratorio. Android podría rechazar futuras actualizaciones si la firma de depuración cambia entre ejecuciones; antes de distribuirlo se debe fijar una firma de release privada. No intentar instalar encima de una aplicación con distinta firma.
