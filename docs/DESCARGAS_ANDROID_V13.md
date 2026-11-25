# KABRA Android — descarga de recursos (v13)

## Diagnóstico confirmado
El cliente `xulek/muonline` hace la descarga inicial en `LoadScene.cs`.
- La URL antigua usaba la descarga de assets de MU Red S20 desde un servidor externo. Se usaba para modelos/texturas del motor MonoGame, no era una descarga alojada por KABRA ni se verificaba antes de usarla.
- Android trataba la ruta base del ensamblado como almacenamiento y descargaba por bloques HTTP Range. Muchos servidores CDN devuelven HTTP 200 a esos bloques y el ZIP termina corrupto.
- Una descarga incompleta podía contarse como 100%.
- La extracción ignoraba excepciones y `CheckAssetsExist` validaba con **cualquier archivo** de la carpeta.
- Los ZIP de recursos pueden contener prefijos como `MU_Red_1_20_61_Full/Data/Gate.bmd`, que la rutina anterior no eliminaba.

## Corrección
- Guardar datos en almacenamiento privado de la aplicación Android.
- Descarga secuencial de Android, 3 reintentos por origen, comprobación del tamaño total recibido.
- Validación del ZIP (incluye `Gate.bmd` y mapas `World*`) antes de descomprimir.
- Extraer eliminando prefijos `Data/` y impedir ZIP Slip.
- Fallar explícitamente si una extracción falla, en vez de continuar al login.
- Crear sello `.kabra-assets-complete` **después** de la extracción total.
- Validación de sello, `Gate.bmd` y `World*` para no considerar instalada una descarga incompleta.
- Mantener el progreso real de interfaz v11.
- Permitir configurar `KABRA_ASSETS_ZIP_URL` como variable de GitHub Actions, HTTPS directo a archivo ZIP, no enlace de página web ni RAR.
- Si no está configurada una URL propia, sigue disponible la URL de recursos original de MonoGame como entorno de prueba. **Esto no asegura que siga disponible ni que contenga los datos específicos de KABRA.**

## ¿Qué archivo debe alojarse?
El APK usa los datos del CLIENTE (ejemplos: `Gate.bmd`, `Local/`, `World1/`, texturas), no los textos de configuración del GameServer. Los archivos privados subidos anteriormente con nombres `Data.zip` (configuraciones del GameServer) y `clientedata.zip` (solo datos Local y Gate, sin mapas completos) NO son paquetes completos para este cliente.

El MediaFire que figura en la web de KABRA distribuye un RAR del cliente Windows; no es un ZIP de recursos directo, y Android no puede extraerlo con `ZipFile.OpenRead`.

Para una distribución real, alojá un ZIP completo de recursos compatible con MonoGame en un servidor HTTPS bajo tu control y configurá la variable del workflow `KABRA_ASSETS_ZIP_URL` apuntando a ese ZIP. No publiques contenido que no tengas autorización para distribuir.

## Pruebas finales pendientes
- Descarga completa desde un Android real y validación del contenido.
- Extracción con poco espacio y suspensión de red (debe fallar claramente sin dar por terminada la instalación).
- Inicio de sesión Louis31 y selección de personaje, por separado de descarga.
