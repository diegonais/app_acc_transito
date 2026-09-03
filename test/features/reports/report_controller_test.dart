import 'dart:io';

import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/authenticated_user.dart';
import 'package:app_acc_transito/features/reports/application/report_controller.dart';
import 'package:app_acc_transito/services/media/evidence_photo.dart';
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

  test('finaliza fotografias persistidas con categorias y relacion al informe',
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

  test('archivo inexistente de fotografia evita finalizar y no crea informe',
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
            'La fotografia temporal no existe.',
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

  test('finaliza varios conductores, vehiculos relacionados y personas',
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
            condicionEntrega: 'Entregado a Transito',
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

  test('valida campos confirmados de conductores vehiculos y personas',
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
            'Debe ingresar placa del vehiculo 1.',
            'El vehiculo 1 referencia un conductor invalido.',
            'El tipo de persona 1 no es valido.',
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

DirectActionReportDraft _validDraft({
  String epi = 'EPI Central',
  String lugar = 'Av. Principal',
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
    fechaHoraHecho: DateTime.utc(2026, 1, 1, 7),
    naturaleza: 'Colision',
    lugar: lugar,
    denuncianteNombre: 'No existe',
    denuncianteDocumento: '',
    denuncianteContacto: 'No existe',
    descripcion: 'Descripcion del hecho',
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
