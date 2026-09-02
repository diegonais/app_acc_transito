# Estado actual - Fase 3 completada

## Etapa

**Fase 3 - Autenticacion local y roles**: finalizada.

La aplicacion cuenta con autenticacion completamente local sobre SQLite, configuracion inicial del primer `ADMIN`, login por usuario/contrasena, sesion en memoria, logout y autorizacion logica por roles `ADMIN` y `POLICE`.

No se implementaron dashboard real, gestion completa de policias, formularios de informes, GPS, fotografias desde camara/galeria, croquis, PDF ni QR.

## Dependencias agregadas

- `cryptography`: usada para derivar contrasenas con PBKDF2-HMAC-SHA256, salt aleatorio y comparacion de hash sin almacenar texto plano.

Se mantienen:

- `sqflite`: motor SQLite local.
- `path`: construccion portable de la ruta del archivo de base de datos.
- `sqflite_common_ffi` como dependencia de desarrollo para pruebas SQLite reales en memoria.

## Autenticacion

- Gestor de sesion en memoria: `lib/features/auth/application/auth_controller.dart`.
- Scope de acceso a sesion: `lib/features/auth/application/auth_scope.dart`.
- Repositorio de autenticacion: `lib/features/auth/data/auth_repository.dart`.
- Hashing de contrasena: `lib/features/auth/data/password_hasher.dart`.

Flujos implementados:

- Si no existe ningun `ADMIN`, el splash redirige a configuracion inicial.
- La configuracion inicial crea el primer `ADMIN` con usuario y contrasena validados.
- Cuando ya existe un `ADMIN`, el flujo inicial deja de mostrarse.
- Login busca usuario localmente, valida estado activo, verifica contrasena y carga rol.
- Usuarios inactivos no acceden.
- Usuario inexistente y contrasena incorrecta devuelven error generico de credenciales.
- La sesion vive solo en memoria mientras la app esta abierta.
- No existe `Recordarme` ni sesion persistente automatica.
- Logout limpia la sesion y vuelve a login.
- La ruta protegida de dashboard redirige a login si no existe sesion.

## Seguridad de contrasena

- Nunca se guarda la contrasena en texto plano.
- `usuarios.contrasena_hash` almacena un valor codificado con formato:
  `pbkdf2_sha256$iteraciones$saltBase64$hashBase64`.
- El salt se genera con `Random.secure`.
- La verificacion deriva nuevamente la clave y compara bytes sin exponer hash ni contrasena en UI.
- No se implementaron email, SMS, preguntas de seguridad ni recuperacion cloud.

## Roles y datos del policia

- Roles modelados en `lib/features/auth/domain/app_role.dart`.
- Sesion autenticada modelada en `lib/features/auth/domain/authenticated_user.dart`.
- La autorizacion se aplica en logica mediante `requireRole`.
- El dashboard minimo muestra datos de sesion y restringe el restablecimiento a `ADMIN`.
- Para usuarios `POLICE`, el login carga datos activos de `policias`:
  - `id_policia`;
  - grado;
  - nombres y apellidos;
  - unidad;
  - sigla;
  - numero de placa;
  - C.I. administrativo.
- Estos datos quedan disponibles en la sesion para asociar informes en fases posteriores.

## Restablecimiento

- `ADMIN` puede establecer una nueva contrasena para un usuario `POLICE`.
- No se requiere conocer ni visualizar la contrasena anterior.
- El restablecimiento reemplaza solamente el hash almacenado y actualiza `fecha_modificacion`.
- Un usuario no `ADMIN` recibe error de autorizacion en la capa logica.

## Base de datos

- No se modifico el esquema ni la version de base de datos.
- Se agregaron consultas parametrizadas en DAO para:
  - buscar usuario por nombre;
  - contar administradores;
  - actualizar hash de contrasena;
  - cargar policia activo por usuario.

## Pruebas y validacion

Comandos ejecutados:

| Comando | Estado | Resultado |
|---|---|---|
| `flutter pub get` | correcto | dependencias resueltas |
| `dart format .` | correcto | formato aplicado |
| `flutter analyze` | correcto | sin issues |
| `flutter test` | correcto | todos los tests pasaron |

Pruebas agregadas:

- `test/features/auth/auth_repository_test.dart`
  - primer `ADMIN`;
  - hash + salt y ausencia de texto plano;
  - bloqueo de recreacion del flujo inicial;
  - login valido `ADMIN`;
  - login valido `POLICE` con datos de policia;
  - contrasena incorrecta;
  - usuario inexistente;
  - usuario inactivo;
  - autorizacion por rol;
  - restablecimiento local de contrasena policial.
- `test/features/auth/auth_controller_test.dart`
  - sesion en memoria;
  - logout limpia autenticacion.
- `test/app_startup_test.dart`
  - configuracion inicial sin `ADMIN`;
  - login valido;
  - logout y proteccion de ruta;
  - error por credenciales incorrectas;
  - ruta desconocida a login.

## Problemas conocidos

- No se probo en dispositivo Android fisico en esta fase.
- El dashboard sigue siendo minimo; los indicadores reales quedan para una fase posterior.
- La gestion completa de policias y cuentas locales queda para fases posteriores.
- Informes, GPS, camara/galeria, croquis, PDF y QR siguen pendientes.

## Siguiente fase

**Fase 4.**
