# Formulario y Supabase — verificación 2026-11-09

Proyecto existente: `app-acc-transito-defensa-ensayo` (`orodoonyalhwdtxnjmau`).
Se reanudó porque estaba inactivo; estado final `ACTIVE_HEALTHY`.
Se mantienen LOCAL/SQLite y ONLINE como modalidades separadas. ONLINE conserva
consulta al entrar/reanudar y Actualizar; no se añadió Realtime ni sincronización
offline entre SQLite y Supabase.

## Corrección aplicada

Migración local y Cloud: `20261110020445_formulario_catalogo_naturaleza.sql`.
La versión es UTC; la intervención corresponde al 09/11 en Bolivia.
La implementación privada de finalización admitía solo las nueve naturalezas
anteriores. Se amplió a las doce del nuevo formulario y se conservaron las
anteriores para APK instaladas y reintentos históricos. No se transforma el
payload ni se altera el ledger de idempotencia.

La migración verifica la huella del cuerpo original antes de reemplazarlo:
`f6dd17b9c2081939beb9410fd389ecd1`. La huella del cuerpo resultante coincide
entre el archivo local y Cloud: `9d47cda2ab129144c75cd336fe555cf6`.
No modifica columnas, funciones públicas, RLS, GRANT, Storage ni Edge Functions.

| Cambio visible | Contrato remoto conservado |
| --- | --- |
| Unidad a la que pertenece | `informes.epi` (texto) |
| Naturaleza del hecho | `informes.naturaleza` y lista validada en RPC |
| Opción y nombre de denunciante | `informes.denunciante_nombre` (opción o `OPCIÓN: nombre`) |
| Dictado corregido por el usuario | `informes.descripcion` (solo texto, sin audio) |
| Categoría seleccionada | `conductores.categoria` (texto) |
| Observación del conductor | `conductores.condicion_entrega` (texto opcional) |

