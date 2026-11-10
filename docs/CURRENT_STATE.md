## Actualización 2026-11-09 — Formulario compatible con Supabase y ensayo real

Proyecto app-acc-transito-defensa-ensayo reanudado, ACTIVE_HEALTHY. Aplicada
migración 20261110020445_formulario_catalogo_naturaleza: la RPC privada admite
las doce naturalezas nuevas y las nueve anteriores para APK instaladas/reintentos.
Unidad, opción/nombre de denunciante, descripción revisada, categoría y Observación
conservan sus columnas/contratos. Sin cambios de RLS, funciones públicas,
Storage ni Edge Functions. LOCAL/SQLite permanece separado de ONLINE.

Verificación: **147 pruebas Flutter correctas**, análisis sin incidencias y formato
lib/test correcto. PostgreSQL 17.11 temporal separado: cuatro migraciones desde
cero, regresiones SQL 09/10/12, catálogo completo y dos carreras concurrentes
correctas. Auth/Storage simulados en ese harness por fallo de Docker. Cloud real:
prueba SQL de RPC/lectura, catálogo completo, negativos, replay y RLS en ROLLBACK.
Antes del ensayo dirigido, huellas de informes/ledger/contadores/RPC pública iguales.

Ensayo real posterior: actualización por adb install -r de Samsung SM-A556E
(Android 16) y emulador TransitoReleasePhase14, conservando firma debug, datos y
sesiones. POLICE B en teléfono; ADMIN ingresado por el usuario en emulador.
Tras un fallo inicial del dictado, se corrigió la selección de español local
mediante consulta de idiomas instalados (Android 13+) y es-ES en Android 12 o
cuando el motor no implementa dicha consulta. Sin reconocimiento remoto.
El usuario confirmó voz real exitosa; se verificó la edición posterior del texto.

Finalizado **2026-000004**, lugar ENSAYO-FORM-20261109-FICTICIO, con EPI 3,
OTROS HECHOS DE TRANSITO, OTRO con nombre, texto dictado/editado, categoría Otros
y observación. ADMIN lo recuperó desde Supabase tras Actualizar y comprobó todos
los campos en el detalle; generó vista previa PDF correcta de tres páginas.
Total Cloud: 15 informes y operaciones (14 previos más uno nuevo), un conductor,
correlativo 2026 = 4. Huellas de los 14 informes/operaciones históricos intactas.
Como el otro POLICE, consulta SQL/RLS al caso nuevo y su conductor: cero filas.
Se conserva el informe de ensayo activo; no hubo eliminación ni inactivación.

Release 1.0.0+1 firmada, minSdk 24/target 36, sin debuggable, configurada solo
con URL/clave publicable del proyecto. Empaquetador admite -DartDefineFromFile.
APK: `docs/manual/entrega/app_transito_defensa_actualizada.apk`, anterior conservada.
SHA256: 91EBF06E173BBBB1C6DC3D5756F84A86C1181FD51554B4A80AEA536824643A48.
La release fue compilada/verificada; el ensayo instalado fue debug de igual código
funcional. No se reemplazó la firma debug existente ni se borraron datos.

Se mantiene consulta/refresco, sin Realtime nuevo. No se repitieron cargas de
fotos/croquis/PDF privados ni concurrencia Edge; HTTP 546 Memory permanece abierto.
La vista PDF probada se generó localmente desde datos remotos, sin subirla.
Evidencia y límites: `supabase/tests/form_sync_verification.md`; capturas en
%TEMP%/transito-form-evidence-20261109. Bitácora Notion pendiente, sin destino
autorizado. Sin commit ni push; trabajo previo y supabase/.temp preservados.

---

## Actualización 2026-11-09 — Naturaleza del hecho

El selector Naturaleza pasa a Naturaleza del hecho y reemplaza sus nueve opciones
por las doce de la captura del usuario, en este orden: ARROLLAMIENTO, ATRICCION,
ATROPELLO, CAIDA, CHOQUE, COLISION, DESLIZAMIENTO, EMBARRANCAMIENTO,
ENCUNETAMIENTO, OTROS HECHOS DE TRANSITO, SUMERSION y VUELCO.
Se respeta la escritura de la referencia. La etiqueta se actualiza también en
el detalle y los nuevos PDF. Los valores de informes finalizados y los PDF ya
exportados no se alteran; no hay migraciones ni cambios de servicios remotos.

