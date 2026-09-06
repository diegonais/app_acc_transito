# Estado actual — Consulta de informes y PDF rediseñados

## Actualización 2026-09-06 — UX/UI documental

Se implementó el rediseño solicitado del detalle y del PDF sobre la versión
estabilizada. El detalle ahora tiene cabecera de caso/estado/fecha, secciones
semánticas, relaciones completas, descripción legible, coordenadas formateadas,
mapa bajo demanda, croquis y fotografías ampliables, funcionario y QR.
La consulta se separó del formulario en archivos y componentes específicos.

El PDF incorpora logo, denominación del logo institucional, tablas, encabezados
de continuación, pie con caso/páginas y espacio de firma. Conserva contenido,
fuentes españolas locales y servicio QR; maneja valores largos, imágenes
faltantes y metadatos MIME heredados sin exponer rutas. El preview conserva
Guardar/Compartir/Imprimir con una barra más compacta. No hay dependencias nuevas
ni cambios en esquema SQLite, modelos, repositorios o reglas de negocio.

Verificación: `flutter analyze` sin incidencias y **85 pruebas correctas**.
Consulta probada a 320/360/412/800 px con texto al 200 %. Se renderizaron seis
PDF sintéticos (2, 3, 4, 7 y hasta 15 páginas), se revisaron visualmente y se
verificó conservación del texto/relaciones/fotos por extracción. El QR se
leyó desde las seis muestras y desde una captura de widgets. Se revisó además
la presentación en escala de grises.

`dart format .` sigue encontrando un residuo inválido de Gradle bajo `build/`;
`dart format lib test` correcto (66 archivos). No se borraron builds ni se
interrumpió la sesión Flutter existente. Se preservaron cambios previos.

Detalle de archivos, componentes, pruebas y límites:
`docs/REPORT_DETAIL_REDESIGN_2026-09-06.md`.
Pendientes: Word/PDF de referencia no adjuntos, pruebas finales de dispositivo
y nuevo empaquetado APK. El APK anterior no contiene esta intervención.
La fase siguiente planificada sigue siendo Fase 15 (manual); DECISIONS no cambió.

# Historial anterior

# Estado actual — Revisión integral y estabilización

## Actualización 2026-09-05 — Revisión solicitada por el usuario

Se revisaron la aplicación existente, persistencia SQLite v3, autenticación,
roles, administración, wizard, consultas, archivos, mapas, PDF/QR, pruebas y
configuración Android. Esta intervención estabiliza las funciones existentes;
la siguiente fase planificada sigue siendo el manual de usuario.

- Corregida la pérdida de temporales de fotografías antes del commit. Una copia
  parcial o un rollback SQLite conserva los originales para reintentar y limpia
  únicamente las copias creadas por la operación fallida.
- Validación de coordenadas completas, finitas y dentro de los rangos geográficos
  tanto en UI como en repositorio. Cancelar ya no convierte entradas inválidas
  mediante `double.parse`. Se bloquea salir o avanzar durante operaciones pendientes.
- Croquis capturado al dejar el paso cartográfico, actualización del mapa al
  cambiar coordenadas y liberación de la imagen de captura. Se limpian croquis
  generados en el formulario y descartados, conservando el asociado al informe.
- PDF con Roboto Regular/Bold local y licencia, paginación de descripciones largas,
  relaciones y fotografías, nombres de archivo con tildes/ñ y nombre del conductor
  en lugar de su ID técnico. Escritura mediante archivo temporal y renombrado.
- Español corregido en interfaz, validaciones y PDF/QR. Se agregó únicamente
  `flutter_localizations` del SDK para diálogos en español de Bolivia y formato
  horario de 24 horas. Retirados `cupertino_icons` y el uso directo de `mime`, que
  guardaba el tipo MIME como si fuera una descripción de evidencia.
- Mensajes de error comprensibles; diagnóstico limitado al tipo de excepción,
  sin credenciales, valores del formulario ni rutas privadas.
- Consultas pendientes invalidadas al cambiar de sesión o cerrar controladores;
  el dashboard se actualiza al volver de informes o administración.