## Evidencia ejecutada

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub`: **147 pruebas correctas**. Nueva regresión de cliente
  ONLINE: 15 unidades, 12 naturalezas, siete categorías, cuatro opciones de
  denunciante, nombre con tildes/ñ, texto revisado con salto de línea y observación.
  Clientes independientes simulados recuperan todos los campos; respuesta perdida
  y replay exacto no duplican el informe ni el conductor. Estos mocks no prueban RLS.
- PostgreSQL nativo **17.11**, cluster nuevo y descartable, bind solo a
  `127.0.0.1`, puerto aleatorio, contraseña efímera fuera del repositorio.
  Se verificó `data_directory` antes de crear la BD de prueba.
  Las cuatro migraciones acumuladas se aplicaron desde cero.
- Pasaron `schema_security.sql`, `finalization_rpc.sql`, `storage_security.sql`
  y `form_catalog_roundtrip.sql`. Las expectativas de catálogo históricas de 09
  se adaptaron solo en memoria para Storage 12, igual que el harness existente.
- Concurrencia con conexiones PostgreSQL independientes: dos autores/misma gestión
  reciben números distintos; misma operación/contenido recibe un solo resultado.
  Se observó la espera real por bloqueo. El cluster se detuvo y eliminó al terminar.
- **Cloud real:** RPC y lectura como `authenticated` bajo contextos de los actores
  sintéticos existentes. Se probaron las doce naturalezas, 15 unidades, siete
  categorías y cuatro denunciantes; ADMIN recuperó todos los campos, POLICE B no
  leyó cabeceras ni conductores ajenos. Valores inválidos rechazados, replay igual.
  Toda esta prueba terminó en **ROLLBACK**; no creó usuarios ni dejó informes.
  Los contextos de rol/JWT se fijaron mediante SQL: no es login Auth ni ensayo HTTP.
- Huellas antes/después iguales de todos los informes, conductores, ledger,
  contadores y definición de RPC pública. Se conservaron los **14 informes** y
  las **14 operaciones** existentes. Las secuencias técnicas identity pueden avanzar
  por las inserciones revertidas; el contador de casos no cambió.
- Historial Cloud: las tres migraciones originales y la nueva versión coinciden
  con los cuatro archivos locales. Sin `db push`, link, reset, commit ni push.
- Formato Dart de lib/test y `git diff --check` correctos. No hay formateador SQL
  disponible; revisión textual y ejecución PostgreSQL realizadas. `dart format .`
  conserva el bloqueo previo por rutas residuales de Gradle en `build/`.

Docker Desktop falló al iniciar por su endpoint local de Inference; no se reseteó
ni se borraron sus datos. Se usó el harness alternativo
`run_form_catalog_tests.mjs`; los binarios PostgreSQL y node-postgres se instalaron
solo en un directorio temporal externo. Auth/Storage de plataforma se simulan
en ese harness: no se afirma prueba HTTP ni carga privada real.

## APK

Release Android `com.example.app_acc_transito`, **1.0.0+1**, compilada con el
proyecto verificado y su clave publicable mediante archivo temporal externo.
Sin claves administrativas, tokens ni contraseñas en el repositorio o cliente.
El script de empaquetado admite ahora `-DartDefineFromFile` opcional y conserva
su invocación anterior. La configuración pública no es una credencial privilegiada.

Copia de entrega: `docs/manual/entrega/app_transito_defensa_actualizada.apk`.
Se conserva la APK anterior. La release queda para entrega; teléfono y emulador
se actualizaron con debug de igual firma que sus instalaciones previas.
SHA256: `91EBF06E173BBBB1C6DC3D5756F84A86C1181FD51554B4A80AEA536824643A48`.
El empaquetador verificó la ausencia de rutas locales y símbolos en libapp.so.

## Límites y pendientes de entrega

Se conectó Samsung SM-A556E (Android 16/API 36) y se inició el emulador existente
TransitoReleasePhase14. Ambos tenían la misma firma debug, comprobada antes de
`adb install -r`; se conservaron datos y sesiones. No hubo desinstalación ni reset.
El usuario inició sesión ADMIN en el emulador; el teléfono restauró POLICE B.
No se solicitaron ni extrajeron contraseñas o JWT.

**Ensayo dirigido real:**

- El teléfono mostró los nuevos menús. POLICE B eligió EPI 3,
  OTROS HECHOS DE TRANSITO, OTRO con nombre ficticio y categoría Otros.
- El primer intento de voz falló. Se corrigió la selección del español local:
  Android 13+ consulta los idiomas instalados, prefiere el español del dispositivo
  o es-ES/es-US; Android 12 usa es-ES. Si el motor no implementa la consulta,
  intenta es-ES en el mismo reconocedor local. No hay fallback remoto.
  Se distinguen modelo español ausente y silencio/sin coincidencias.
- Tras instalar la corrección, el usuario confirmó dictado real exitoso.
  La UI mostró el texto reconocido. Se añadió manualmente el sufijo
  ` - ENSAYO FICTICIO REVISADO`, comprobando edición sin perder el dictado.
- Se finalizó **2026-000004** desde el teléfono. Lugar identificador:
  `ENSAYO-FORM-20261109-FICTICIO`. Se conserva activo como dato sintético.
- ADMIN pulsó Actualizar en el emulador y abrió el mismo caso. Se observaron
  unidad, naturaleza, opción/nombre, descripción corregida, categoría y
  `Observacion ficticia sincronizada` en el detalle, leídos de Supabase.
- ADMIN generó y abrió la vista previa PDF, tres páginas. Se inspeccionó la
  primera: caso, naturaleza, denunciante y texto dictado/editado correctos.
  No se registró ni subió este PDF a Storage; fue generación local desde datos remotos.
- SQL Cloud confirmó exactamente **15 informes, 15 operaciones y un conductor**:
  los 14 previos más un informe nuevo. Correlativo 2026 = 4. Las huellas de
  los 14 informes y operaciones históricos siguen iguales a las del baseline.
- Como el otro POLICE, una consulta SQL con RLS al caso nuevo y su conductor
  devolvió cero filas. Esta última comprobación usa contexto SQL, sin extraer JWT.

Capturas de evidencia fuera del repositorio:
`%TEMP%/transito-form-evidence-20261109/` (caso ADMIN, descripción, observación y PDF).
La firma release de entrega se verificó con apksigner; la debug actualizada
mantiene la huella SHA256 de certificado
`e49a90d133e614b85c03374f7a8a19bfacb06513d01c17df7eb9cd2de5c53a1b`.
El ensayo desde las APK fue debug con el mismo código funcional; no se afirma
ensayo funcional instalado de la release. La release se compiló y verificó.

No se repitieron cargas de fotos/croquis/PDF privados ni la concurrencia Edge.
El pendiente histórico HTTP 546 Memory y la validación de adjuntos en dos clientes
permanecen abiertos; esta migración no los corrige ni los introduce.

Advisors Cloud posteriores: tres tablas privadas con RLS sin políticas (denegación
intencional), cuatro RPC SECURITY DEFINER ejecutables por authenticated (fachadas
existentes con autorización interna) y protección de contraseñas filtradas Auth
deshabilitada. No se cambiaron esas superficies en esta intervención. Referencias:
[RLS sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[fachadas DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable),
[protección de contraseñas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

Registro en Notion pendiente: no hay destino autorizado en esta conversación.