Verificación: 141 pruebas correctas, incluidas selección de las doce opciones,
persistencia en el envío y legibilidad a 320/360/412 px con texto ampliado.
Análisis sin incidencias, formato lib/test y git diff --check correctos.
El bloqueo previo de dart format . por residuos de Gradle en build/ permanece.
No se regeneró la APK después de este ajuste. Cambios previos preservados.

---

## Actualización 2026-11-09 — Categoría y observación del conductor

En Agregar/Revisar conductor, Categoría es un selector obligatorio con A, B, C,
M, P, T y Otros. Se conserva la selección al revisar un conductor en memoria.
La etiqueta Condición de entrega pasa a Observación, también en detalle y en
los PDF generados posteriormente; sigue siendo texto opcional y usa el campo
existente condicionEntrega. No hay cambios de esquema, dependencias, contratos
remotos ni contenido persistido; los PDF ya exportados se conservan.

Verificación: 141 pruebas Flutter correctas y análisis sin incidencias. El flujo
prueba las siete categorías, obligatoriedad, revisión y envío de la observación.
Formato lib/test correcto; dart format . sigue bloqueado por una ruta residual
de Gradle en build/. Diff sin errores de espacios. No se regeneró ni instaló
la APK después de este ajuste; se preservan los cambios previos de esta sesión.

---

## Actualización 2026-11-09 — Dictado editable en Descripción

El paso de descripción permite dictar en español por fragmentos, terminar o
cancelar el dictado. El resultado se añade al texto existente y queda editable
para revisión; no reescribe los hechos con IA ni finaliza automáticamente.
Se conserva únicamente el texto mediante el contrato existente, sin archivos
de audio, cambios de esquema, dependencias nuevas ni servicios Cloud.

Implementación: widget DescriptionDictationField, servicio Dart por MethodChannel
y reconocimiento Android estrictamente local mediante createOnDeviceSpeechRecognizer.
Requiere Android 12/API 31 o superior y motor/modelo local compatible con español
(es-BO). Sin soporte, permisos o reconocimiento, informa el error y conserva
la escritura manual. Solicita RECORD_AUDIO al pulsar dictado; cancela al salir
del campo o pasar la aplicación a segundo plano. Tiempo máximo de espera: 60 s.
No existe fallback a reconocimiento remoto ni subida de audios pregrabados.

Verificación: 141 pruebas Flutter correctas; análisis sin incidencias y formato
lib/test correcto. Pruebas con servicio simulado de texto añadido, edición,
cancelación con resultado tardío, permiso denegado y reconocimiento no disponible.
Pendiente validación de micrófono y modelos de idioma en dispositivo físico;
las pruebas simuladas no acreditan la disponibilidad del motor del teléfono.
Compilación Android debug correcta: build/app/outputs/flutter-apk/app-debug.apk.
Sin instalación ni prueba de voz en teléfono; APK sin configuración remota.
Se preservan los dos cambios del formulario previos de esta sesión.

---

## Actualización 2026-11-09 — Menú de denunciante

El paso Denunciante incorpora selección obligatoria: BOL 110, DE OFICIO,
DENUNCIANTE y OTRO. Las dos últimas muestran un nombre obligatorio.
Se conserva la opción y, cuando corresponde, el nombre en el campo textual
existente (`DENUNCIANTE: nombre` u `OTRO: nombre`); las otras opciones se guardan
literalmente. El nombre oculto no se envía. Documento opcional y contacto
obligatorio mantienen sus reglas. Sin cambios de esquema, dependencias,
informes finalizados ni servicios remotos.

Verificación: selección de las cuatro opciones, visibilidad condicional,
validación de nombre y envío final comprobados en las pruebas del formulario.
`flutter analyze --no-pub` sin incidencias; formato de lib/test correcto.

---

## Actualización 2026-11-09 — Selector de unidad del informe

En Datos generales, el campo textual EPI se sustituye por el selector obligatorio
«Unidad a la que pertenece», con las 15 opciones proporcionadas por el usuario:
EPI 3, EPI 5, EPI 6, EPI 8, EPI 9, EPI 11, RP 110, TRANSITO, UPAR DELTA,
PAC, DIPROVE, POFOMA, INTERPOL, BOMBEROS y BATALLON DE SEGURIDAD FISICA.
El formulario compartido conserva el valor textual en `epi`, sin migraciones,
cambios de dependencias ni alteración de informes finalizados. No se modifican
perfiles policiales, PDF/QR ni recursos remotos.

