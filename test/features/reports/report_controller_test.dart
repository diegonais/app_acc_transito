import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/authenticated_user.dart';
import 'package:app_acc_transito/features/reports/application/report_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late UserRepository userRepository;
  late PoliceRepository policeRepository;
  late ReportRepository reportRepository;
  late ReportController controller;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    appDatabase = AppDatabase(databasePath: inMemoryDatabasePath);
    userRepository = UserRepository(appDatabase);
    policeRepository = PoliceRepository(appDatabase);
    reportRepository = ReportRepository(appDatabase);
    controller = ReportController(repository: reportRepository);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('valida obligatorios antes de finalizar', () async {
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.validacion',
      plate: 'PL-001',
    );

    await expectLater(
      controller.finalize(
        actor: police,
        draft: const DirectActionReportDraft(
          epi: '',
          fechaHoraLlegada: null,
          fechaHoraHecho: null,
          naturaleza: '',
          lugar: '',
          denuncianteNombre: '',
          denuncianteDocumento: '',
          denuncianteContacto: '',
          descripcion: '',
          condicionesClimaticas: '',
          vehiculosMovidos: null,
          protagonistasPresentes: null,
          testigos: '',
          efectosPersonales: '',
        ),
        now: DateTime.utc(2026),
      ),
      throwsA(isA<ReportValidationException>()),
    );

    final db = await appDatabase.instance;
    expect(await db.query('informes'), isEmpty);
  });

  test('finaliza asociado al policia autenticado y queda en modo lectura',
      () async {
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.creador',
      plate: 'PL-002',
    );

    final finalized = await controller.finalize(
      actor: police,
      draft: _validDraft(),
      now: DateTime.utc(2026, 5, 1),
    );

    final detail = await controller.findReadableDetail(
      actor: police,
      idInforme: finalized.idInforme,
    );
    expect(finalized.numeroCaso, '2026-000001');
    expect(detail.idPolicia, police.requiredPoliceId);
    expect(detail.numeroCaso, finalized.numeroCaso);
    expect(detail.isActive, isTrue);
    expect(detail.descripcion, 'Descripcion del hecho');
  });

  test('POLICE consulta solo sus informes activos', () async {
    final firstPolice = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.uno',
      plate: 'PL-003',
    );
    final secondPolice = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.dos',
      plate: 'PL-004',
    );
    final first = await controller.finalize(
      actor: firstPolice,
      draft: _validDraft(epi: 'EPI Primero'),
      now: DateTime.utc(2026),
    );
    await controller.finalize(
      actor: secondPolice,
      draft: _validDraft(epi: 'EPI Segundo'),
      now: DateTime.utc(2026),
    );

    await controller.load(firstPolice);

    expect(controller.reports, hasLength(1));
    expect(controller.reports.single.idInforme, first.idInforme);
  });

  test('ADMIN consulta todos los activos e inactiva con soft delete', () async {
    final admin = _adminSession();
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.admin',
      plate: 'PL-005',
    );
    final report = await controller.finalize(
      actor: police,
      draft: _validDraft(),
      now: DateTime.utc(2026),
    );

    await controller.load(admin);
    expect(controller.reports, hasLength(1));

    await controller.inactivate(actor: admin, idInforme: report.idInforme);
    expect(controller.reports, isEmpty);

    final db = await appDatabase.instance;
    final stored = await db.query('informes');
    expect(stored.single['estado'], 0);
  });

  test('POLICE no puede inactivar ni leer informes ajenos', () async {
    final firstPolice = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.propietario',
      plate: 'PL-006',
    );
    final secondPolice = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.ajeno',
      plate: 'PL-007',
    );
    final report = await controller.finalize(
      actor: firstPolice,
      draft: _validDraft(),
      now: DateTime.utc(2026),
    );

    await expectLater(
      controller.inactivate(
        actor: secondPolice,
        idInforme: report.idInforme,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      controller.findReadableDetail(
        actor: secondPolice,
        idInforme: report.idInforme,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('cancelar descarta estado en memoria sin persistir', () async {
    const draft = DirectActionReportDraft(
      epi: 'EPI Temporal',
      fechaHoraLlegada: null,
      fechaHoraHecho: null,
      naturaleza: '',
      lugar: '',
      denuncianteNombre: '',
      denuncianteDocumento: '',
      denuncianteContacto: '',
      descripcion: '',
      condicionesClimaticas: '',
      vehiculosMovidos: null,
      protagonistasPresentes: null,
      testigos: '',
      efectosPersonales: '',
    );

    expect(draft.hasData, isTrue);
    final db = await appDatabase.instance;
    expect(await db.query('informes'), isEmpty);
  });
}

DirectActionReportDraft _validDraft({String epi = 'EPI Central'}) {
  return DirectActionReportDraft(
    epi: epi,
    fechaHoraLlegada: DateTime.utc(2026, 1, 1, 8),
    fechaHoraHecho: DateTime.utc(2026, 1, 1, 7),
    naturaleza: 'Colision',
    lugar: 'Av. Principal',
    denuncianteNombre: 'No existe',
    denuncianteDocumento: '',
    denuncianteContacto: 'No existe',
    descripcion: 'Descripcion del hecho',
    condicionesClimaticas: 'Despejado',
    vehiculosMovidos: false,
    protagonistasPresentes: true,
    testigos: 'No existe',
    efectosPersonales: 'No aplica',
    conductores: const [
      DriverInput(
        nombreCompleto: 'Juan Perez',
        licencia: 'LP-123',
        categoria: 'A',
        contactos: 'No aplica',
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
      PersonInput(
        nombre: 'Maria Rojas',
        edad: 30,
        tipo: 'HERIDO',
        lugarEvacuacion: 'Hospital',
      ),
    ],
  );
}

AuthenticatedUser _adminSession() {
  return const AuthenticatedUser(
    idUsuario: 1,
    username: 'admin.local',
    role: AppRole.admin,
  );
}

Future<AuthenticatedUser> _createPoliceSession(
  UserRepository userRepository,
  PoliceRepository policeRepository, {
  required String username,
  required String plate,
}) async {
  final idUsuario = await userRepository.createUser(
    username: username,
    passwordHash: 'hash:salt',
    role: AppRole.police.databaseValue,
    now: DateTime.utc(2026),
  );
  final idPolicia = await policeRepository.createPolice(
    idUsuario: idUsuario,
    numeroPlaca: plate,
    grado: 'Sgto.',
    nombres: 'Ana',
    apellidos: 'Quispe',
    unidad: 'Transito',
    sigla: 'UT',
    ci: '1234567',
    now: DateTime.utc(2026),
  );
  return AuthenticatedUser(
    idUsuario: idUsuario,
    username: username,
    role: AppRole.police,
    policeProfile: PoliceProfile(
      idPolicia: idPolicia,
      numeroPlaca: plate,
      grado: 'Sgto.',
      nombres: 'Ana',
      apellidos: 'Quispe',
      unidad: 'Transito',
      sigla: 'UT',
      ci: '1234567',
    ),
  );
}
