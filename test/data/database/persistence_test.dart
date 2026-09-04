import 'dart:io';

import 'package:app_acc_transito/data/database/app_database_migrations.dart';
import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/services/media/evidence_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

var _policeSequence = 0;

void main() {
  late AppDatabase appDatabase;
  late UserRepository userRepository;
  late PoliceRepository policeRepository;
  late ReportRepository reportRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    appDatabase = AppDatabase(databasePath: inMemoryDatabasePath);
    userRepository = UserRepository(appDatabase);
    policeRepository = PoliceRepository(appDatabase);
    reportRepository = ReportRepository(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('crea la BD versionada con foreign keys habilitadas', () async {
    final db = await appDatabase.instance;

    final versionRows = await db.rawQuery('PRAGMA user_version');
    final foreignKeyRows = await db.rawQuery('PRAGMA foreign_keys');
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
      "('usuarios', 'policias', 'informes', 'conductores', 'vehiculos', "
      "'personas_involucradas', 'fotografias')",
    );

    expect(versionRows.single['user_version'], AppDatabase.schemaVersion);
    expect(foreignKeyRows.single['foreign_keys'], 1);
    expect(tableRows, hasLength(7));
  });

  test('migra incrementalmente de version 1 a version actual', () async {
    final sandbox = await Directory.systemTemp.createTemp('migration_test_');
    final databasePath = p.join(sandbox.path, 'legacy.db');
    AppDatabase? migratedDatabase;
    try {
      final legacy = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            await AppDatabaseMigrations.create(db, version);
          },
        ),
      );
      await legacy.close();

      migratedDatabase = AppDatabase(databasePath: databasePath);
      final db = await migratedDatabase.instance;

      final versionRows = await db.rawQuery('PRAGMA user_version');
      final triggerRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name IN "
        "('trg_vehiculos_conductor_mismo_informe_insert', "
        "'trg_vehiculos_conductor_mismo_informe_update')",
      );
      final indexRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN "
        "('idx_informes_estado_fecha_hecho', "
        "'idx_informes_estado_policia_fecha_hecho')",
      );

      expect(versionRows.single['user_version'], AppDatabase.schemaVersion);
      expect(triggerRows, hasLength(2));
      expect(indexRows, hasLength(2));
    } finally {
      await migratedDatabase?.close();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    }
  });

  test('inserta usuarios, policias e informe finalizado con relaciones',
      () async {
    final idPolicia = await _createPolice(userRepository, policeRepository);

    final finalized = await reportRepository.finalizeReport(
      _validReportInput(
        idPolicia: idPolicia,
        epi: 'EPI Norte',
        conductores: const [
          DriverInput(
            nombreCompleto: 'Juan Perez',
            edad: 34,
            licencia: 'LP-123',
            categoria: 'A',
            domicilio: 'Barrio Norte',
            zona: 'Norte',
            contactos: '70000001',
          ),
        ],
        vehiculos: const [
          VehicleInput(
            driverIndex: 0,
            placa: '123ABC',
            marca: 'Toyota',
            color: 'Blanco',
            tipo: 'Vagoneta',
            servicio: 'Particular',
          ),
        ],
        personas: const [
          PersonInput(nombre: 'Maria Rojas', edad: 30, tipo: 'HERIDO'),
        ],
        fotografias: const [
          PhotoInput(
            ruta: '/evidencias/foto-1.jpg',
            tipo: EvidencePhotoCategory.panoramica,
          ),
        ],
      ),
      now: DateTime.utc(2026),
    );

    final db = await appDatabase.instance;
    final conductores = await db.query('conductores');
    final vehiculos = await db.query('vehiculos');
    final personas = await db.query('personas_involucradas');
    final fotografias = await db.query('fotografias');

    expect(finalized.numeroCaso, '2026-000001');
    expect(conductores.single['id_informe'], finalized.idInforme);
    expect(
        vehiculos.single['id_conductor'], conductores.single['id_conductor']);
    expect(personas.single['tipo'], 'HERIDO');
    expect(fotografias.single['ruta'], '/evidencias/foto-1.jpg');
  });

  test('aplica restricciones confirmadas y relaciones FK', () async {
    final db = await appDatabase.instance;
    final idUsuario = await userRepository.createUser(
      username: 'admin',
      passwordHash: 'hash:salt',
      role: 'ADMIN',
      now: DateTime.utc(2026),
    );

    await expectLater(
      userRepository.createUser(
        username: 'admin',
        passwordHash: 'otro-hash',
        role: 'ADMIN',
        now: DateTime.utc(2026),
      ),
      throwsA(isA<DatabaseException>()),
    );

    await expectLater(
      db.insert('usuarios', {
        'nombre_usuario': 'rol-invalido',
        'contrasena_hash': 'hash',
        'rol': 'ROOT',
        'estado': 1,
        'fecha_creacion': DateTime.utc(2026).toIso8601String(),
        'fecha_modificacion': DateTime.utc(2026).toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );

    await expectLater(
      policeRepository.createPolice(
        idUsuario: idUsuario + 99,
        numeroPlaca: '999',
        grado: 'Sgto.',
        nombres: 'Ana',
        apellidos: 'Quispe',
        unidad: 'Transito',
        sigla: 'UT',
        ci: '123',
        now: DateTime.utc(2026),
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('impide relacionar un vehiculo con conductor de otro informe', () async {
    final idPolicia = await _createPolice(userRepository, policeRepository);
    final first = await reportRepository.finalizeReport(
      _validReportInput(
        idPolicia: idPolicia,
        epi: 'EPI Conductor',
        conductores: const [_validDriver],
      ),
      now: DateTime.utc(2026),
    );
    final second = await reportRepository.finalizeReport(
      _validReportInput(idPolicia: idPolicia, epi: 'EPI Vehiculo'),
      now: DateTime.utc(2026),
    );

    final db = await appDatabase.instance;
    final conductor = await db.query(
      'conductores',
      where: 'id_informe = ?',
      whereArgs: [first.idInforme],
      limit: 1,
    );

    await expectLater(
      db.insert('vehiculos', {
        'id_informe': second.idInforme,
        'id_conductor': conductor.single['id_conductor'],
        'placa': '999XYZ',
        'marca': 'Toyota',
        'color': 'Blanco',
        'tipo': 'Vagoneta',
        'servicio': 'Particular',
        'fecha_creacion': DateTime.utc(2026).toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rollback completo si falla una insercion dependiente', () async {
    await expectLater(
      reportRepository.finalizeReport(
        _validReportInput(
          idPolicia: 999,
          epi: 'EPI Central',
        ),
        now: DateTime.utc(2026),
      ),
      throwsA(isA<DatabaseException>()),
    );

    final db = await appDatabase.instance;
    expect(await db.query('informes'), isEmpty);
  });

  test('correlativo por gestion no reutiliza informes inactivos', () async {
    final idPolicia = await _createPolice(userRepository, policeRepository);

    final first = await reportRepository.finalizeReport(
      _validReportInput(idPolicia: idPolicia, epi: 'EPI 1'),
      now: DateTime.utc(2026),
    );
    final second = await reportRepository.finalizeReport(
      _validReportInput(idPolicia: idPolicia, epi: 'EPI 2'),
      now: DateTime.utc(2026),
    );
    final nextYear = await reportRepository.finalizeReport(
      _validReportInput(idPolicia: idPolicia, gestion: 2027, epi: 'EPI 3'),
      now: DateTime.utc(2027),
    );

    await reportRepository.inactivateReport(
      idInforme: second.idInforme,
      now: DateTime.utc(2026, 2),
    );

    final third = await reportRepository.finalizeReport(
      _validReportInput(idPolicia: idPolicia, epi: 'EPI 4'),
      now: DateTime.utc(2026, 3),
    );

    expect(first.numeroCaso, '2026-000001');
    expect(second.numeroCaso, '2026-000002');
    expect(nextYear.numeroCaso, '2027-000001');
    expect(third.numeroCaso, '2026-000003');
  });

  test('soft delete conserva datos y consultas de app excluyen inactivos',
      () async {
    final idPolicia = await _createPolice(userRepository, policeRepository);
    final active = await reportRepository.finalizeReport(
      _validReportInput(
        idPolicia: idPolicia,
        epi: 'EPI Activo',
        fotografias: const [
          PhotoInput(
            ruta: '/evidencias/activa.jpg',
            tipo: EvidencePhotoCategory.otra,
          ),
        ],
      ),
      now: DateTime.utc(2026),
    );
    final inactive = await reportRepository.finalizeReport(
      _validReportInput(
        idPolicia: idPolicia,
        epi: 'EPI Inactivo',
        conductores: const [_validDriver],
        vehiculos: const [
          VehicleInput(
            driverIndex: 0,
            placa: '456DEF',
            marca: 'Nissan',
            color: 'Rojo',
            tipo: 'Automovil',
            servicio: 'Publico',
          ),
        ],
        personas: const [
          PersonInput(nombre: 'Luis Roca', edad: 42, tipo: 'FALLECIDO'),
        ],
        fotografias: const [
          PhotoInput(
            ruta: '/evidencias/inactiva.jpg',
            tipo: EvidencePhotoCategory.placa,
          ),
        ],
      ),
      now: DateTime.utc(2026),
    );

    await reportRepository.inactivateReport(
      idInforme: inactive.idInforme,
      now: DateTime.utc(2026, 2),
    );

    final db = await appDatabase.instance;
    final activeReports = await reportRepository.findActiveReports();
    final inactiveDetail =
        await reportRepository.findActiveReportDetail(inactive.idInforme);
    final inactiveDrivers = await db.query(
      'conductores',
      where: 'id_informe = ?',
      whereArgs: [inactive.idInforme],
    );
    final inactiveVehicles = await db.query(
      'vehiculos',
      where: 'id_informe = ?',
      whereArgs: [inactive.idInforme],
    );
    final inactivePeople = await db.query(
      'personas_involucradas',
      where: 'id_informe = ?',
      whereArgs: [inactive.idInforme],
    );
    final inactivePhotos = await db.query(
      'fotografias',
      where: 'id_informe = ?',
      whereArgs: [inactive.idInforme],
    );

    expect(activeReports, hasLength(1));
    expect(activeReports.single['id_informe'], active.idInforme);
    expect(inactiveDetail, isNull);
    expect(inactiveDrivers.single['nombre_completo'], 'Juan Perez');
    expect(inactiveVehicles.single['placa'], '456DEF');
    expect(inactivePeople.single['tipo'], 'FALLECIDO');
    expect(inactivePhotos.single['ruta'], '/evidencias/inactiva.jpg');
  });

  test('dashboard calcula totales dia mes fecha policia y omite inactivos',
      () async {
    final firstPolice = await _createPolice(userRepository, policeRepository);
    final secondPolice = await _createPolice(userRepository, policeRepository);
    final first = await reportRepository.finalizeReport(
      _validReportInput(
        idPolicia: firstPolice,
        epi: 'EPI Dia',
        fechaHoraHecho: DateTime.utc(2026, 5, 12, 7),
      ),
      now: DateTime.utc(2026, 5, 12),
    );
    await reportRepository.finalizeReport(
      _validReportInput(
        idPolicia: firstPolice,
        epi: 'EPI Mes',
        fechaHoraHecho: DateTime.utc(2026, 5, 20, 7),
      ),
      now: DateTime.utc(2026, 5, 20),
    );
    final inactive = await reportRepository.finalizeReport(
      _validReportInput(
        idPolicia: secondPolice,
        epi: 'EPI Inactivo',
        fechaHoraHecho: DateTime.utc(2026, 5, 12, 8),
      ),
      now: DateTime.utc(2026, 5, 12),
    );
    await reportRepository.inactivateReport(
      idInforme: inactive.idInforme,
      now: DateTime.utc(2026, 6),
    );

    final adminStats = await reportRepository.loadAdminDashboard(
      referenceDate: DateTime(2026, 5, 12, 9),
      selectedDate: DateTime(2026, 5, 12),
    );
    final policeStats = await reportRepository.loadPoliceDashboard(
      idPolicia: firstPolice,
      referenceDate: DateTime(2026, 5, 12, 9),
      selectedDate: DateTime(2026, 6, 1),
    );
    final emptyResults = await reportRepository.queryActiveReportsForAdmin(
      filter: ReportQueryFilter(
        from: DateTime.utc(2025, 1, 1),
        to: DateTime.utc(2025, 1, 2),
      ),
    );

    expect(adminStats.totalActiveReports, 2);
    expect(adminStats.activePoliceCount, 2);
    expect(adminStats.reportsToday, 1);
    expect(adminStats.reportsThisMonth, 2);
    expect(adminStats.reportsBySelectedDate, 1);
    expect(adminStats.reportsByPolice, hasLength(2));
    expect(
      adminStats.reportsByPolice
          .singleWhere((entry) => entry.idPolicia == firstPolice)
          .total,
      2,
    );
    expect(
      adminStats.reportsByPolice
          .singleWhere((entry) => entry.idPolicia == secondPolice)
          .total,
      0,
    );
    expect(adminStats.reportsByMonth.single.total, 2);
    expect(policeStats.totalActiveReports, 2);
    expect(policeStats.reportsToday, 1);
    expect(policeStats.reportsThisMonth, 2);
    expect(policeStats.reportsBySelectedDate, 0);
    expect(emptyResults, isEmpty);

    final detail = await reportRepository.findActiveReportDetailForPolice(
      idInforme: first.idInforme,
      idPolicia: secondPolice,
    );
    expect(detail, isNull);
  });
}

const _validDriver = DriverInput(
  nombreCompleto: 'Juan Perez',
  edad: 34,
  licencia: 'LP-123',
  categoria: 'A',
  domicilio: 'Barrio Norte',
  zona: 'Norte',
  contactos: '70000001',
);

Future<int> _createPolice(
  UserRepository userRepository,
  PoliceRepository policeRepository,
) async {
  final sequence = ++_policeSequence;
  final now = DateTime.utc(2026);
  final idUsuario = await userRepository.createUser(
    username: 'policia-$sequence',
    passwordHash: 'hash:salt',
    role: 'POLICE',
    now: now,
  );
  return policeRepository.createPolice(
    idUsuario: idUsuario,
    numeroPlaca: 'PL-$sequence',
    grado: 'Sgto.',
    nombres: 'Ana',
    apellidos: 'Quispe',
    unidad: 'Transito',
    sigla: 'UT',
    ci: '1234567',
    now: now,
  );
}

FinalizeReportInput _validReportInput({
  required int idPolicia,
  int gestion = 2026,
  String epi = 'EPI Central',
  DateTime? fechaHoraHecho,
  List<DriverInput> conductores = const [],
  List<VehicleInput> vehiculos = const [],
  List<PersonInput> personas = const [],
  List<PhotoInput> fotografias = const [],
}) {
  return FinalizeReportInput(
    idPolicia: idPolicia,
    gestion: gestion,
    epi: epi,
    fechaHoraLlegada: DateTime.utc(gestion, 1, 1, 8),
    fechaHoraHecho: fechaHoraHecho ?? DateTime.utc(gestion, 1, 1, 7),
    naturaleza: 'Colision',
    lugar: 'Av. Principal',
    denuncianteNombre: 'No existe',
    denuncianteContacto: 'No existe',
    descripcion: 'Descripcion del hecho',
    condicionesClimaticas: 'Despejado',
    vehiculosMovidos: false,
    protagonistasPresentes: true,
    testigos: 'No existe',
    efectosPersonales: 'No aplica',
    conductores: conductores,
    vehiculos: vehiculos,
    personas: personas,
    fotografias: fotografias,
  );
}