Verificación: `flutter analyze --no-pub` sin incidencias y pruebas del formulario
correctas, incluido envío de la unidad seleccionada y Naturaleza con texto ampliado.
`dart format lib test` correcto; `dart format .` mantiene el error preexistente
por una ruta residual de Gradle dentro de `build/`. Sin APK ni instalación nueva.

---

# Estado actual — Intervenciones 21/22: ensayo Cloud en dos clientes

## Actualización 2026-11-01 — DOS CLIENTES VALIDADO, sin adjuntos

Se actualizó el paquete existente com.example.app_acc_transito, versión 1.0.0+1,
mediante adb install -r: release en emulator-5554 (Android 15/API 35) y debug en
Samsung SM-A556E R5CX40ENFZH (Android 16/API 36). Se compararon los certificados
efectivos con cada instalación histórica antes de actualizar. Ambas APK se
compilaron con configuración pública mediante --dart-define, sin incorporar
valores al código o repositorio. No hubo desinstalación, reset ni limpieza de
datos. Por decisión expresa, no se verificó funcionalmente el historial LOCAL:
sus datos eran sintéticos descartables y las contraseñas se desconocían.

Proyecto único del ensayo: app-acc-transito-defensa-ensayo. Previamente, con
autorización separada, se restablecieron solo las contraseñas de las tres cuentas
sintéticas existentes mediante Auth Admin desde un procedimiento temporal local
externo al repositorio. Se verificaron UID, correos, roles y relaciones sin cambios;
no se incorporaron claves administrativas, contraseñas o sesiones al cliente.

Resultado del ensayo dirigido mediante las aplicaciones:

- POLICE A, emulador: finalizó 2026-000001 sin adjuntos y confirmó persistencia
  al regresar al listado y pulsar Actualizar.
- ADMIN, Samsung: consultó ese informe creado desde el otro dispositivo.
- POLICE B, Samsung: listado sin informes ajenos; una consulta dirigida al ID 12
  de A mediante la API pública y la sesión B devolvió cero filas. Se ejecutó
  desde el SDK de la APK debug con conexión temporal de depuración, sin extraer
  JWT ni usar una clave administrativa. Es evidencia real de esa lectura RLS,
  distinta de las pruebas con mocks de la intervención 20.
- POLICE B finalizó 2026-000002 sin adjuntos y confirmó persistencia propia.
- La misma cuenta ADMIN inició sesión en ambos clientes y, tras Actualizar,
  ambos mostraron los informes A y B. Total observado: 13 informes activos,
  correspondientes a 11 previos más exactamente dos nuevos del ensayo.
- Desconexión solo en emulador: la consulta mostró un error de carga; al restaurar
  Wi-Fi/datos a sus estados anteriores y pulsar Reintentar recuperó ambos informes.
  No se realizaron escrituras durante la desconexión.

No se cambiaron Flutter, SQL, RLS, Edge Functions ni Storage durante el ensayo.
La actualización comprobada es por consulta/refresco, no por WebSocket o push.
Fotografías, croquis, PDF y archivos privados reales siguen sin validación en dos
clientes. HTTP 546 Memory permanece abierto; no se repitió la concurrencia Edge.
No se realizaron pruebas de carga ni validación productiva institucional.
Las herramientas y capturas saneadas de estas intervenciones permanecen fuera
del repositorio; los dos auxiliares preexistentes supabase/.temp se conservan locales.
Antes del commit se repitieron flutter analyze --no-pub (sin incidencias) y
flutter test --no-pub (136 pruebas correctas), sin nuevas operaciones Cloud.

---

# Estado histórico — Intervención 20: cliente para DEFENSA EN LÍNEA

## Actualización 2026-10-29 — Implementado localmente, pendiente ensayo Cloud

Baseline verificado: 34e74f99bce6f7ab55fe122854ba068b2b342314. Se autorizó
expresamente esta entrada documental durante la intervención. No se modifican
DECISIONS ni decisiones de negocio. LOCAL conserva SQLite v3, su login,
correlativos, formulario, consultas, archivos y PDF/QR; ONLINE no construye
AppDatabase ni escribe informes en SQLite. No hay fallback, doble escritura,
importación ni sincronización de bases históricas.