- Dashboard adaptado a pantallas estrechas, sin cortar etiquetas ni el nombre;
  botones permiten saltos de línea y Android muestra el nombre ACC Tránsito.
- Creación del primer Admin protegida por transacción ante concurrencia;
  administración verifica la correspondencia policía/cuenta y restringe los
  restablecimientos a cuentas POLICE. Hashes malformados se rechazan.

Verificación: `flutter analyze` sin incidencias; `flutter test` con **76 pruebas
correctas** (61 iniciales y 15 nuevas). Se conservaron las pruebas existentes,
ajustando sus textos y la expectativa de limpieza de temporales después del commit.
Pruebas nuevas: rollback real con archivos y reintento, Unicode en SQLite/PDF/QR,
coordenadas inválidas, carrera del primer Admin, IDs administrativos mezclados,
consultas tardías y recorrido del wizard en 360x800.

Un PDF de estrés de 13 páginas se renderizó y revisó: conserva 180 repeticiones
del texto español, 20 conductores y 14 fotografías; el QR se decodificó desde la
imagen con “José Muñoz Peña” y “División de Tránsito”. Desaparecieron las advertencias
de Helvetica. Los archivos de prueba permanecen fuera del versionado.

`dart format .` encontró nuevamente una ruta residual inválida de Gradle bajo
`build/`; `dart format lib test` terminó correctamente (61 archivos). No se borró
el directorio de compilación para resolver un problema ajeno a las fuentes.
`scripts/package_release.ps1` compiló y verificó el APK release de 58.9 MB:
`build/app/outputs/flutter-apk/app-release.apk`, SHA256
`8B8FE0EDC9545DBE4EE45103833E0B99A6B865A3FA73D9003BE8CA22DE4C5D92`.

En el emulador aislado `TransitoRevision20260906` (API 35) se verificaron creación
del Administrador, login, dashboard y nuevo login al reabrir. La actualización
del APK final conservó la cuenta. La revisión visual confirmó etiquetas completas.

Pendientes reales: comparación visual con el Word oficial (no está en los assets
disponibles), recorrido de GPS/permisos/cámara/galería/compartir/impresión en un
teléfono real y futura actualización coordinada de Gradle/AGP/Kotlin. El emulador
existente rechazó la actualización por firma incompatible; su instalación se
conservó. Detalle y resultados de verificación Android en
`docs/REVIEW_2026-09-05.md`.

No se modificaron el esquema SQLite v3, sus migraciones, las decisiones
consolidadas ni los archivos de informes inactivos. Las secciones siguientes
son el historial anterior y sus pendientes quedan sustituidos por este resumen.

# Historial — PDF completo con QR, preview, guardado y compartir

## Actualizacion 2026-09-05 — Flujo PDF funcional

Se implemento el flujo funcional desde el detalle de informe para generar y
previsualizar el PDF del Informe de Accion Directa. En
`lib/features/reports/report_list_page.dart`, `ReportDetailPage` ahora expone
la accion `Ver informe PDF`, muestra estado de generacion y abre
`ReportPdfPreviewPage` con los bytes generados desde el `idInforme` persistido.

`DirectActionReportPdfService` fue ampliado sin reemplazar el QR existente:
mantiene `InstitutionalQrService` como fuente del QR institucional y construye
un PDF A4 multipagina con datos generales, fechas legibles, descripcion,
denunciante, condiciones, conductores, vehiculos, personas involucradas,
ubicacion, croquis si existe, fotografias disponibles, datos del funcionario
responsable y QR. Fotografias y croquis se leen desde rutas de archivo; si un
archivo falta o no puede leerse, se omite sin cancelar la generacion del PDF.

Se agregaron `printing` y `share_plus` como dependencias directas para preview,
impresion y share sheet estandar. `ReportPdfPreviewPage` permite Guardar PDF,
Compartir e Imprimir. El guardado usa `ReportPdfFileService`, escribe bajo
`documents/reports/<numeroCaso>/pdf/<nombre>.pdf` y persiste `informes.ruta_pdf`
mediante `ReportController.saveReadablePdf`, `ReportRepository.updatePdfPath`
y `ReportDao.updatePdfPath`, sin SQL desde UI ni cambios de esquema.

