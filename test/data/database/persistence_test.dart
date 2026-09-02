import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  test('inserta usuarios, policias e informe finalizado con relaciones',
      () async {
    final idPolicia = await _createPolice(userRepository, policeRepository);

    final finalized = await reportRepository.finalizeReport(
      FinalizeReportInput(
        idPolicia: idPolicia,
        gestion: 2026,
        epi: 'EPI Norte',
        conductores: const [
          DriverInput(nombreCompleto: 'Juan Perez', licencia: 'LP-123'),
        ],
        vehiculos: const [
          VehicleInput(driverIndex: 0, placa: '123ABC', marca: 'Toyota'),
        ],
        personas: const [
          PersonInput(nombre: 'Maria Rojas', tipo: 'HERIDO'),
        ],
        fotografias: const [
          PhotoInput(ruta: '/evidencias/foto-1.jpg', tipo: 'PANORAMICA'),
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

  test('rollback completo si falla una insercion dependiente', () async {
    final idPolicia = await _createPolice(userRepository, policeRepository);

    await expectLater(
      reportRepository.finalizeReport(
        FinalizeReportInput(
          idPolicia: idPolicia,
          gestion: 2026,
          epi: 'EPI Central',
          personas: const [
            PersonInput(nombre: 'Tipo invalido', tipo: 'TESTIGO'),
          ],
        ),
        now: DateTime.utc(2026),
      ),
      throwsA(isA<DatabaseException>()),
    );

    final db = await appDatabase.instance;
    expect(await db.query('informes'), isEmpty);
    expect(await db.query('personas_involucradas'), isEmpty);
  });

  test('correlativo por gestion no reutiliza informes inactivos', () async {
    final idPolicia = await _createPolice(userRepository, policeRepository);

    final first = await reportRepository.finalizeReport(
      FinalizeReportInput(idPolicia: idPolicia, gestion: 2026, epi: 'EPI 1'),
      now: DateTime.utc(2026),
    );
    final second = await reportRepository.finalizeReport(
      FinalizeReportInput(idPolicia: idPolicia, gestion: 2026, epi: 'EPI 2'),
      now: DateTime.utc(2026),
    );
    final nextYear = await reportRepository.finalizeReport(
      FinalizeReportInput(idPolicia: idPolicia, gestion: 2027, epi: 'EPI 3'),
      now: DateTime.utc(2027),
    );

    await reportRepository.inactivateReport(
      idInforme: second.idInforme,
      now: DateTime.utc(2026, 2),
    );

    final third = await reportRepository.finalizeReport(
      FinalizeReportInput(idPolicia: idPolicia, gestion: 2026, epi: 'EPI 4'),
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
      FinalizeReportInput(
        idPolicia: idPolicia,
        gestion: 2026,
        epi: 'EPI Activo',
        fotografias: const [
          PhotoInput(ruta: '/evidencias/activa.jpg', tipo: 'OTRA'),
        ],
      ),
      now: DateTime.utc(2026),
    );
    final inactive = await reportRepository.finalizeReport(
      FinalizeReportInput(
        idPolicia: idPolicia,
        gestion: 2026,
        epi: 'EPI Inactivo',
        fotografias: const [
          PhotoInput(ruta: '/evidencias/inactiva.jpg', tipo: 'PLACA'),
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
    final inactivePhotos = await db.query(
      'fotografias',
      where: 'id_informe = ?',
      whereArgs: [inactive.idInforme],
    );

    expect(activeReports, hasLength(1));
    expect(activeReports.single['id_informe'], active.idInforme);
    expect(inactivePhotos.single['ruta'], '/evidencias/inactiva.jpg');
  });
}

Future<int> _createPolice(
  UserRepository userRepository,
  PoliceRepository policeRepository,
) async {
  final now = DateTime.utc(2026);
  final idUsuario = await userRepository.createUser(
    username: 'policia-${DateTime.now().microsecondsSinceEpoch}',
    passwordHash: 'hash:salt',
    role: 'POLICE',
    now: now,
  );
  return policeRepository.createPolice(
    idUsuario: idUsuario,
    numeroPlaca: 'PL-${DateTime.now().microsecondsSinceEpoch}',
    grado: 'Sgto.',
    nombres: 'Ana',
    apellidos: 'Quispe',
    unidad: 'Transito',
    sigla: 'UT',
    ci: '1234567',
    now: now,
  );
}