Al iniciar se elige LOCAL o DEFENSA EN LÍNEA. Supabase se inicializa solo al
elegir ONLINE, mediante un único cliente. Sin configuración pública válida se
muestra un error y LOCAL permanece disponible. Configuración por --dart-define:
SUPABASE_URL (HTTPS) y SUPABASE_PUBLISHABLE_KEY (publicable o anon). No se
incorporaron valores reales ni claves privilegiadas. Las nuevas dependencias
se fijaron: supabase_flutter 2.18.3 (SDK), uuid 4.6.0 (operaciones) y http 1.6.0
(clasificación de fallos de transporte y pruebas HTTP sin red); lock actualizado.

### Componentes y comportamiento

- app/mode_selection.dart, app/app.dart y main.dart: selección y DI por modalidad.
- features/auth: adaptador remoto del contrato existente y capacidad adicional
  de sesión ONLINE; correo/contraseña, restauración persistente del SDK, salida,
  expiración y errores de renovación. Roles y perfiles activos se leen de
  usuarios/policias con RLS; nunca de user_metadata ni de un selector de roles.
- data/remote/online_report_repository.dart: mismas entidades ReportRecord,
  listados propios/consolidados, relaciones, filtros, dashboard y finalización
  mediante finalizar_informe(operation_id, payload). Sin INSERT/UPDATE directo
  ni asignación de correlativos en el teléfono. ADMIN observa autor histórico,
  gestión, caso, estado activo y fecha de registro.
- Actualización al entrar/reabrir, al reanudar una pantalla visible, después de
  finalizar y mediante Actualizar. Sin Realtime push ni temporizador periódico.
- Doble toque comparte una sola finalización; payload JSON y UUID se congelan.
  Tras un timeout se admite un único replay automático exacto (dos intentos
  totales por acción). La recuperación manual conserva la misma intención;
  no se reintentan automáticamente validaciones, permisos ni HTTP 546.
- data/remote/online_file_service.dart: reserva/carga sin overwrite/verificación
  y vínculo usando las RPC existentes; descarga autenticada a caché privada,
  sin URLs públicas. Operaciones de archivo serializadas por cliente. Máximo
  técnico del contrato: 12 fotos y un croquis, 5 MiB por imagen, 10 MiB por PDF.
  Una verificación fallida no se invoca otra vez: se consulta su reserva. Un
  archivo no confirmado bloquea la finalización sin omitirlo.
- PDF/QR usan ownerSnapshot de ESE informe remoto (nombre, grado, placa y unidad),
  no el perfil actual. El autor puede guardar y registrar el PDF con reservar_archivo
  y registrar_pdf; ADMIN lo guarda en su dispositivo. Si falla el registro remoto,
  se informa que la copia local existe y que el resultado remoto no se confirmó.
- Gestión remota de cuentas e inactivación quedan deshabilitadas y señaladas:
  no hay contrato servidor autorizado para esas escrituras. No se usa signup.

### Evidencia del contrato de recuperación

Revisión de 20261023030451_finalize_report_rpc.sql: clave UUID primaria en
operaciones_finalizacion, INSERT ON CONFLICT y SELECT FOR UPDATE (líneas 91–100),
comparación de auth_uid/payload, retorno del resultado existente y actualización
del resultado en la misma llamada transaccional (línea 226). Las tablas privadas
carecen de CRUD cliente (línea 23). La fachada adicional de Storage en la migración
12 conserva la implementación y valida autor/contenido/archivos antes de vincular.
finalization_rpc.sql contiene pruebas de replay perdido, conflicto, actor ajeno
y rollback de hijos/contador; run_finalization_tests.ps1 contiene cuatro escenarios
de concurrencia con espera de bloqueo observada por el harness. Se leyeron esas
pruebas y el SQL; NO se ejecutó una BD SQL en esta intervención. Los mocks nuevos
validan el comportamiento Flutter, no demuestran ejecución del SQL ni RLS desplegada.

### Validación y límites

