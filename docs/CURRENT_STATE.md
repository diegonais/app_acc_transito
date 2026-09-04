# Estado actual - Fase 11 completada

## Etapa

**Fase 11 - Codigo QR**: finalizada.

La aplicacion mantiene autenticacion local sobre SQLite, gestion de policias,
registro de Informes de Accion Directa, evidencias fotograficas, dashboard,
consultas y soft delete de informes. Esta fase agrego el QR institucional local
asociado al policia propietario del informe y un punto minimo de integracion con
PDF para que el documento solicite el QR al servicio centralizado.

## Dependencias

Se agregaron dependencias justificadas para generacion local:

- `qr`: construccion local de la matriz QR.
- `pdf`: integracion local del QR dentro del PDF generado.

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

## QR institucional

Implementado:

- Servicio centralizado `lib/services/qr/institutional_qr_service.dart`.
- Modelo `InstitutionalQrPolice` con solo los datos permitidos:
  - nombre completo;
  - grado;
  - numero de placa;
  - unidad.
- Payload textual estructurado, simple y legible:

```text
FUNCIONARIO POLICIAL
Nombre completo: ...
Grado: ...
Numero de placa: ...
Unidad: ...
```

- Generacion local de QR mediante matriz `QrImage`.
- Validacion de datos obligatorios del payload.
- Se elimino la construccion previa de texto QR desde el usuario autenticado
  para evitar duplicacion de logica.

No se incluye:

- C.I.;
- usuario;
- contrasena/hash;
- IDs internos;
- informacion del dispositivo;
- datos no aprobados.

## Integracion PDF

Implementado:

- Servicio `lib/services/pdf/direct_action_report_pdf_service.dart`.
- El PDF no arma el payload por su cuenta; solicita el QR al
  `InstitutionalQrService`.
- El controlador `ReportController.buildReadablePdf`:
  - respeta permisos de lectura del actor;
  - carga el detalle persistido del informe;
  - resuelve el policia propietario por `id_policia`;
  - genera el PDF con el QR del propietario, aunque quien consulte sea Admin.
- El repositorio permite resolver la identidad QR del propietario desde SQLite
  sin exponer datos no autorizados al payload.

Nota: la maquetacion completa, guardado, visualizacion, compartir e impresion
del PDF quedan como superficie de Fase 10/12 pendiente en el estado recibido del
proyecto. La integracion QR-PDF queda preparada y probada.

## Dashboard y consultas

Se mantiene:

- Dashboard `ADMIN` con total activos, policias activos, informes por policia,
  informes del dia, del mes, por fecha seleccionada y resumen mensual.
- Dashboard `POLICE` con totales propios, indicadores del dia, mes, fecha
  seleccionada y resumen mensual propio.
- Estadisticas calculadas siempre desde SQLite.
- Sin tablas de contadores duplicados.
- Consultas de informes activos filtradas por rol, policia y fechas.
- Restriccion `POLICE` en controlador y repositorio para impedir alcance ajeno.

## Informe de Accion Directa

Se mantiene:

- Ruta `/reports` accesible desde dashboard.
- `POLICE` puede registrar informes nuevos.
- `ADMIN` consulta informes activos del dispositivo.
- Formulario por secciones con estado en memoria.
- Coordenadas, croquis OSM, captura PNG opcional y apertura externa de mapas.
- Fotografias desde camara y galeria con categorias.
- No existen borradores persistidos.
- `Finalizar informe` valida obligatorios y persiste definitivamente.
- Informe finalizado inmutable y detalle en modo lectura.

## Persistencia

- Version de esquema SQLite actual: `3`.
- No se modifico el esquema en esta fase.
- `PRAGMA foreign_keys = ON` se mantiene habilitado.
- `Finalizar informe` usa transaccion SQLite.
- El correlativo se calcula dentro de la transaccion considerando activos e
  inactivos.
- SQLite guarda rutas/metadatos de archivos; nunca bytes ni BLOB.
- Consultas, filtros y estadisticas filtran `estado = 1`.
- Inactivar solo cambia `estado` y conserva contenido, relaciones y archivos.

## Servicios

- `lib/services/qr/institutional_qr_service.dart`
  - construye payload QR institucional;
  - valida datos requeridos;
  - genera QR local no vacio.
- `lib/services/pdf/direct_action_report_pdf_service.dart`
  - incorpora el QR solicitado al servicio QR;
  - conserva el payload usado para trazabilidad y pruebas;
  - genera bytes PDF locales.
- `lib/services/media/evidence_photo.dart`
  - define la representacion centralizada de categorias fotograficas.
- `lib/services/media/evidence_media_service.dart`
  - obtiene imagenes desde camara y galeria;
  - copia selecciones a temporales propios de la app;
  - copia evidencias definitivas a `reports/NUMERO_CASO/images/`.
- `lib/services/geolocation/geolocation_service.dart`
  - conserva la obtencion de coordenadas y mensajes de permisos/fallas.
- `lib/services/maps/simple_sketch_map.dart`
  - conserva el croquis OSM sencillo.
- `lib/services/maps/map_snapshot_service.dart`
  - conserva captura PNG de croquis en documentos de la app.
- `lib/services/external_apps/external_maps_service.dart`
  - conserva apertura externa de coordenadas.

## Pruebas y validacion

Comandos ejecutados:

| Comando | Estado | Resultado |
|---|---|---|
| `dart format .` | correcto | formato aplicado |
| `flutter analyze` | correcto | sin issues |
| `flutter test` | correcto | todos los tests pasaron |

Pruebas agregadas o actualizadas:

- `test/services/institutional_qr_service_test.dart`
  - contenido correcto del payload;
  - datos excluidos ausentes;
  - QR local no vacio con matriz legible;
  - rechazo de datos obligatorios vacios.
- `test/services/direct_action_report_pdf_service_test.dart`
  - PDF local no vacio;
  - integracion del payload QR dentro del servicio PDF;
  - nombre de archivo segun formato documentado.
- `test/features/reports/report_controller_test.dart`
  - Admin generando/consultando PDF usa QR del policia propietario del informe;
  - se excluyen datos del Admin, otros policias y C.I.

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
- Validar lectura de QR desde un PDF generado en dispositivo.

## Problemas conocidos

- La implementacion recibida no tenia el PDF completo de Fase 10; esta fase dejo
  una integracion QR-PDF minima, local y testeada.
- No se probo en dispositivo Android fisico en esta fase.

## Siguiente fase

**Fase 12.**
