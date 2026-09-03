# Estado actual - Fase 7 completada

## Etapa

**Fase 7 - Geolocalizacion y mapas**: finalizada.

La aplicacion mantiene autenticacion local sobre SQLite, gestion de policias
para `ADMIN` y el flujo de Informes de Accion Directa. La fase actual agrego
captura de coordenadas GPS, croquis cartografico sencillo basado en
OpenStreetMap, preparacion de PNG para PDF y apertura externa de coordenadas.

No se implementaron todavia dashboard real, fotografias desde camara/galeria,
PDF ni QR.

## Dependencias

Dependencias agregadas en esta fase:

- `geolocator`: permisos, estado del servicio de ubicacion y latitud/longitud.
- `flutter_map`: croquis cartografico sencillo con OpenStreetMap.
- `latlong2`: modelo de coordenadas usado por `flutter_map`.
- `url_launcher`: apertura de coordenadas con una aplicacion externa
  compatible.
- `path_provider`: ruta de documentos de la app para guardar capturas PNG de
  croquis como archivo.

Se mantienen:

- `cryptography`: hash de contrasenas con PBKDF2-HMAC-SHA256 y salt aleatorio.
- `sqflite`: motor SQLite local.
- `path`: construccion portable de rutas.
- `sqflite_common_ffi`: SQLite real en memoria para pruebas.

## Autenticacion

- Gestor de sesion en memoria: `lib/features/auth/application/auth_controller.dart`.
- Scope de acceso a sesion: `lib/features/auth/application/auth_scope.dart`.
- Repositorio de autenticacion: `lib/features/auth/data/auth_repository.dart`.
- Hashing de contrasena: `lib/features/auth/data/password_hasher.dart`.

Flujos vigentes:

- Si no existe ningun `ADMIN`, el splash redirige a configuracion inicial.
- La configuracion inicial crea el primer `ADMIN`.
- Login local valida usuario activo, contrasena y rol.
- Usuarios inactivos no acceden.
- Usuarios `POLICE` requieren perfil policial activo asociado.
- La sesion vive solo en memoria mientras la app esta abierta.
- No existe `Recordarme`.
- Logout limpia la sesion y vuelve a login.

## Gestion de policias

Implementado solo para `ADMIN`:

- Ruta protegida `/officers` accesible desde el dashboard del Administrador.
- Listado de policias registrados con estados loading/error/empty.
- Alta de funcionario policial con datos administrativos confirmados.
- Modificacion de datos administrativos permitidos.
- Activacion/desactivacion sincronizada de policia y usuario asociado.
- Restablecimiento de contrasena por Admin sin mostrar la anterior.

No se agregaron celular del policia ni numero de escalafon.

## Informe de Accion Directa

Implementado:

- Ruta `/reports` accesible desde el dashboard.
- `POLICE` puede registrar informes nuevos.
- `ADMIN` consulta informes activos del dispositivo.
- `POLICE` consulta solamente sus informes activos.
- Formulario por secciones con estado en memoria:
  - EPI / Estacion Policial Integral;
  - fecha/hora de llegada;
  - fecha/hora del hecho;
  - naturaleza;
  - lugar textual;
  - denunciante, documento y contacto;
  - descripcion;
  - condiciones climaticas;
  - vehiculos movidos;
  - protagonistas presentes;
  - testigos;
  - efectos personales;
  - latitud/longitud opcionales;
  - ruta de croquis PNG opcional;
  - conductores dinamicos;
  - vehiculos dinamicos;
  - personas involucradas dinamicas.
- La seccion de coordenadas permite solicitar ubicacion GPS y muestra estados de
  carga, exito y falla.
- Fallas por permiso denegado, permiso permanentemente denegado, servicio
  desactivado o ubicacion no disponible no bloquean `Finalizar informe`.
- Si no hay coordenadas, latitud/longitud quedan nulas y se conserva el lugar
  textual.
- Con coordenadas disponibles, el formulario muestra un croquis cartografico
  sencillo con `flutter_map` + OpenStreetMap, marcador, zoom y desplazamiento.
- Mover el mapa solo cambia el encuadre y no modifica las coordenadas
  registradas.
- La cartografia puede preparar una captura PNG para PDF; SQLite conserva solo
  la ruta del archivo, nunca BLOB.
- Si las teselas del mapa no cargan, se muestra mensaje claro, se conservan las
  coordenadas y la finalizacion no se bloquea.
- Las coordenadas pueden abrirse en una aplicacion externa compatible.
- Conductores pueden agregarse, revisarse, editarse y quitarse antes de
  finalizar.