Validaciones ejecutadas:

- `flutter pub add printing share_plus`: agrego `printing 5.15.0`,
  `share_plus 13.3.0` y transitorios; termino con el aviso Windows ya conocido
  de symlink/developer mode para plugins de escritorio.
- `dart format lib test`: correcto.
- `flutter analyze`: sin issues.
- `flutter test`: 61 tests pasaron. Persisten advertencias Helvetica/Unicode
  del paquete `pdf`; la generacion no falla, pero queda pendiente validacion
  visual final con documento oficial y fuente institucional si se requiere
  cobertura tipografica completa.

# Estado actual — Wizard de Informe de Accion Directa implementado

## Actualizacion 2026-09-05 — Informe de Accion Directa por pasos

Se rediseño el flujo de creacion del Informe de Accion Directa en
`lib/features/reports/report_list_page.dart`, transformando el formulario largo
en un wizard de 6 pasos dentro de una sola ruta/pantalla:

1. Datos generales.
2. Denunciante.
3. Descripcion y condiciones.
4. Coordenadas y croquis.
5. Fotografias y archivos / Conductores.
6. Vehiculos / Personas involucradas.

Se preservo el orden real del formulario, los `TextEditingController`, listas en
memoria, selectores de fecha/hora, validadores existentes, geolocalizacion,
apertura de mapas, croquis, camara, galeria, dialogs de conductores/vehiculos/
personas, cancelacion y finalizacion transaccional mediante
`ReportController.finalize` y `ReportRepository.finalizeReport`. No se agregaron
dependencias, rutas, backend, sincronizacion ni cambios de esquema SQLite.

El wizard incorpora indicador permanente `Paso X de 6` con porcentaje calculado
desde el paso actual, tarjetas de paso con icono/titulo/descripcion, botones
`Anterior`/`Siguiente`, y `Finalizar informe` + `Cancelar` en el ultimo paso.
`Siguiente` valida solo el paso visible; `Anterior` no valida; `Finalizar
informe` identifica el primer paso invalido antes de conservar la misma logica
de guardado. Los datos se mantienen al cambiar de paso porque el estado completo
permanece en el `State` padre.

Validaciones ejecutadas:

- `dart format .`: vuelve a fallar por residuos existentes dentro de `build/`,
  igual que estaba documentado previamente.
- `dart format lib test`: correcto, 55 archivos revisados, 1 archivo formateado.
- `flutter analyze`: sin issues.
- `flutter test`: 57 tests pasaron. Persisten advertencias Helvetica/Unicode del
  servicio PDF ya conocidas y no relacionadas con este cambio.

# Estado actual — Gestion de policias redisenada, release funcional condicionado

## Actualizacion 2026-09-05 — Gestion de policias

Se rediseno el modulo ADMIN de gestion de policias tomando como referencia dos
capturas provistas por el usuario. El cambio fue acotado a UI/UX en
`lib/features/officers/officer_management_page.dart`: listado compacto con
encabezado, conteo dinamico, tarjetas resumidas, badge de estado y accion unica
`Ver`; las acciones administrativas `Editar`, `Restablecer contrasena` y
`Activar/Desactivar usuario` pasaron a una nueva vista de detalle de solo
lectura dentro del mismo modulo.

Se preservo el funcionamiento existente: alta de policias, formulario de
edicion, restablecimiento de contrasena, confirmacion de activacion/
desactivacion, refresh mediante el controller, validaciones, repositorio,
transacciones SQLite y modelos. No se agregaron dependencias, rutas globales,
backend, sincronizacion ni cambios de esquema.

Validaciones ejecutadas:

- `dart format .`: vuelve a fallar por residuos existentes dentro de `build/`,
  igual que en la Fase 14 documentada.
- `dart format lib test`: correcto, 55 archivos revisados.
- `flutter analyze`: sin issues.
- `flutter test test/app_startup_test.dart`: 5 tests pasaron, incluyendo el
  nuevo flujo que verifica que el listado solo expone `Ver` y que las acciones
  administrativas aparecen en el detalle.
