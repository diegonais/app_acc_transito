import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/features/auth/data/auth_repository.dart';
import 'package:app_acc_transito/features/auth/data/password_hasher.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/auth_exceptions.dart';
import 'package:app_acc_transito/features/officers/data/officer_management_repository.dart';
import 'package:app_acc_transito/features/officers/domain/officer_management_exceptions.dart';
import 'package:app_acc_transito/features/officers/domain/officer_record.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late PasswordHasher passwordHasher;
  late OfficerManagementRepository officerRepository;
  late AuthRepository authRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    appDatabase = AppDatabase(databasePath: inMemoryDatabasePath);
    passwordHasher = PasswordHasher(
      algorithm: Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 256,
      ),
    );
    officerRepository = OfficerManagementRepository(appDatabase);
    authRepository = AuthRepository(
      userRepository: UserRepository(appDatabase),
      policeRepository: PoliceRepository(appDatabase),
      passwordHasher: passwordHasher,
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('alta valida crea usuario POLICE y policia relacionados', () async {
    final idPolicia = await _createOfficer(
      officerRepository,
      passwordHasher,
    );

    final officers = await officerRepository.listOfficers();
    final db = await appDatabase.instance;
    final users = await db.query('usuarios');

    expect(idPolicia, isPositive);
    expect(officers.single.idPolicia, idPolicia);
    expect(officers.single.idUsuario, users.single['id_usuario']);
    expect(officers.single.username, 'policia.local');
    expect(users.single['rol'], AppRole.police.databaseValue);
    expect(users.single['estado'], 1);
    expect(officers.single.estadoPolicia, 1);
  });

  test('rechaza usuario duplicado y no crea registros parciales', () async {
    await _createOfficer(officerRepository, passwordHasher);

    await expectLater(
      _createOfficer(
        officerRepository,
        passwordHasher,
        plate: 'PL-002',
      ),
      throwsA(isA<DuplicateUsernameException>()),
    );

    final db = await appDatabase.instance;
    expect(await db.query('usuarios'), hasLength(1));
    expect(await db.query('policias'), hasLength(1));
  });

  test('rechaza placa duplicada y no deja usuario huerfano', () async {
    await _createOfficer(officerRepository, passwordHasher);

    await expectLater(
      _createOfficer(
        officerRepository,
        passwordHasher,
        username: 'otro.policia',
      ),
      throwsA(isA<DuplicatePlateException>()),
    );

    final db = await appDatabase.instance;
    expect(await db.query('usuarios'), hasLength(1));
    expect(await db.query('policias'), hasLength(1));
  });

  test('actualiza datos administrativos autorizados', () async {
    await _createOfficer(officerRepository, passwordHasher);
    final officer = (await officerRepository.listOfficers()).single;

    await officerRepository.updateOfficerAdministrativeData(
      OfficerUpdateInput(
        idPolicia: officer.idPolicia,
        idUsuario: officer.idUsuario,
        numeroPlaca: 'PL-010',
        grado: 'Tte.',
        nombres: 'Ana Maria',
        apellidos: 'Quispe Rojas',
        unidad: 'Transito Norte',
        sigla: 'UTN',
        ci: '7654321',
        username: 'ana.quispe',
      ),
      now: DateTime.utc(2026, 2),
    );

    final updated = (await officerRepository.listOfficers()).single;
    expect(updated.numeroPlaca, 'PL-010');
    expect(updated.grado, 'Tte.');
    expect(updated.nombreCompleto, 'Ana Maria Quispe Rojas');
    expect(updated.unidad, 'Transito Norte');
    expect(updated.sigla, 'UTN');
    expect(updated.ci, '7654321');
    expect(updated.username, 'ana.quispe');
  });

  test('activa y desactiva policia junto al usuario asociado', () async {
    await _createOfficer(officerRepository, passwordHasher);
    final officer = (await officerRepository.listOfficers()).single;

    await officerRepository.setOfficerActive(
      idPolicia: officer.idPolicia,
      idUsuario: officer.idUsuario,
      isActive: false,
      now: DateTime.utc(2026, 2),
    );

    var updated = (await officerRepository.listOfficers()).single;
    expect(updated.estadoPolicia, 0);
    expect(updated.estadoUsuario, 0);
    expect(updated.isActive, isFalse);

    await officerRepository.setOfficerActive(
      idPolicia: officer.idPolicia,
      idUsuario: officer.idUsuario,
      isActive: true,
      now: DateTime.utc(2026, 3),
    );

    updated = (await officerRepository.listOfficers()).single;
    expect(updated.estadoPolicia, 1);
    expect(updated.estadoUsuario, 1);
    expect(updated.isActive, isTrue);
  });

  test('login queda bloqueado para policia inactivo', () async {
    await _createOfficer(officerRepository, passwordHasher);
    final officer = (await officerRepository.listOfficers()).single;

    await officerRepository.setOfficerActive(
      idPolicia: officer.idPolicia,
      idUsuario: officer.idUsuario,
      isActive: false,
    );

    await expectLater(
      authRepository.login(
        username: 'policia.local',
        password: 'ClavePolicia123',
      ),
      throwsA(isA<InactiveUserException>()),
    );
  });

  test('login carga relacion usuario-policia activa', () async {
    await _createOfficer(officerRepository, passwordHasher);

    final session = await authRepository.login(
      username: 'policia.local',
      password: 'ClavePolicia123',
    );

    expect(session.role, AppRole.police);
    expect(session.policeProfile?.numeroPlaca, 'PL-001');
    expect(session.policeProfile?.ci, '1234567');
    expect(session.requiredPoliceId, isPositive);
  });

  test('restablecimiento cambia hash sin exponer contrasena anterior',
      () async {
    await _createOfficer(officerRepository, passwordHasher);
    final officer = (await officerRepository.listOfficers()).single;

    await officerRepository.resetPassword(
      idUsuario: officer.idUsuario,
      passwordHash: await passwordHasher.hash('NuevaClave123'),
      now: DateTime.utc(2026, 2),
    );

    await expectLater(
      authRepository.login(
        username: 'policia.local',
        password: 'ClavePolicia123',
      ),
      throwsA(isA<InvalidCredentialsException>()),
    );
    expect(
      await authRepository.login(
        username: 'policia.local',
        password: 'NuevaClave123',
      ),
      isA<Object>(),
    );
  });
}

Future<int> _createOfficer(
  OfficerManagementRepository repository,
  PasswordHasher passwordHasher, {
  String username = 'policia.local',
  String plate = 'PL-001',
}) async {
  return repository.createOfficerAccount(
    OfficerAccountInput(
      numeroPlaca: plate,
      grado: 'Sgto.',
      nombres: 'Ana',
      apellidos: 'Quispe',
      unidad: 'Transito',
      sigla: 'UT',
      ci: '1234567',
      username: username,
      passwordHash: await passwordHasher.hash('ClavePolicia123'),
      isActive: true,
    ),
    now: DateTime.utc(2026),
  );
}
