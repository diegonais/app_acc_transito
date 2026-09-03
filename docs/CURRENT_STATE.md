# Estado actual - Fase 9 completada

## Etapa

**Fase 9 - Consultas, filtros y dashboard**: finalizada.

La aplicacion mantiene autenticacion local sobre SQLite, gestion de policias,
registro de Informes de Accion Directa, evidencias fotograficas y soft delete
de informes. Esta fase agrego dashboard operativo real, consultas filtradas y
estadisticas locales diferenciadas por rol.

No se implementaron PDF, QR ni PDF estadistico del dashboard.

## Dependencias

No se agregaron dependencias en esta fase.

Se mantienen:

- `image_picker`: captura desde camara y seleccion multiple desde galeria.
- `mime`: identificacion basica del tipo de archivo seleccionado para metadato.
- `geolocator`: permisos, estado del servicio de ubicacion y latitud/longitud.
- `flutter_map`: croquis cartografico sencillo con OpenStreetMap.
- `latlong2`: modelo de coordenadas usado por `flutter_map`.
- `url_launcher`: apertura de coordenadas con una aplicacion externa compatible.
- `path_provider`: rutas persistentes y temporales de la aplicacion.
- `cryptography`: hash de contrasenas con PBKDF2-HMAC-SHA256 y salt aleatorio.
- `sqflite`: motor SQLite local.
- `path`: construccion portable de rutas.
- `sqflite_common_ffi`: SQLite real en memoria para pruebas.

## Dashboard y consultas

Implementado:

- Dashboard `ADMIN` con:
  - total de informes activos;
  - cantidad de policias activos;
  - informes por policia;
  - informes del dia;
  - informes del mes;
  - informes por fecha seleccionada;
  - resumen de informes por mes.
- Dashboard `POLICE` con:
  - total propio de informes activos;
  - indicadores propios del dia;
  - indicadores propios del mes;
  - indicador propio por fecha seleccionada;
  - resumen mensual propio.
- Las estadisticas se calculan siempre desde SQLite.
- No existen tablas de contadores ni totales duplicados persistidos.
- EPI se conserva como dato del informe, pero no se agrego como filtro del
  dashboard.
- La pantalla de informes permite consultar activos:
  - todos para `ADMIN`;
  - por policia para `ADMIN`;
  - por rango de fechas;
  - solo propios para `POLICE`.
- El detalle de informe permanece en modo lectura.
- La UI incluye cards, loading, error, empty y estado sin coincidencias.

## Seguridad por rol

- `ADMIN` puede consultar todos los informes activos e inactivar informes.
- `POLICE` puede registrar informes y consultar solamente sus informes activos.
- La restriccion por rol existe en controlador y repositorio:
  - las consultas `POLICE` fuerzan `id_policia` desde la sesion autenticada;
  - el filtro recibido no puede ampliar el alcance a informes ajenos;
  - el detalle `POLICE` se resuelve con `id_informe`, `id_policia` y
    `estado = 1` en la consulta.
- Un informe inactivo no se muestra, no se cuenta y no puede abrirse desde la
  consulta normal.

## Informe de Accion Directa

Se mantiene:

- Ruta `/reports` accesible desde el dashboard.
- `POLICE` puede registrar informes nuevos.
- `ADMIN` consulta informes activos del dispositivo.
- `POLICE` consulta solamente sus informes activos.
- Formulario por secciones con estado en memoria y evidencias fotograficas
  temporales.
- Coordenadas, croquis OSM, captura PNG opcional y apertura externa de mapas.
- Fotografias desde camara y galeria, con categorias `PANORAMICA`,
  `LICENCIA`, `PLACA`, `OTRA`.
- No existen borradores persistidos.
- `Finalizar informe` valida obligatorios y persiste definitivamente.
- El informe finalizado es inmutable y se abre en modo lectura.
- No existe edicion posterior del informe finalizado.

## Persistencia

- Version de esquema SQLite actual: `3`.
- Se agrego migracion versionada para indices de consultas por fecha:
  `idx_informes_estado_fecha_hecho` e
  `idx_informes_estado_policia_fecha_hecho`.
