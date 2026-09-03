import 'package:sqflite/sqflite.dart';

class AppDatabaseMigrations {
  const AppDatabaseMigrations._();

  static Future<void> create(DatabaseExecutor db, int version) async {
    for (var targetVersion = 1; targetVersion <= version; targetVersion++) {
      await _apply(db, targetVersion);
    }
  }

  static Future<void> upgrade(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var targetVersion = oldVersion + 1;
        targetVersion <= newVersion;
        targetVersion++) {
      await _apply(db, targetVersion);
    }
  }

  static Future<void> _apply(DatabaseExecutor db, int targetVersion) async {
    switch (targetVersion) {
      case 1:
        await _createVersion1(db);
        return;
      case 2:
        await _createVersion2(db);
        return;
      default:
        throw StateError('No existe migracion para version $targetVersion.');
    }
  }

  static Future<void> _createVersion1(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE usuarios (
  id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre_usuario TEXT NOT NULL UNIQUE,
  contrasena_hash TEXT NOT NULL,
  rol TEXT NOT NULL CHECK (rol IN ('ADMIN', 'POLICE')),
  estado INTEGER NOT NULL DEFAULT 1 CHECK (estado IN (0, 1)),
  fecha_creacion TEXT NOT NULL,
  fecha_modificacion TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE policias (
  id_policia INTEGER PRIMARY KEY AUTOINCREMENT,
  id_usuario INTEGER NOT NULL UNIQUE,
  numero_placa TEXT NOT NULL UNIQUE,
  grado TEXT NOT NULL,
  nombres TEXT NOT NULL,
  apellidos TEXT NOT NULL,
  unidad TEXT NOT NULL,
  sigla TEXT NOT NULL,
  ci TEXT NOT NULL,
  estado INTEGER NOT NULL DEFAULT 1 CHECK (estado IN (0, 1)),
  fecha_creacion TEXT NOT NULL,
  fecha_modificacion TEXT NOT NULL,
  FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
)
''');

    await db.execute('''
CREATE TABLE informes (
  id_informe INTEGER PRIMARY KEY AUTOINCREMENT,
  id_policia INTEGER NOT NULL,
  gestion INTEGER NOT NULL,
  correlativo INTEGER NOT NULL CHECK (correlativo > 0),
  numero_caso TEXT NOT NULL UNIQUE,
  epi TEXT NOT NULL,
  fecha_hora_llegada TEXT,
  fecha_hora_hecho TEXT,
  naturaleza TEXT,
  lugar TEXT,
  latitud REAL,
  longitud REAL,
  denunciante_nombre TEXT,
  denunciante_documento TEXT,
  denunciante_contacto TEXT,
  descripcion TEXT,
  condiciones_climaticas TEXT,
  vehiculos_movidos INTEGER CHECK (vehiculos_movidos IS NULL OR vehiculos_movidos IN (0, 1)),
  protagonistas_presentes INTEGER CHECK (protagonistas_presentes IS NULL OR protagonistas_presentes IN (0, 1)),
  testigos TEXT,
  efectos_personales TEXT,
  ruta_croquis TEXT,
  ruta_pdf TEXT,
  estado INTEGER NOT NULL DEFAULT 1 CHECK (estado IN (0, 1)),
  fecha_creacion TEXT NOT NULL,
  fecha_modificacion TEXT NOT NULL,
  UNIQUE (gestion, correlativo),
  FOREIGN KEY (id_policia) REFERENCES policias (id_policia)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
)
''');

    await db.execute('''
CREATE TABLE conductores (
  id_conductor INTEGER PRIMARY KEY AUTOINCREMENT,
  id_informe INTEGER NOT NULL,
  nombre_completo TEXT NOT NULL,
  edad INTEGER CHECK (edad IS NULL OR edad >= 0),
  licencia TEXT,
  categoria TEXT,
  domicilio TEXT,
  zona TEXT,
  contactos TEXT,
  condicion_entrega TEXT,
  fecha_creacion TEXT NOT NULL,
  FOREIGN KEY (id_informe) REFERENCES informes (id_informe)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
)
''');

    await db.execute('''
CREATE TABLE vehiculos (
  id_vehiculo INTEGER PRIMARY KEY AUTOINCREMENT,
  id_informe INTEGER NOT NULL,
  id_conductor INTEGER,
  placa TEXT,
  marca TEXT,
  color TEXT,
  tipo TEXT,
  servicio TEXT,
  fecha_creacion TEXT NOT NULL,
  FOREIGN KEY (id_informe) REFERENCES informes (id_informe)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  FOREIGN KEY (id_conductor) REFERENCES conductores (id_conductor)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
)
''');

    await db.execute('''
CREATE TABLE personas_involucradas (
  id_persona INTEGER PRIMARY KEY AUTOINCREMENT,
  id_informe INTEGER NOT NULL,
  nombre TEXT NOT NULL,
  edad INTEGER CHECK (edad IS NULL OR edad >= 0),
  tipo TEXT NOT NULL CHECK (tipo IN ('HERIDO', 'FALLECIDO')),
  lugar_evacuacion TEXT,
  fecha_creacion TEXT NOT NULL,
  FOREIGN KEY (id_informe) REFERENCES informes (id_informe)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
)
''');

    await db.execute('''
CREATE TABLE fotografias (
  id_fotografia INTEGER PRIMARY KEY AUTOINCREMENT,
  id_informe INTEGER NOT NULL,
  ruta TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('PANORAMICA', 'LICENCIA', 'PLACA', 'OTRA')),
  descripcion TEXT,
  fecha_creacion TEXT NOT NULL,
  FOREIGN KEY (id_informe) REFERENCES informes (id_informe)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
)
''');

    await db.execute(
      'CREATE INDEX idx_policias_id_usuario ON policias (id_usuario)',
    );
    await db.execute(
      'CREATE INDEX idx_informes_id_policia ON informes (id_policia)',
    );
    await db.execute(
      'CREATE INDEX idx_informes_estado ON informes (estado)',
    );
    await db.execute(
      'CREATE INDEX idx_conductores_id_informe ON conductores (id_informe)',
    );
    await db.execute(
      'CREATE INDEX idx_vehiculos_id_informe ON vehiculos (id_informe)',
    );
    await db.execute(
      'CREATE INDEX idx_vehiculos_id_conductor ON vehiculos (id_conductor)',
    );
    await db.execute(
      'CREATE INDEX idx_personas_id_informe ON personas_involucradas (id_informe)',
    );
    await db.execute(
      'CREATE INDEX idx_fotografias_id_informe ON fotografias (id_informe)',
    );
  }

  static Future<void> _createVersion2(DatabaseExecutor db) async {
    await db.execute('''
CREATE TRIGGER trg_vehiculos_conductor_mismo_informe_insert
BEFORE INSERT ON vehiculos
WHEN NEW.id_conductor IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM conductores
    WHERE id_conductor = NEW.id_conductor
      AND id_informe = NEW.id_informe
  )
BEGIN
  SELECT RAISE(ABORT, 'El conductor relacionado no pertenece al informe.');
END
''');

    await db.execute('''
CREATE TRIGGER trg_vehiculos_conductor_mismo_informe_update
BEFORE UPDATE OF id_informe, id_conductor ON vehiculos
WHEN NEW.id_conductor IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM conductores
    WHERE id_conductor = NEW.id_conductor
      AND id_informe = NEW.id_informe
  )
BEGIN
  SELECT RAISE(ABORT, 'El conductor relacionado no pertenece al informe.');
END
''');
  }
}
