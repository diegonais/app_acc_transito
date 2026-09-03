# Estado actual - Fase 4 completada

## Etapa

**Fase 4 - Gestion de policias**: finalizada.

La aplicacion mantiene autenticacion local sobre SQLite y ahora permite al
`ADMIN` gestionar funcionarios policiales y sus cuentas locales asociadas.

No se implementaron todavia el Informe de Accion Directa, dashboard real, GPS,
fotografias desde camara/galeria, croquis, PDF ni QR.

## Dependencias

Sin dependencias nuevas en esta fase.

Se mantienen:

- `cryptography`: hash de contrasenas con PBKDF2-HMAC-SHA256 y salt aleatorio.
- `sqflite`: motor SQLite local.
- `path`: construccion portable de la ruta del archivo de base de datos.
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
- Visualizacion de estado activo/inactivo.
- Alta de funcionario policial con:
  - numero de placa;
  - grado;
  - nombres;
  - apellidos;
  - unidad;
  - sigla;
  - C.I.;
  - nombre de usuario;
  - contrasena inicial;
  - estado.
- Modificacion de datos administrativos permitidos:
  - numero de placa;
  - grado;
  - nombres;
  - apellidos;
  - unidad;
  - sigla;
  - C.I.;
  - nombre de usuario.
- Activacion/desactivacion sincronizada de policia y usuario asociado.
- Restablecimiento de contrasena por Admin sin mostrar la anterior.

No se agregaron celular del policia ni numero de escalafon.

## Persistencia

- No se modifico el esquema ni la version de base de datos.
- Se reutilizan las tablas existentes `usuarios` y `policias`.
- Alta de usuario `POLICE` + registro `policias` se realiza dentro de una transaccion.
- Activacion/desactivacion actualiza ambas tablas dentro de una transaccion.
- Actualizacion administrativa mantiene la identidad interna `id_usuario` /
  `id_policia` y no toca tablas de informes.
- No hay borrado fisico destructivo.
- Se agregaron consultas parametrizadas para:
  - listar policias con su usuario;
  - buscar duplicados de usuario;
  - buscar duplicados de placa;
  - actualizar datos administrativos;
  - actualizar estado de usuario/policia;
  - restablecer hash de contrasena.

## Pruebas y validacion

Comandos ejecutados:

| Comando | Estado | Resultado |
|---|---|---|
| `dart format .` | correcto | formato aplicado |
| `flutter analyze` | correcto | sin issues |
| `flutter test` | correcto | todos los tests pasaron |

Pruebas agregadas:

- `test/features/officers/officer_management_repository_test.dart`
  - alta valida;
  - usuario duplicado;
  - placa duplicada;
  - ausencia de registros parciales;
  - actualizacion administrativa;
  - activacion/desactivacion sincronizada;
  - login bloqueado para inactivo;
  - relacion usuario-policia;
  - restablecimiento de contrasena.

Pruebas existentes conservadas:

- `test/features/auth/auth_repository_test.dart`
- `test/features/auth/auth_controller_test.dart`
- `test/data/database/persistence_test.dart`
- `test/app_startup_test.dart`

## Problemas conocidos

- No se probo en dispositivo Android fisico en esta fase.
- El dashboard sigue siendo minimo; los indicadores reales quedan para fase posterior.
- Informes, GPS, camara/galeria, croquis, PDF y QR siguen pendientes.

## Siguiente fase

**Fase 5.**