Flutter 3.47.2 / Dart 3.13.2. flutter analyze --no-pub: sin incidencias.
flutter test --no-pub: 136 pruebas correctas, incluidas 29 nuevas de ONLINE.
Cubren SDK con HTTP simulado, DI con SQLite que falla si se toca, sesión/roles,
lecturas de tres clientes simulados, refresco/lifecycle, expiración, offline,
respuesta perdida/replay/doble toque, snapshots distintos por informe y archivos
serializados. Se corrigieron fallos intermedios de pruebas/rutas sin AuthScope,
ajuste del selector de policías a nombres largos y sincronización del scroll
en el test de navegación. Compilación APK debug local correcta, sin configuración
Cloud. No sustituye el APK release de entrega ni constituye ensayo en teléfonos.

dart format lib test: 83 archivos formateados. dart format . reproduce el fallo
preexistente de una ruta residual de Gradle bajo build/flutter_plugin_android_lifecycle.
No se borraron builds ni se actualizaron Gradle/AGP/Kotlin/SDK. La compilación emitió
avisos de versiones existentes. Revisión de diff, archivos nuevos y patrones de
credenciales: sin secretos detectados. No se editan SQL, Edge Functions, Android,
.gitignore ni los dos auxiliares preexistentes supabase/.temp, cuyo contenido no se leyó.

La recuperación pendiente vive en memoria por autor durante la sesión: no resiste
cierre del proceso. Mientras está incierta se bloquea editar/descartar esa intención
o iniciar otra, y se indica no cerrar la aplicación. Reservas o verificaciones
inciertas pueden requerir revisión posterior; no hay limpieza remota automática.
El contrato de reserva no conserva descripciones opcionales de fotografías: se
rechazan explícitamente antes de cargar, en lugar de perderlas silenciosamente.

No se realizó ninguna llamada al proyecto Cloud, lectura remota, carga real,
prueba física, cambio de Auth/RLS/Storage/Realtime, despliegue, commit ni push.
HTTP 546 WORKER_RESOURCE_LIMIT Memory sigue ABIERTO; no se repitió la prueba de
concurrencia Edge ni se afirma corregido. No se evaluó tamaño real del paquete.
Pendientes de autorización separada: ensayo POLICE A registra/consulta, ADMIN ve
A/B desde otro teléfono, POLICE B no accede a A, el mismo ADMIN accede desde un
tercer dispositivo, errores de red/replay y archivos/PDF privados reales. Antes
del ensayo hay que configurar únicamente URL y clave pública del cliente y
verificar la compatibilidad del despliegue existente, sin presumirla por los mocks.

---

# Estado actual — Visualización de Naturaleza corregida

## Actualización 2026-09-16 — Texto completo en Naturaleza

Corregido el recorte del valor seleccionado en el primer paso del informe.
`DropdownButtonFormField` deja de usar altura compacta (`isDense: false`);
mantiene altura variable para mostrar completas las opciones de varias líneas.
Se conservan las nueve opciones, obligatoriedad, selección y persistencia.
Sin cambios de esquema, dependencias ni reglas del informe.

La prueba de regresión reprodujo el fallo anterior: el texto de «Colisión»
recibía 8 px de altura cuando necesitaba 24 px. Las nuevas pruebas comprueban
la altura de todas las líneas y su posición dentro del campo antes y después
de enfocar Lugar, para opciones cortas/largas a 320/360/412 px y escalas de
texto 1/1,5/2. Capturas de widgets revisadas en
`%TEMP%/transito-naturaleza-20260916/`. Suite completa: **103 pruebas correctas**;
`flutter analyze` sin incidencias. `dart format lib test`: 69 archivos correctos;
`dart format .` mantiene el fallo previo de rutas residuales de Gradle en `build/`.
La observación anterior de recorte de Naturaleza queda resuelta en el código;
las comprobaciones de GPS y dispositivo físico siguen pendientes.

Regenerado `docs/manual/entrega/app_transito.apk` con la corrección mediante
`scripts/package_release.ps1`, versión 1.0.0+1 y firma release verificada con
`apksigner`. SHA256:
`2757F01AE3FAB52AAF67EF35FF3A7D7D674553DE876B349CD850A9EBFAF6E47D`.
Esta copia reemplaza el APK de entrega del 15/09. La corrección, las pruebas y
este registro se incluyen en el commit `fix(informes): corregir recorte del texto
en naturaleza`. El APK y los archivos del manual permanecen locales según
las reglas existentes de Git.

## Actualización 2026-09-15 — APK para entrega al cliente