- `flutter test`: 57 tests pasaron. Persisten advertencias Helvetica/Unicode del
  servicio PDF ya conocidas y no relacionadas con este cambio.

# Estado actual — Dashboard ADMIN rediseñado, release funcional condicionado

## Actualizacion 2026-09-05 — Dashboard ADMIN

Se rediseño la pantalla principal del Administrador tomando como referencia una
captura visual provista por el usuario. El cambio fue acotado a UI en
`lib/features/dashboard/dashboard_placeholder_page.dart`: bienvenida con usuario
y badge de rol, tarjetas de metricas en grilla, seccion "Resumen rapido" con
fecha seleccionable, tarjetas de resumen, banner informativo y acciones
principales destacadas.

Se preservo la arquitectura existente: `DashboardController`, `ReportRepository`,
consultas SQLite, refresh, logout y navegacion a consultas/gestion de policias.
No se agregaron dependencias, rutas, backend, sincronizacion ni cambios de
esquema.

Validaciones ejecutadas:

- `dart format lib test`: correcto, 55 archivos revisados, 0 cambios finales.
- `flutter analyze`: sin issues.
- `flutter test`: 56 tests pasaron. Persisten advertencias Helvetica/Unicode del
  servicio PDF ya conocidas y no relacionadas con este cambio.

Nota: `dart format .` sigue fallando si recorre residuos dentro de `build/`, tal
como ya estaba documentado en Fase 14. Para esta intervencion se formatearon las
fuentes versionadas (`lib` y `test`) sin limpiar artefactos de build.

# Estado actual — Fase 14: APK release generado, entrega condicionada

## Etapa y resultado

Fase 14 — Release y APK ejecutada el 2026-09-05, exclusivamente sobre
empaquetado, configuracion Android, seguridad y validacion. Sin funcionalidades
nuevas, sin cambios en lib/, SQLite v3 ni decisiones consolidadas.

APK release instalable generado y probado en emulador Android 15. No se declara
la entrega funcional completa: PDF/QR no esta accesible desde UI y falta el flujo
de compartir/guardar/imprimir. La afirmacion de integracion PDF de Fase 13 se
corrige con la revision de codigo y la prueba de release.

## Version y artefacto

- Version: **1.0.0**. Build number: **1** (`pubspec.yaml`: `1.0.0+1`).
- Nombre visible: **ACC Transito**.
- Application ID conservado: `com.example.app_acc_transito`.
- APK: **app-release.apk**, universal ARMv7 / ARM64 / x86_64.
- Ruta: `C:/Users/Desktop/Desktop/projects/app_acc_transito/build/app/outputs/flutter-apk/app-release.apk`.
- Tamano: 55 027 051 bytes (52.5 MiB).
- SHA256: `7988934A61C63B7F85B2332DC31AFB22ECEDB0C2AD332950D7E0A702C4941E3C`.
- Android minimo 7 / API 24; target y compile API 36.
- Comando: `flutter build apk --release --no-pub --build-name=1.0.0 --build-number=1 --obfuscate --split-debug-info=.release-private/symbols/1.0.0+1`.
- Ejecutado mediante `scripts/package_release.ps1`; el script aplica un mapeo
  temporal del registrador generado a URI de paquete. Para reproducir desde cero,
  usar `scripts/build_release.ps1`, no el comando Flutter aislado.
- Firma release RSA 3072 dedicada, verificada con apksigner, esquema v2.
- Certificado SHA256: `c128cf8762bc52a4df3fb226bcc3a0c6537c39c628980053bd3928ef0f841b55`.
- No depurable: verificado con manifiesto y `run-as` rechazado por Android.

## Cambios de Fase 14

- Firma debug sustituida por firma release privada; build falla si falta su
  configuracion. Clave fuera del repositorio y propiedades excluidas de Git.
- Icono Android invalido corregido, legacy y adaptativo usando copia exacta del
  logo institucional. Asset Flutter original preservado.
- Nombre visible alineado con la aplicacion.
- Backup Android y HTTP claro deshabilitados; permisos revisados; GPS/camara
  opcionales para instalacion; query geo para apertura de mapas.