- Vehiculos pueden agregarse, revisarse, editarse y quitarse antes de finalizar.
- Personas involucradas pueden agregarse, revisarse, editarse y quitarse antes
  de finalizar.
- No existen borradores persistidos.
- Cancelar con datos ingresados solicita confirmacion y advierte perdida de la
  informacion no guardada.
- `Finalizar informe` valida obligatorios y persiste definitivamente.
- Despues de finalizar, el detalle se abre en modo lectura.
- No existe edicion posterior del informe finalizado.
- No existen controles UI para editar o eliminar hijos individualmente en modo
  lectura final.

## Persistencia

- Version de esquema SQLite actual: `2`.
- No se requirio migracion nueva: `latitud`, `longitud` y `ruta_croquis` ya
  existian en `informes`.
- La version 2 agrega triggers para impedir que un vehiculo relacione un
  conductor perteneciente a otro informe.
- `PRAGMA foreign_keys = ON` se mantiene habilitado.
- `Finalizar informe` usa transaccion SQLite.
- Informe, conductores, vehiculos, relaciones, personas y fotografias se
  persisten como una sola unidad.
- Si falla una operacion persistente, SQLite revierte la transaccion completa.
- El informe se guarda asociado automaticamente al `id_policia` autenticado.
- Todo informe nuevo queda con `estado = 1`.
- Correlativo por gestion con formato `AAAA-NNNNNN`.
- El correlativo se calcula al finalizar y considera activos e inactivos.
- Los correlativos no se reutilizan tras inactivar.
- Consultas de aplicacion filtran `estado = 1`.
- `ADMIN` puede inactivar informes con confirmacion.
- Inactivar solo cambia `estado` y conserva contenido/relaciones.
- No existe vista de inactivos ni reactivacion en UI.
- No se crean registros huerfanos durante el llenado del formulario.
- Archivos de croquis se guardan fuera de SQLite y la base registra solamente
  la ruta.

## Servicios

- `lib/services/geolocation/geolocation_service.dart`
  - verifica servicio de ubicacion;
  - solicita/verifica permisos;
  - obtiene latitud/longitud;
  - devuelve estados claros para permiso denegado, denegado permanente,
    servicio desactivado y error no disponible.
- `lib/services/maps/simple_sketch_map.dart`
  - mapa OSM centrado en coordenadas;
  - marcador visible;
  - zoom/desplazamiento;
  - aviso si fallan teselas.
- `lib/services/maps/map_snapshot_service.dart`
  - captura `RepaintBoundary` como PNG;
  - guarda en documentos de la app bajo `croquis/`;
  - devuelve ruta de archivo.
- `lib/services/external_apps/external_maps_service.dart`
  - abre URI `geo:` y usa OpenStreetMap web como respaldo.

## Pruebas y validacion

Comandos ejecutados:

| Comando | Estado | Resultado |
|---|---|---|
| `dart format .` | correcto | formato aplicado |
| `flutter analyze` | correcto | sin issues |
| `flutter test` | correcto | todos los tests pasaron |

Pruebas agregadas o actualizadas:

- `test/features/reports/report_controller_test.dart`
  - GPS fallido no bloquea finalizacion;
  - conserva lugar textual con latitud/longitud nulas;
  - persiste coordenadas y ruta PNG del croquis.
- `test/services/external_maps_service_test.dart`
  - construccion de URI `geo:` para apertura externa.

Pruebas existentes conservadas:

- `test/features/officers/officer_management_repository_test.dart`
- `test/features/auth/auth_repository_test.dart`
- `test/features/auth/auth_controller_test.dart`
- `test/app_startup_test.dart`
- `test/data/database/persistence_test.dart`

## Pruebas fisicas pendientes

Requieren dispositivo Android real:

- Permitir ubicacion y confirmar obtencion de latitud/longitud.
- Denegar ubicacion y confirmar mensaje no bloqueante.
- Denegar permanentemente ubicacion y confirmar mensaje de ajustes.
- Desactivar servicio GPS y confirmar mensaje no bloqueante.
- Confirmar carga de teselas OpenStreetMap con internet disponible.
- Confirmar estado claro sin conectividad o sin carga de teselas.
- Preparar captura PNG del croquis y verificar que el archivo exista.
- Abrir coordenadas con una aplicacion externa de mapas instalada.

## Problemas conocidos

- No se probo en dispositivo Android fisico en esta fase.
- El dashboard sigue siendo minimo; los indicadores reales quedan para fase
  posterior.
- Fotografias desde camara/galeria, PDF y QR siguen pendientes para fases
  posteriores.

## Siguiente fase

**Fase 8.**