Generado con `scripts/package_release.ps1` y copiado como
`docs/manual/entrega/app_transito.apk`, junto al manual. Versión 1.0.0+1,
Android 7.0 o superior (minSdk 24), APK universal de 62.025.748 bytes.
Firma verificada con `apksigner verify --verbose`; variante release sin
indicador debuggable. SHA256:
`A12FA2A16929B91B1A2ED3F26C394CDD49A6CC79E167C2C15F3EA2ACEBE88F28`.
Coincide con el APK probado durante la elaboración del manual. Sin cambios
de código ni dependencias; se mantienen las validaciones y las observaciones
de dispositivo físico registradas abajo. Archivo de entrega local, excluido
de Git por las reglas existentes de `docs/`.

## Actualización 2026-09-14 — Fase 15 Manual de usuario

Manual detallado para Administrador y Policía en `docs/manual/entrega/`, en
PDF y DOCX editable: 40 capítulos, 42 páginas y 32 capturas reales de la
versión release 1.0.0+1 basada en `55305ef`. Cubre instalación, primer ADMIN,
sesión, gestión de policías, dashboard, seis pasos del informe, evidencias,
croquis, consultas, QR, PDF, compartir, imprimir, inactivación y problemas
frecuentes. Incluye las nueve naturalezas, los tres obligatorios del conductor
y la fecha/hora del registro definitivo en el QR.

Se construyó el APK con `scripts/package_release.ps1` y se instaló en un AVD
aislado API 35 (`TransitoManual20260915`, `emulator-5556`), preservando el
emulador existente. Se finalizó y exportó un informe con datos de demostración.
ZXing confirmó igualdad del QR de la app y del PDF, incluido caso y registro
definitivo con segundos. El PDF no contiene el apartado Funcionario responsable.

Verificación: `flutter analyze` sin incidencias y **100 pruebas correctas**.
`dart format lib test`: 69 archivos sin cambios; `dart format .` reproduce
el fallo previo de rutas residuales de Gradle en `build/`. Sin cambios de
código de la app, esquema ni dependencias del proyecto. Revisión visual de
las 42 páginas y comprobación del índice. Fuente, capturas y trazabilidad en
`docs/manual/VERIFICACION_MANUAL.md`; la carpeta del manual sigue excluida
por las reglas existentes de Git. Sin nuevo commit en esta fase.

Pendiente de aceptación en teléfono físico: obtención automática de GPS,
cámara, impresión y lectura con otra cámara. En este emulador la solicitud
GPS quedó pendiente; el recorrido se completó con coordenadas manuales y
croquis correcto. También se observó recorte del texto de Naturaleza después
de enfocar Lugar, aunque el listado y la persistencia fueron correctos.
Ambas observaciones están registradas en la verificación del manual.

# Historial — QR del informe unificado en app y PDF

## Actualización 2026-09-14 — QR de la vista de detalle

La visualización del QR en la app, antes de generar el PDF, usa ahora
`generateForReport` con el número de caso y `fechaCreacion` del informe visible.
Su contenido coincide exactamente con el QR del PDF: datos del policía,
correlativo completo y fecha/hora del registro definitivo con segundos.
El QR se actualiza si cambian el caso o la fecha, incluso con el mismo policía.
Se conserva la presentación de la sección de identidad de la app.

Verificación: `flutter analyze` sin incidencias y **100 pruebas correctas** con
`flutter test --dart-define=UI_REVIEW_OUTPUT=<ruta temporal>/app.png`. La prueba
del detalle compara el contenido del QR con el PDF generado para el mismo
informe. Nueva prueba de actualización por caso y fecha; permanecen correctas
las pruebas de consulta a 320/360/412/800 px con texto ampliado. ZXing decodificó
el QR de una captura de widgets y confirmó caso, fecha y datos con ñ/tildes;
captura revisada visualmente en `%TEMP%/transito-qr-20260914/app-qr.png`.

`dart format lib test` correcto (69 archivos); `dart format .` mantiene el fallo
preexistente por residuos de Gradle en `build/`. Sin cambios de persistencia,
dependencias ni generación del PDF en esta intervención. Se preservan todos
los ajustes previos de la sesión. Sin APK nuevo ni escaneo en teléfono real.
DECISIONS extiende al QR de la app el contenido aprobado. La siguiente fase
planificada sigue siendo Fase 15 (manual).

# Historial — PDF sin apartado de funcionario y QR del informe