- Dependencias Java de tests no usados y viewBinding retirados; no dependencias
  nuevas. Lockfile conservado.
- Cambios Android que ya existian al iniciar preservados.
- Script `scripts/build_release.ps1` y plantilla `android/key.properties.example`.
- `scripts/package_release.ps1` evita que Flutter incluya la ruta local del
  registrador generado; restaura package_config.json al terminar. Ofuscacion y
  simbolos separados bajo `.release-private/symbols/1.0.0+1`. Verificacion de las
  tres bibliotecas AOT finales: sin URI de desarrollo ni DWARF.
- Revision de lib/ y Android sin admin/admin, contrasenas precargadas, logs
  sensibles ni rutas de desarrollo en fuentes de produccion. APK sin bases de
  datos precargadas, fixtures, keystore ni propiedades privadas.

## Controles ejecutados

| Control | Resultado |
|---|---|
| `dart format .` | 55 archivos, 0 cambios tras limpiar build |
| `flutter analyze` | Sin issues |
| `flutter test` | 56 tests pasaron |
| Analyze y test tras clean con `--no-pub` | Sin issues / 56 pasaron |
| `flutter build apk --release --no-pub --build-name=1.0.0 --build-number=1 --obfuscate --split-debug-info=.release-private/symbols/1.0.0+1` | Correcto, 54.8 s |
| `apksigner verify --verbose --print-certs` | Firma valida y distinta de debug |
| `aapt dump badging` | Version, API, nombre y tres ABI correctos |
| `adb install` en emulador nuevo | Success |
| SQLite real del APK | integrity_check=ok, v3, sin errores FK |
| Logcat AndroidRuntime:E / flutter:E | Sin errores capturados |
| `git diff --check` | Sin errores de whitespace |

Las pruebas unitarias/persistencia/widgets conservan cobertura de roles, hash,
transacciones/rollback, migraciones, correlativo anual/no reutilizacion, relaciones,
soft delete, dashboard, QR y generacion PDF. No equivalen a pruebas release de
servicios de dispositivo.

## Validacion del APK release

Emulador nuevo `TransitoReleasePhase14`, Android 15 / API 35, x86_64, resolucion
720x1280, densidad 240. No se reemplazo ni borro la instalacion del AVD anterior.
Datos sinteticos creados por UI solo dentro del emulador; no incluidos en APK.

| Flujo | Resultado release |
|---|---|
| Instalacion limpia y arranque | Correctos; muestra Crear primer Administrador |
| Primer Admin | Creado mediante UI; luego muestra login |
| Reapertura | Force-stop + arranque solicita login repetidamente |
| Login Admin y POLICE | Ambos correctos |
| Registro de policia | Correcto desde Admin |
| Dashboard | Vacio, un informe y cero tras inactivar/actualizar |
| Finalizacion | Formulario incompleto rechazado; completo guarda `2026-000001` |
| Inmutabilidad | Detalle en modo lectura |
| Persistencia | Tras reiniciar, Admin consulta informe, coordenadas y fotografia |
| Correlativo | `2026-000001` real; tras inactivar, MAX+1=2 en SQLite |
| GPS | Permiso concedido y coordenadas simuladas obtenidas |
| Croquis | Tiles OSM visibles, captura PNG y ruta persistente |
| Camara | Permiso, captura, confirmacion, miniatura y archivo persistente |
| Galeria | Selector Android, seleccion de dos imagenes y miniaturas |
| Cancelacion | Formulario con galeria descartado; BD sigue con un solo informe |
| Soft delete | Solo Admin en UI; informe oculto tambien a POLICE |
| Conservacion | SQLite mantiene estado=0 y fotografia relacionada; JPG y PNG existen |
| PDF/QR/compartir | Bloqueado: generador solo en servicio/controlador, sin acceso UI |

La inspeccion SQLite se hizo por adb root **del emulador** despues de probar los
flujos UI; la aplicacion siguio siendo release no depurable. Se devolvio adb a
modo no root. No se modificaron datos mediante SQL. La no reutilizacion tras
crear un segundo informe y el cambio de gestion estan cubiertos por tests, pero
no se ejecutaron como segundo flujo completo en este APK.

