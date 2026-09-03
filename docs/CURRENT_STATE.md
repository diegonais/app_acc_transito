# Estado actual - Fase 8 completada

## Etapa

**Fase 8 - Fotografias y archivos**: finalizada.

La aplicacion mantiene autenticacion local sobre SQLite, gestion de policias
para `ADMIN` y el flujo de Informes de Accion Directa. La fase actual agrego
evidencias fotograficas desde camara y galeria, manejo temporal durante el
formulario, previsualizacion, categorias normalizadas y persistencia definitiva
por numero de caso.

No se implementaron todavia dashboard real, PDF ni QR.

## Dependencias

Dependencias agregadas en esta fase:

- `image_picker`: captura desde camara y seleccion multiple desde galeria.
- `mime`: identificacion basica del tipo de archivo seleccionado para metadato.

Se mantienen:

- `geolocator`: permisos, estado del servicio de ubicacion y latitud/longitud.
- `flutter_map`: croquis cartografico sencillo con OpenStreetMap.
- `latlong2`: modelo de coordenadas usado por `flutter_map`.
- `url_launcher`: apertura de coordenadas con una aplicacion externa compatible.
- `path_provider`: rutas persistentes y temporales de la aplicacion.
- `cryptography`: hash de contrasenas con PBKDF2-HMAC-SHA256 y salt aleatorio.
- `sqflite`: motor SQLite local.
- `path`: construccion portable de rutas.
- `sqflite_common_ffi`: SQLite real en memoria para pruebas.

## Informe de Accion Directa

Implementado:

- Ruta `/reports` accesible desde el dashboard.
- `POLICE` puede registrar informes nuevos.
- `ADMIN` consulta informes activos del dispositivo.
- `POLICE` consulta solamente sus informes activos.
- Formulario por secciones con estado en memoria, incluyendo evidencias
  fotograficas temporales.
- La seccion de coordenadas conserva GPS, croquis OSM, captura PNG opcional y
  apertura externa de mapas.
- La seccion de fotografias permite agregar evidencias desde camara y galeria.
- Cada fotografia se previsualiza como miniatura y permite cambiar categoria.
- Categorias centralizadas: `PANORAMICA`, `LICENCIA`, `PLACA`, `OTRA`.
- Las fotografias pueden quitarse antes de finalizar; al quitarlas se limpian
  temporales propios de la app cuando corresponde.
- Si el usuario cancela el informe, se descarta el estado en memoria y se
  eliminan las evidencias temporales creadas por la app.
- Si un archivo temporal falta, la UI muestra archivo inexistente y la
  finalizacion falla sin crear informe ni metadatos huerfanos.
- No existen borradores persistidos.
- `Finalizar informe` valida obligatorios y persiste definitivamente.
- Despues de finalizar, el detalle se abre en modo lectura y muestra las
  fotografias persistidas o estado de archivo inexistente.
- No existe edicion posterior del informe finalizado.

## Persistencia

- Version de esquema SQLite actual: `2`.
- No se requirio migracion nueva: la tabla `fotografias` ya existia con
  `id_informe`, `ruta`, `tipo`, `descripcion` y `fecha_creacion`.
- `PRAGMA foreign_keys = ON` se mantiene habilitado.
- `Finalizar informe` usa transaccion SQLite.
- Informe, conductores, vehiculos, relaciones, personas y fotografias se
  persisten como una sola unidad.
- Antes de insertar metadatos de fotografias, el correlativo se calcula dentro
  de la transaccion y se obtiene `numero_caso`.
- Las fotografias se copian desde el area temporal propia de la app a
  almacenamiento persistente bajo `reports/NUMERO_CASO/images/`.
- Los nombres persistentes son seguros y se basan en numero de caso, orden y
  categoria.
- SQLite guarda rutas/metadatos; nunca bytes ni BLOB.
- Si falla una operacion persistente, SQLite revierte la transaccion completa y
  se intenta limpiar cualquier fotografia persistente creada en ese intento.
- El informe se guarda asociado automaticamente al `id_policia` autenticado.
- Todo informe nuevo queda con `estado = 1`.
- Correlativo por gestion con formato `AAAA-NNNNNN`.
- Consultas de aplicacion filtran `estado = 1`.
- `ADMIN` puede inactivar informes con confirmacion.
- Inactivar solo cambia `estado` y conserva contenido, relaciones y archivos.
- No existe vista de inactivos ni reactivacion en UI.
- No se crean registros huerfanos durante el llenado del formulario.

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
- Para galeria se usa `image_picker`/selector del sistema, solicitando solo lo
  necesario segun la version Android objetivo.
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
  - finaliza varias fotografias persistidas con categorias;
  - valida relacion correcta de fotografias con `id_informe`;
  - archivo fotografico inexistente evita crear informe y metadatos.
- `test/services/evidence_media_service_test.dart`
  - copia imagen seleccionada al area temporal propia;
  - persiste evidencias bajo `reports/NUMERO_CASO/images/`;
  - genera nombres seguros por caso, orden y categoria;
  - limpia temporales al persistir y al cancelar;
  - falla claramente cuando el archivo fuente no existe.
- `test/data/database/persistence_test.dart`
  - mantiene creacion de BD versionada con `fotografias`;
  - inserta metadatos fotograficos como rutas;
  - conserva fotografias tras inactivar informe.

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
- Repetir validaciones fisicas pendientes de GPS, mapa, croquis PNG y apertura
  externa de coordenadas.

## Problemas conocidos

- No se probo en dispositivo Android fisico en esta fase.
- `flutter pub add image_picker` resolvio dependencias pero Windows mostro el
  aviso de Developer Mode/symlinks para plugins; `flutter analyze` y
  `flutter test` se ejecutaron correctamente.
- El dashboard sigue siendo minimo; los indicadores reales quedan para fase
  posterior.
- PDF y QR siguen pendientes para fases posteriores.

## Siguiente fase

**Fase 9.**