## Actualización 2026-09-14 — Identificación del informe en el QR

- Retirado del PDF el título y la tabla «Funcionario responsable». Se conserva
  el QR institucional y el espacio de firma; la consulta en pantalla no cambió.
- El QR del PDF agrega el número de caso completo (`AAAA-NNNNNN`) y la fecha y
  hora del registro definitivo (`fechaCreacion`), con segundos. El usuario
  confirmó que no corresponde usar la hora de generación de cada archivo.
  La fecha guardada se conserva; si está en UTC, se indica expresamente.
- La información existente del policía continúa dentro del QR. Su generación
  institucional sin datos del informe sigue disponible para la vista de detalle.
- QR ampliado de 140 a 160 puntos, margen blanco de 12 puntos y corrección de
  errores media. QR y firma permanecen juntos al paginar.
- Sin cambios de SQLite, dependencias de la app, correlativos, guardado,
  compartir o impresión. Los PDF previamente exportados no se reescriben;
  el cambio se aplica al volver a generarlos. DECISIONS actualizado con lo aprobado.

Verificación: `flutter analyze` sin incidencias y **99 pruebas correctas** con
`flutter test --dart-define=PDF_REVIEW_OUTPUT=<ruta temporal>/informe.pdf`.
Incluyen fecha/caso del registro, segundos, UTC, caso vacío y conservación del
contenido del QR al regenerar. Se renderizaron siete PDF sintéticos (36 páginas,
entre 2 y 14 por documento) con Poppler y se revisó la disposición de las páginas.
ZXing leyó los siete QR desde los renderizados y verificó caso, fecha/hora y
datos del policía, incluyendo ñ y tildes. Extracción con pypdf confirmó la
ausencia del apartado eliminado y la presencia del QR y la firma.

`dart format lib test` correcto (69 archivos); `dart format .` mantiene el fallo
preexistente por residuos de Gradle en `build/`. `git diff --check` correcto.
Evidencias sintéticas en `%TEMP%/transito-qr-20260914`, fuera del versionado;
ZXing se instaló únicamente en el runtime de herramientas para esta verificación.
Sin APK nuevo ni prueba de escaneo/impresión en teléfono. Se preservan los cambios
del formulario de esta misma sesión. La siguiente fase planificada sigue siendo
Fase 15 (manual).

# Historial — Naturaleza y datos obligatorios de conductores

## Actualización 2026-09-14 — Ajustes solicitados del formulario

- Paso 1: Naturaleza usa un selector obligatorio con las nueve opciones
  solicitadas, sin selección automática. Conserva el valor al cambiar de paso
  y admite etiquetas largas en teléfonos estrechos.
- Paso 5: al agregar o revisar un conductor, solo nombre completo, licencia
  y categoría son obligatorios. Edad, domicilio, zona, contactos y condición
  de entrega pueden quedar vacíos. La edad ingresada conserva su validación
  como entero no negativo. Se informa la regla en el diálogo.
- Repositorio alineado con la misma regla antes de la transacción, sin
  debilitar la validación de vehículos ni personas involucradas. El resumen
  del conductor omite contactos vacíos para evitar mostrar `null`.
- Sin cambios de esquema SQLite, dependencias, correlativos ni informes
  históricos. DECISIONS registra los dos requerimientos del usuario.

Verificación: `flutter analyze` sin incidencias; `flutter test` con **97 pruebas
correctas** (dos nuevas y ampliación del recorrido del wizard). Se comprobó
selección de las nueve opciones a 320 px, navegación y finalización a 360 px,
rechazo de obligatorios vacíos o con espacios, revisión del conductor y edad
inválida. SQLite confirma el guardado de campos opcionales vacíos, la relación
vehículo/conductor y que los intentos inválidos no persisten ni consumen caso.
`dart format lib test` correcto (69 archivos); `dart format .` mantiene el fallo
preexistente por residuos de Gradle bajo `build/`. `git diff --check` correcto.
Sin verificación en dispositivo ni APK nuevo. La siguiente fase planificada
sigue siendo Fase 15; este ajuste no genera el manual.

# Historial — Filtros de fecha validados en consultas e Inicio

## Actualización 2026-09-13 — Límites de búsqueda por fecha

Se revisaron todos los selectores de fecha: el rango Desde/Hasta de Informes
y los dos accesos de fecha de Inicio (cabecera de Resumen rápido e Informes
por fecha) comparten ahora el selector validado para ADMIN y POLICE.

