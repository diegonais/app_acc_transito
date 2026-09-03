# Estado actual - Fase 6 completada

## Etapa

**Fase 6 - Conductores, vehiculos y personas involucradas**: finalizada.

La aplicacion mantiene autenticacion local sobre SQLite, gestion de policias
para `ADMIN` y el flujo de Informes de Accion Directa. La fase actual completo
las secciones dinamicas de conductores, vehiculos y personas involucradas,
manteniendo estado temporal durante el llenado y persistencia definitiva solo
al finalizar.

No se implementaron todavia dashboard real, captura GPS automatica,
fotografias desde camara/galeria, croquis cartografico operativo, PDF ni QR.

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
  - lugar;
  - denunciante, documento y contacto;
  - descripcion;
  - condiciones climaticas;
  - vehiculos movidos;
  - protagonistas presentes;
  - testigos;
  - efectos personales;
  - latitud/longitud opcionales;
  - ruta de croquis opcional;
  - conductores dinamicos;
  - vehiculos dinamicos;
  - personas involucradas dinamicas.
- Conductores pueden agregarse, revisarse, editarse y quitarse antes de
  finalizar.
- Campos validados por conductor: nombre, edad, licencia, categoria,
  domicilio, zona y contactos. Condicion de entrega queda opcional para cuando
  corresponda.
- Vehiculos pueden agregarse, revisarse, editarse y quitarse antes de
  finalizar.
- Campos validados por vehiculo: placa, marca, color, tipo y servicio.
- La relacion conductor-vehiculo se selecciona contra conductores del mismo
  formulario temporal.
- Al quitar un conductor antes de finalizar, los vehiculos relacionados se
  limpian o reindexan en memoria para evitar referencias invalidas.
- Personas involucradas pueden agregarse, revisarse, editarse y quitarse antes
  de finalizar.
- Campos validados por persona: tipo `HERIDO`/`FALLECIDO`, nombre y edad.
  Lugar de evacuacion queda opcional para cuando corresponda.
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

## Pruebas y validacion

Comandos ejecutados:

| Comando | Estado | Resultado |
|---|---|---|
| `dart format .` | correcto | formato aplicado |
| `flutter analyze` | correcto | sin issues |
| `flutter test` | correcto | todos los tests pasaron |

Pruebas agregadas o actualizadas:

- `test/features/reports/report_controller_test.dart`
  - validaciones antes de finalizar;
  - varios conductores;
  - varios vehiculos;
  - relacion conductor-vehiculo;
  - personas involucradas;
  - validacion de campos confirmados de conductores, vehiculos y personas;
  - finalizacion asociada al policia autenticado;
  - detalle en modo lectura;
  - consulta `POLICE` limitada a informes propios activos;
  - consulta `ADMIN` de todos los activos;
  - permiso de inactivacion solo para `ADMIN`;
  - bloqueo de lectura de informes ajenos para `POLICE`;
  - cancelacion como descarte de estado en memoria sin persistencia.
- `test/data/database/persistence_test.dart`
  - creacion de BD versionada con foreign keys habilitadas;
  - finalizacion completa con relaciones;
  - impedimento de relacionar vehiculo con conductor de otro informe;
  - rollback ante falla SQLite;
  - correlativo por gestion;
  - no reutilizacion de correlativo con informes inactivos;
  - soft delete conserva datos y excluye inactivos.

Pruebas existentes conservadas:

- `test/features/officers/officer_management_repository_test.dart`
- `test/features/auth/auth_repository_test.dart`
- `test/features/auth/auth_controller_test.dart`
- `test/app_startup_test.dart`

## Problemas conocidos

- No se probo en dispositivo Android fisico en esta fase.
- El dashboard sigue siendo minimo; los indicadores reales quedan para fase posterior.
- GPS automatico, camara/galeria, croquis cartografico real, PDF y QR siguen
  pendientes para fases posteriores.

## Siguiente fase

**Fase 7.**