- `PRAGMA foreign_keys = ON` se mantiene habilitado.
- `Finalizar informe` usa transaccion SQLite.
- Informe, conductores, vehiculos, relaciones, personas y fotografias se
  persisten como una sola unidad.
- El correlativo se calcula dentro de la transaccion considerando activos e
  inactivos.
- SQLite guarda rutas/metadatos de archivos; nunca bytes ni BLOB.
- Todo informe nuevo queda con `estado = 1`.
- Correlativo por gestion con formato `AAAA-NNNNNN`.
- Consultas, filtros y estadisticas de aplicacion filtran `estado = 1`.
- `ADMIN` puede inactivar informes con confirmacion.
- Inactivar solo cambia `estado` y conserva contenido, relaciones y archivos.
- No existe vista de inactivos ni reactivacion en UI.
- Se usan consultas parametrizadas.
- Se mantienen indices previos sobre `informes(id_policia)` e
  `informes(estado)`.

## Servicios

- `lib/services/media/evidence_photo.dart`
  - define la representacion centralizada de categorias fotograficas.
- `lib/services/media/evidence_media_service.dart`
  - obtiene imagenes desde camara y galeria;
  - copia selecciones a temporales propios de la app;
  - copia evidencias definitivas a `reports/NUMERO_CASO/images/`;
  - genera nombres seguros;
  - limpia temporales al quitar/cancelar y persistentes si falla la finalizacion.
- `lib/services/geolocation/geolocation_service.dart`
  - conserva la obtencion de coordenadas y mensajes de permisos/fallas.
- `lib/services/maps/simple_sketch_map.dart`
  - conserva el croquis OSM sencillo.
- `lib/services/maps/map_snapshot_service.dart`
  - conserva captura PNG de croquis en documentos de la app.
- `lib/services/external_apps/external_maps_service.dart`
  - conserva apertura externa de coordenadas.

## Permisos Android

- `CAMERA` permanece declarado para captura desde camara.
- No se agregaron permisos amplios de almacenamiento.
- Para galeria se usa `image_picker`/selector del sistema.
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` e `INTERNET` se conservan por
  GPS y cartografia.

## Pruebas y validacion

Comandos ejecutados:

| Comando | Estado | Resultado |
|---|---|---|
| `dart format .` | correcto | formato aplicado |
| `flutter analyze` | correcto | sin issues |
| `flutter test` | correcto | todos los tests pasaron |

Pruebas agregadas o actualizadas:

- `test/features/reports/report_controller_test.dart`
  - consulta por fecha y policia;
  - exclusion de informes inactivos;
  - aislamiento de rol cuando `POLICE` intenta usar un `id_policia` ajeno.
- `test/data/database/persistence_test.dart`
  - totales de dashboard;
  - informes por dia, mes y fecha seleccionada;
  - informes por policia, incluyendo policia activo sin informes activos;
  - indicadores propios de `POLICE`;
  - resultados vacios;
  - detalle restringido por `id_policia`.
- `test/app_startup_test.dart`
  - rutas actualizadas con el controlador real de dashboard.

## Pruebas fisicas pendientes

Requieren dispositivo Android real:

- Permitir camara y confirmar captura de una fotografia.
- Denegar camara y confirmar mensaje de permisos no destructivo.
- Seleccionar una imagen desde galeria.
- Seleccionar varias imagenes desde galeria.
- Confirmar miniaturas, cambio de categoria y quitar fotografia.
- Cancelar informe con fotografias y confirmar limpieza de temporales propios de
  la app.
- Finalizar informe con varias fotografias y confirmar archivos persistentes en
  almacenamiento interno de la app.
- Confirmar que las rutas persistidas no apuntan a cache/temporales.
- Inactivar informe y confirmar que fotografias/metadatos se conservan.
- Probar dashboard y filtros en dispositivo con datos reales.
- Repetir validaciones fisicas pendientes de GPS, mapa, croquis PNG y apertura
  externa de coordenadas.

## Problemas conocidos

- No se probo en dispositivo Android fisico en esta fase.
- PDF y QR siguen pendientes para fases posteriores.

## Siguiente fase

**Fase 10.**
