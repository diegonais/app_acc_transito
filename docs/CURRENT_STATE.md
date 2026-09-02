# Estado actual - Fase 2 completada

## Etapa

**Fase 2 - SQLite y persistencia**: finalizada.

La aplicacion cuenta con una base SQLite local, versionada y reproducible para Android mediante `sqflite`. No se implementaron pantallas nuevas, autenticacion funcional, dashboard real, GPS, fotografias desde camara/galeria, PDF ni QR.

## Dependencias agregadas

- `sqflite`: motor SQLite local requerido por la fase.
- `path`: construccion portable de la ruta del archivo de base de datos.
- `sqflite_common_ffi` como dependencia de desarrollo: pruebas SQLite reales en memoria.

## Base de datos

- Gestor central: `lib/data/database/app_database.dart`.
- Nombre de BD: `app_acc_transito.db`.
- Version de esquema: `1`.
- Migraciones versionadas: `lib/data/database/app_database_migrations.dart`.
- `PRAGMA foreign_keys = ON` se habilita al configurar cada conexion.
- Todas las consultas implementadas usan parametros (`whereArgs` o `rawQuery` con argumentos).

## Esquema implementado

Tablas base creadas:

- `usuarios`
- `policias`
- `informes`
- `conductores`
- `vehiculos`
- `personas_involucradas`
- `fotografias`

Restricciones principales:

- PK internas `INTEGER PRIMARY KEY AUTOINCREMENT`.
- FK explicitas entre usuarios, policias, informes y tablas hijas.
- `usuarios.nombre_usuario` unico.
- `policias.numero_placa` unico.
- `policias.id_usuario` unico para relacion 1 a 0..1.
- `informes.numero_caso` unico.
- `informes(gestion, correlativo)` unico.
- `estado` entero con `0 = inactivo`, `1 = activo`.
- Roles restringidos a `ADMIN` y `POLICE`.
- Personas restringidas a `HERIDO` y `FALLECIDO`.
- Fotografias restringidas a `PANORAMICA`, `LICENCIA`, `PLACA`, `OTRA`.
- Fotografias, croquis y PDF se persisten solo como rutas/metadatos, sin BLOB.
- No se agregaron campos de celular ni escalafon para policias.

Indices creados:

- FK y consultas reales: informes por policia, informes por estado, hijos por informe y vehiculos por conductor.
- Unicidades mediante restricciones aprobadas.

## Arquitectura de persistencia

Se respeta el flujo:

```text
UI
↓
estado/controlador
↓
repositorio
↓
DAO
↓
SQLite
```

DAOs creados:

- `UserDao`
- `PoliceDao`
- `ReportDao`

Repositorios creados:

- `UserRepository`
- `PoliceRepository`
- `ReportRepository`

La UI existente no ejecuta SQL.

## Finalizar informe

Quedo preparado el mecanismo transaccional en `ReportRepository.finalizeReport`.

La transaccion:

1. calcula correlativo por gestion considerando activos e inactivos;
2. arma `numero_caso` con formato `AAAA-NNNNNN`;
3. inserta informe con `estado = 1`;
4. inserta conductores;
5. inserta vehiculos y relacion opcional con conductor;
6. inserta personas involucradas;
7. inserta fotografias como rutas/metadatos;
8. confirma todo o revierte todo ante error.

Los informes finalizados no tienen estado de borrador. La inactivacion usa soft delete mediante `estado = 0`; las consultas de aplicacion implementadas devuelven solo activos.

## Pruebas y validacion

Comandos ejecutados:

| Comando | Estado | Resultado |
|---|---|---|
| `flutter pub get` | correcto | dependencias resueltas |
| `dart format .` | correcto | formato aplicado |
| `flutter analyze` | correcto | sin issues |
| `flutter test` | correcto | todos los tests pasaron |

Pruebas de persistencia agregadas en `test/data/database/persistence_test.dart`:

- creacion de BD versionada;
- `PRAGMA foreign_keys = ON`;
- existencia de tablas base;
- inserciones de usuarios, policias, informes y relaciones;
- FK y restricciones `UNIQUE`/`CHECK`;
- rollback completo en finalizacion fallida;
- correlativo por gestion;
- reinicio de correlativo por gestion;
- no reutilizacion tras inactivar;
- soft delete;
- consultas que excluyen informes inactivos;
- conservacion de metadatos asociados a informes inactivos.

## Problemas conocidos

- No se probo en dispositivo Android fisico en esta fase.
- La autenticacion local aun no verifica hash/salt en UI; queda para la fase correspondiente.
- La pantalla de informe todavia no existe; solo quedo lista la persistencia transaccional para usarla despues.
- GPS, camara/galeria, croquis, PDF y QR siguen pendientes.

## Siguiente fase

**Fase 3.**