- Inicio no posterior al fin; se permite buscar un mismo día y se incluye
  todo el día final, manteniendo el límite superior exclusivo de SQLite.
- Fecha máxima: hoy según el reloj local, recalculada al abrir, confirmar y
  ejecutar la consulta. Se rechazan fechas futuras también por teclado.
- Fecha mínima: el hecho más antiguo registrado, usando el mismo campo
  `fecha_hora_hecho` que las consultas. ADMIN usa el historial del dispositivo;
  POLICE usa su historial propio. La fecha de creación no se utiliza como
  límite porque excluiría hechos anteriores registrados después.
- El límite histórico se conserva al inactivar informes; estos siguen ocultos.
  Sin historial, el calendario permite únicamente hoy. Si solo hubiera fechas
  futuras heredadas, el límite se ajusta a hoy para mantener válido el selector.
- Validación adicional en el repositorio, sin SQL desde widgets. Los filtros
  permanecen accesibles para limpiarlos si una consulta devuelve error.
  Inicio ajusta una fecha previa fuera de límites al actualizar automáticamente;
  una selección explícita inválida se rechaza sin sustituir la fecha anterior.

Sin cambios de esquema, dependencias, permisos o formulario de registro.
DECISIONS incorpora las reglas de búsqueda solicitadas por el usuario.

Verificación: `flutter analyze` sin incidencias; `flutter test` con **95 pruebas
correctas** (10 nuevas). Cubren teclado/calendario, rangos invertidos, fechas
futuras y antiguas, mismo día, cierre inclusivo, límites por rol, historial
inactivo, ausencia de informes y cambio del reloj con el selector abierto.
La prueba previa que consultaba antes del primer informe ahora usa un día
sin resultados dentro del rango válido; el rechazo se cubre explícitamente.
`dart format lib test` correcto (69 archivos). `dart format .` mantiene el fallo
preexistente por residuos de Gradle en `build/`. Sin APK nuevo ni verificación
en dispositivo. La siguiente fase planificada sigue siendo Fase 15.

# Historial — Indicadores en dos columnas para todos los roles

## Actualización 2026-09-13 — Diseño de indicadores compartido

Se extendió el diseño de tarjetas compactas y dos columnas a los dos roles
existentes (ADMIN y POLICE). Administrador conserva cuatro indicadores en 2 × 2;
Policía conserva sus tres indicadores propios: activos y día en la primera
fila, mes a la izquierda de la segunda fila. El espacio restante queda vacío.
Ambos usan etiquetas completas y altura de fila adaptable al contenido.

Se retiraron las condiciones de rol que seleccionaban el diseño anterior.
Se mantienen los datos, permisos, consultas SQLite y demás secciones de Inicio.
Cambio de código limitado a `lib/features/dashboard/dashboard_placeholder_page.dart`.

Verificación: `flutter analyze` sin incidencias y `flutter test` con 85 pruebas
correctas. `dart format lib test` correcto (66 archivos); `dart format .`
mantiene el fallo preexistente por residuos de Gradle bajo `build/`.
Sin APK nuevo ni verificación en dispositivo. La siguiente fase planificada
sigue siendo Fase 15; DECISIONS no cambió.

# Historial — Indicadores ADMIN en cuadrícula 2 × 2

## Actualización 2026-09-12 — Ajuste puntual de Inicio

Las cuatro tarjetas del Administrador se distribuyen en dos columnas y dos
filas también en teléfonos: informes activos/policías activos arriba e informes
del día/informes del mes abajo. Se compactaron iconos y espacios internos y se
permite que las etiquetas completas aumenten la altura de cada fila si hace falta.
Se conservaron el resto de Inicio, el dashboard POLICE y la lógica de datos.
Cambio limitado a `lib/features/dashboard/dashboard_placeholder_page.dart`.

Verificación: `flutter analyze` sin incidencias y `flutter test` con 85 pruebas
correctas. `dart format .` sigue fallando por la ruta residual de Gradle bajo
`build/`; `dart format lib test` correcto (66 archivos, sin cambios).
No se generó un APK nuevo ni se verificó este ajuste en dispositivo.
La siguiente fase planificada sigue siendo Fase 15; DECISIONS no cambió.

# Historial — Consulta de informes y PDF rediseñados

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