El recorrido funcional completo anterior se hizo con el primer APK release
firmado. El APK final agrega solamente endurecimiento de empaquetado (URI del
registrador, ofuscacion y simbolos externos). Su instalacion como actualizacion
en el emulador conservo la BD y volvio a mostrar login. Analyze y 56 tests pasaron
nuevamente. No se repitio todo el recorrido funcional sobre el binario final.

Durante la sesion aparecio un Samsung SM-A556E / Android 16 / API 36 sin la app.
Se instalo release y luego se actualizo al APK final: ambos arrancaron en Crear
primer Administrador. No se crearon cuentas de prueba en el telefono.

Evidencias: `docs/release-evidence/` (13 PNG, SQLite, firma y log de errores).
Capturas 01-11: primer release; 12-13: artefacto final en Samsung y emulador.
Registro tecnico/reproduccion/custodia: `docs/RELEASE_1.0.0_1.md`.

## Problemas y pendientes

1. **Bloqueo funcional de entrega:** `buildReadablePdf` no tiene llamada desde UI;
   no existe flujo de visualizar, guardar, imprimir o compartir PDF. El generador
   es parcial frente al Word oficial (omite relacionados, fotos, GPS y croquis).
   No se agregaron estas funcionalidades en Fase 14.
2. PDF emite advertencias Helvetica sin soporte Unicode; validacion visual con
   documento oficial y lectura QR desde PDF final pendientes.
3. Pendiente telefono real: GPS real, permisos denegados/permanentes, GPS apagado,
   fallo de cartografia, apertura externa de mapas y variaciones de camara/galeria.
4. Dashboard al volver de inactivar puede conservar cifras previas hasta pulsar
   Actualizar; la consulta actualizada excluye correctamente los inactivos.
5. Primer `dart format .` fallo por residuos en build; `flutter clean` lo resolvio.
6. En Windows `flutter pub get --enforce-lockfile` resolvio dependencias pero
   reporto falta de symlinks para escritorio. Analyze/test/build Android posteriores
   con `--no-pub` correctos. Para el script desde cero habilitar soporte de symlinks.
7. Advertencias no bloqueantes de futura compatibilidad Gradle/AGP/Kotlin y XML
   del SDK; versiones registradas sin actualizaciones ajenas al alcance.
   Android Studio aparecio durante la sesion y Flutter eligio JDK 25, causando
   un build fallido. Se fijo `flutter config --jdk-dir` al JDK 17 de JAVA_HOME;
   la reconstruccion final paso. La ruta local del registrador AOT se detecto y
   elimino mediante el script de empaquetado, no editando el binario.
8. Custodiar y respaldar de forma privada el keystore y `android/key.properties`
   para futuras actualizaciones; no distribuirlos junto al APK.

## Informacion para manual (sin generar el manual)

- Instalacion Android API 24+, nombre ACC Transito e icono institucional.
- Primera configuracion crea Admin; no hay credenciales por defecto.
- Login en cada inicio; Admin registra policias y restablece contrasenas.
- Sin borradores; cancelar descarta; finalizar asigna caso y deja solo lectura.
- GPS es opcional; cartografia requiere internet; BD y archivos permanecen locales.
- Permisos de ubicacion/camara y selector de galeria; evidencias por categorias.
- Admin inactiva; no hay reactivacion ni eliminacion fisica; actualizar dashboard.
- No presentar PDF/compartir como funcionales hasta resolver los bloqueos.
- Desinstalar/borrar datos elimina almacenamiento local; no hay sincronizacion ni
  recuperacion cloud. Instalaciones futuras requieren conservar la misma firma.

## Siguiente fase

**Fase 15 — Documentacion/manual.** Insumos tecnicos y evidencias disponibles.
APK listo para documentar el estado real y realizar validacion adicional, pero
**no listo para entrega funcional definitiva** hasta resolver bloqueos y pendientes.
No se genero el manual completo ni se modifico `docs/DECISIONS.md`.
