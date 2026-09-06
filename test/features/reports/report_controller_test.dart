import 'dart:io';

import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/authenticated_user.dart';
import 'package:app_acc_transito/features/reports/application/report_controller.dart';
import 'package:app_acc_transito/services/files/report_pdf_file_service.dart';
import 'package:app_acc_transito/services/media/evidence_photo.dart';
import 'package:app_acc_transito/services/media/evidence_media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('válida obligatorios antes de finalizar', () async {
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

  test('finaliza asociado al policía autenticado y queda en modo lectura',
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
    expect(detail.descripcion, 'Descripción del hecho');
  });

  test('GPS fallido no bloquea finalizacion y conserva lugar textual',
      () async {
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.sin.gps',
      plate: 'PL-010',
    );

    final finalized = await controller.finalize(
      actor: police,
      draft: _validDraft(lugar: 'Interseccion textual confirmada'),
      now: DateTime.utc(2026, 5, 4),
    );

    final detail = await controller.findReadableDetail(
      actor: police,
      idInforme: finalized.idInforme,
    );
    expect(detail.lugar, 'Interseccion textual confirmada');
    expect(detail.latitud, isNull);
    expect(detail.longitud, isNull);
    expect(detail.rutaCroquis, isNull);
  });

  test('persiste coordenadas y ruta PNG del croquis', () async {
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.mapa',
      plate: 'PL-011',
    );

    final finalized = await controller.finalize(
      actor: police,
      draft: _validDraft(
        latitud: -17.783327,
        longitud: -63.182140,
        rutaCroquis: '/documentos/croquis/croquis_2026_000001.png',
      ),
      now: DateTime.utc(2026, 5, 5),
    );

    final detail = await controller.findReadableDetail(
      actor: police,
      idInforme: finalized.idInforme,
    );
    expect(detail.latitud, -17.783327);
    expect(detail.longitud, -63.182140);
    expect(detail.rutaCroquis, '/documentos/croquis/croquis_2026_000001.png');
  });

  test('finaliza fotografías persistidas con categorias y relacion al informe',
      () async {
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.fotos',
      plate: 'PL-012',
    );

    final finalized = await controller.finalize(
      actor: police,
      draft: _validDraft(
        fotografias: const [
          PhotoInput(
            ruta: '/tmp/foto-a.jpg',
            tipo: EvidencePhotoCategory.panoramica,
          ),
          PhotoInput(
            ruta: '/tmp/foto-b.jpg',
            tipo: EvidencePhotoCategory.licencia,
          ),
        ],
      ),
      persistPhotosForCase: ({required numeroCaso, required photos}) async {
        expect(numeroCaso, '2026-000001');
        return [
          photos[0].copyWith(
            ruta: '/documentos/reports/$numeroCaso/images/01_panoramica.jpg',
          ),
          photos[1].copyWith(
            ruta: '/documentos/reports/$numeroCaso/images/02_licencia.jpg',
          ),
        ];
      },
      now: DateTime.utc(2026, 5, 6),
    );

    final detail = await controller.findReadableDetail(
      actor: police,
      idInforme: finalized.idInforme,
    );
    final db = await appDatabase.instance;
    final rows = await db.query('fotografias');

    expect(detail.fotografias, hasLength(2));
    expect(detail.fotografias.first.idFotografia, rows.first['id_fotografia']);
    expect(detail.fotografias.first.tipo, EvidencePhotoCategory.panoramica);
    expect(detail.fotografias.last.tipo, EvidencePhotoCategory.licencia);
    expect(rows.map((row) => row['id_informe']),
        everyElement(finalized.idInforme));
    expect(
      detail.fotografias.first.ruta,
      '/documentos/reports/2026-000001/images/01_panoramica.jpg',
    );
  });

  test('archivo inexistente de fotografía evita finalizar y no crea informe',
      () async {
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.foto.faltante',
      plate: 'PL-013',
    );

    await expectLater(
      controller.finalize(
        actor: police,
        draft: _validDraft(
          fotografias: const [
            PhotoInput(
              ruta: '/tmp/faltante.jpg',
              tipo: EvidencePhotoCategory.otra,
            ),
          ],
        ),
        persistPhotosForCase: ({required numeroCaso, required photos}) async {
          throw const FileSystemException(
            'La fotografía temporal no existe.',
            '/tmp/faltante.jpg',
          );
        },
        now: DateTime.utc(2026, 5, 7),
      ),
      throwsA(isA<FileSystemException>()),
    );

    final db = await appDatabase.instance;
    expect(await db.query('informes'), isEmpty);
    expect(await db.query('fotografias'), isEmpty);
  });

  test('finaliza varios conductores, vehículos relacionados y personas',
      () async {
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.relaciones',
      plate: 'PL-008',
    );

    final finalized = await controller.finalize(
      actor: police,
      draft: _validDraft(
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
          DriverInput(
            nombreCompleto: 'Luis Roca',
            edad: 41,
            licencia: 'SC-456',
            categoria: 'B',
            domicilio: 'Av. Sur',
            zona: 'Sur',
            contactos: '70000002',
            condicionEntrega: 'Entregado a Tránsito',
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
          VehicleInput(
            driverIndex: 1,
            placa: '456DEF',
            marca: 'Nissan',
            color: 'Rojo',
            tipo: 'Automovil',
            servicio: 'Publico',
          ),
        ],
        personas: const [
          PersonInput(
            nombre: 'Maria Rojas',
            edad: 30,
            tipo: 'HERIDO',
            lugarEvacuacion: 'Hospital',
          ),
          PersonInput(
            nombre: 'Carlos Rojas',
            edad: 52,
            tipo: 'FALLECIDO',
          ),
        ],
      ),
      now: DateTime.utc(2026, 5, 2),
    );

    final detail = await controller.findReadableDetail(
      actor: police,
      idInforme: finalized.idInforme,
    );

    expect(detail.conductores, hasLength(2));
    expect(detail.vehiculos, hasLength(2));
    expect(detail.personas, hasLength(2));
    expect(detail.vehiculos.first.idConductor,
        detail.conductores.first.idConductor);
    expect(
        detail.vehiculos.last.idConductor, detail.conductores.last.idConductor);
  });

  test('válida campos confirmados de conductores vehículos y personas',
      () async {
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.validacion.relaciones',
      plate: 'PL-009',
    );

    await expectLater(
      controller.finalize(
        actor: police,
        draft: _validDraft(
          conductores: const [
            DriverInput(nombreCompleto: 'Sin datos'),
          ],
          vehiculos: const [
            VehicleInput(driverIndex: 1),
          ],
          personas: const [
            PersonInput(nombre: 'Persona sin edad', tipo: 'OBSERVADO'),
          ],
        ),
        now: DateTime.utc(2026, 5, 3),
      ),
      throwsA(
        isA<ReportValidationException>().having(
          (error) => error.messages,
          'messages',
          containsAll([
            'Debe ingresar edad del conductor 1.',
            'Debe ingresar contactos del conductor 1.',
            'Debe ingresar placa del vehículo 1.',
            'El vehículo 1 referencia un conductor inválido.',
            'El tipo de persona 1 no es válido.',
            'Debe ingresar edad de la persona 1.',
          ]),
        ),
      ),
    );

    final db = await appDatabase.instance;
    expect(await db.query('informes'), isEmpty);
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
    final owner = await controller.findReadableOwner(
        actor: firstPolice, idInforme: first.idInforme);
    expect(owner.numeroPlaca, 'PL-003');
    await expectLater(
        controller.findReadableOwner(
            actor: secondPolice, idInforme: first.idInforme),
        throwsStateError);
    final adminOwner = await controller.findReadableOwner(
        actor: _adminSession(), idInforme: first.idInforme);
    expect(adminOwner.numeroPlaca, 'PL-003');
    await controller.inactivate(
        actor: _adminSession(), idInforme: first.idInforme);
    await expectLater(
        controller.findReadableOwner(
            actor: firstPolice, idInforme: first.idInforme),
        throwsStateError);
    await expectLater(
        controller.findReadableOwner(
            actor: _adminSession(), idInforme: first.idInforme),
        throwsStateError);
  });

  test('consultas filtran por fecha policía y excluyen inactivos', () async {
    final admin = _adminSession();
    final firstPolice = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.filtro.uno',
      plate: 'PL-014',
    );
    final secondPolice = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.filtro.dos',
      plate: 'PL-015',
    );
    final january = await controller.finalize(
      actor: firstPolice,
      draft: _validDraft(fechaHoraHecho: DateTime.utc(2026, 1, 10, 7)),
      now: DateTime.utc(2026, 1, 10),
    );
    final february = await controller.finalize(
      actor: firstPolice,
      draft: _validDraft(fechaHoraHecho: DateTime.utc(2026, 2, 5, 7)),
      now: DateTime.utc(2026, 2, 5),
    );
    await controller.finalize(
      actor: secondPolice,
      draft: _validDraft(fechaHoraHecho: DateTime.utc(2026, 1, 10, 8)),
      now: DateTime.utc(2026, 1, 10),
    );
    await controller.inactivate(actor: admin, idInforme: february.idInforme);

    await controller.load(
      admin,
      filter: ReportQueryFilter(
        idPolicia: firstPolice.requiredPoliceId,
        from: DateTime.utc(2026, 1, 10),
        to: DateTime.utc(2026, 1, 11),
      ),
    );

    expect(controller.reports, hasLength(1));
    expect(controller.reports.single.idInforme, january.idInforme);
  });

  test('POLICE no puede ampliar consultas con id_policia ajeno', () async {
    final firstPolice = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.scope.uno',
      plate: 'PL-016',
    );
    final secondPolice = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.scope.dos',
      plate: 'PL-017',
    );
    await controller.finalize(
      actor: firstPolice,
      draft: _validDraft(epi: 'Propio'),
      now: DateTime.utc(2026),
    );
    await controller.finalize(
      actor: secondPolice,
      draft: _validDraft(epi: 'Ajeno'),
      now: DateTime.utc(2026),
    );

    await controller.load(
      firstPolice,
      filter: ReportQueryFilter(idPolicia: secondPolice.requiredPoliceId),
    );

    expect(controller.reports, hasLength(1));
    expect(controller.reports.single.idPolicia, firstPolice.requiredPoliceId);
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

  test('PDF consultado por ADMIN usa QR del policía propietario', () async {
    final admin = _adminSession();
    final owner = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.dueno.pdf',
      plate: 'PL-020',
    );
    await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.no.dueno.pdf',
      plate: 'PL-021',
    );
    final report = await controller.finalize(
      actor: owner,
      draft: _validDraft(),
      now: DateTime.utc(2026),
    );

    final pdf = await controller.buildReadablePdf(
      actor: admin,
      idInforme: report.idInforme,
    );
    final payload = pdf.qrPayload.toStructuredText();

    expect(pdf.bytes, isNotEmpty);
    expect(payload, contains('Ana Quispe'));
    expect(payload, contains('PL-020'));
    expect(payload, isNot(contains('PL-021')));
    expect(payload, isNot(contains('admin.local')));
    expect(payload, isNot(contains('1234567')));
  });

  test('guardar PDF persiste ruta_pdf sin modificar contenido', () async {
    final sandbox = await Directory.systemTemp.createTemp('pdf_save_test_');
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });
    final police = await _createPoliceSession(
      userRepository,
      policeRepository,
      username: 'policia.guarda.pdf',
      plate: 'PL-022',
    );
    final finalized = await controller.finalize(
      actor: police,
      draft: _validDraft(),
      now: DateTime.utc(2026),
    );
    final pdf = await controller.buildReadablePdf(
      actor: police,
      idInforme: finalized.idInforme,
    );

    final path = await controller.saveReadablePdf(
      actor: police,
      idInforme: finalized.idInforme,
      pdf: pdf,
      fileService: ReportPdfFileService(documentsRoot: sandbox),
    );

    expect(await File(path).exists(), isTrue);
    final db = await appDatabase.instance;
    final rows = await db.query(
      'informes',
      where: 'id_informe = ?',
      whereArgs: [finalized.idInforme],
    );
    expect(rows.single['ruta_pdf'], path);
    expect(rows.single['descripcion'], 'Descripción del hecho');
    expect(path, contains('reports'));
    expect(path, endsWith('.pdf'));
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

  test('rechaza coordenadas incompletas, no finitas o fuera de rango',
      () async {
    final police = await _createPoliceSession(userRepository, policeRepository,
        username: 'coordenadas', plate: 'PL-COORD');
    for (final pair in <(double?, double?)>[
      (1, null),
      (null, 1),
      (double.nan, 0),
      (0, double.infinity),
      (91, 0),
      (0, -181)
    ]) {
      await expectLater(
          controller.finalize(
              actor: police,
              draft: _validDraft(latitud: pair.$1, longitud: pair.$2)),
          throwsA(isA<ReportValidationException>()));
    }
    expect(await reportRepository.findActiveReports(), isEmpty);
    final saved = await controller.finalize(
        actor: police, draft: _validDraft(latitud: 0, longitud: 0));
    expect(saved.numeroCaso, '2026-000001');
  });

  test('SQLite y QR conservan español al finalizar y volver a consultar',
      () async {
    final police = await _createPoliceSession(userRepository, policeRepository,
        username: 'unicode', plate: 'PL-ES');
    const text =
        'José Muñoz Peña. Información, Descripción, Ubicación, Acción, Vehículo. áéíóúñÑ';
    final saved = await controller.finalize(
        actor: police,
        draft: _validDraft(
            lugar: text,
            epi: 'División de Tránsito',
            personas: const [
              PersonInput(nombre: 'José Muñoz Peña', edad: 30, tipo: 'HERIDO')
            ]));
    final read = await controller.findReadableDetail(
        actor: _adminSession(), idInforme: saved.idInforme);
    expect(read.lugar, text);
    expect(read.epi, 'División de Tránsito');
    expect(read.personas.single.nombre, 'José Muñoz Peña');
    final db = await appDatabase.instance;
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect((await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok');
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

  test('rollback SQLite conserva fotos temporales y permite finalizar de nuevo',
      () async {
    final root = await Directory.systemTemp.createTemp('report_rollback_');
    addTearDown(() => root.delete(recursive: true));
    final media = EvidenceMediaService(
        temporaryRoot: Directory('${root.path}/tmp'),
        documentsRoot: Directory('${root.path}/docs'));
    final source = File('${root.path}/original.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final staged =
        await media.stageFile(source, category: EvidencePhotoCategory.otra);
    final police = await _createPoliceSession(userRepository, policeRepository,
        username: 'rollback', plate: 'PL-ROLL');
    final db = await appDatabase.instance;
    await db.execute(
        "CREATE TRIGGER fail_photo BEFORE INSERT ON fotografias BEGIN SELECT RAISE(ABORT, 'fallo simulado'); END");
    Future<FinalizedReport> save() => controller.finalize(
        actor: police,
        draft: _validDraft(fotografias: [staged]),
        persistPhotosForCase: media.persistPhotosForReport,
        cleanupPersistedPhotos: media.cleanupPersistentPhotos);
    await expectLater(save(), throwsA(isA<DatabaseException>()));
    expect(await db.query('informes'), isEmpty);
    expect(await db.query('conductores'), isEmpty);
    expect(await db.query('vehiculos'), isEmpty);
    expect(await File(staged.ruta).readAsBytes(), [1, 2, 3]);
    await db.execute('DROP TRIGGER fail_photo');
    final saved = await save();
    expect(saved.numeroCaso, '2026-000001');
    final detail = await controller.findReadableDetail(
        actor: police, idInforme: saved.idInforme);
    expect(await File(detail.fotografias.single.ruta).readAsBytes(), [1, 2, 3]);
  });
}

DirectActionReportDraft _validDraft({
  String epi = 'EPI Central',
  String lugar = 'Av. Principal',
  DateTime? fechaHoraHecho,
  double? latitud,
  double? longitud,
  String? rutaCroquis,
  List<DriverInput>? conductores,
  List<VehicleInput>? vehiculos,
  List<PersonInput>? personas,
  List<PhotoInput>? fotografias,
}) {
  return DirectActionReportDraft(
    epi: epi,
    fechaHoraLlegada: DateTime.utc(2026, 1, 1, 8),
    fechaHoraHecho: fechaHoraHecho ?? DateTime.utc(2026, 1, 1, 7),
    naturaleza: 'Colisión',
    lugar: lugar,
    denuncianteNombre: 'No existe',
    denuncianteDocumento: '',
    denuncianteContacto: 'No existe',
    descripcion: 'Descripción del hecho',
    condicionesClimaticas: 'Despejado',
    vehiculosMovidos: false,
    protagonistasPresentes: true,
    testigos: 'No existe',
    efectosPersonales: 'No aplica',
    latitud: latitud,
    longitud: longitud,
    rutaCroquis: rutaCroquis,
    conductores: conductores ??
        const [
          DriverInput(
            nombreCompleto: 'Juan Perez',
            edad: 34,
            licencia: 'LP-123',
            categoria: 'A',
            domicilio: 'Barrio Norte',
            zona: 'Norte',
            contactos: 'No aplica',
          ),
        ],
    vehiculos: vehiculos ??
        const [
          VehicleInput(
            driverIndex: 0,
            placa: '123ABC',
            marca: 'Toyota',
            color: 'Blanco',
            tipo: 'Vagoneta',
            servicio: 'Particular',
          ),
        ],
    personas: personas ??
        const [
          PersonInput(
            nombre: 'Maria Rojas',
            edad: 30,
            tipo: 'HERIDO',
            lugarEvacuacion: 'Hospital',
          ),
        ],
    fotografias: fotografias ?? const [],
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
    unidad: 'Tránsito',
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
      unidad: 'Tránsito',
      sigla: 'UT',
      ci: '1234567',
    ),
  );
}
