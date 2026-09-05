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
