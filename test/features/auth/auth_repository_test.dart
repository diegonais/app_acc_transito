import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/features/auth/data/auth_repository.dart';
import 'package:app_acc_transito/features/auth/data/password_hasher.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/auth_exceptions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late UserRepository userRepository;
  late PoliceRepository policeRepository;
  late PasswordHasher passwordHasher;
  late AuthRepository authRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    appDatabase = AppDatabase(databasePath: inMemoryDatabasePath);
    userRepository = UserRepository(appDatabase);
    policeRepository = PoliceRepository(appDatabase);
    passwordHasher = PasswordHasher(
      algorithm: Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 256,
      ),
    );
    authRepository = AuthRepository(
      userRepository: userRepository,
      policeRepository: policeRepository,
      passwordHasher: passwordHasher,
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('crea el primer ADMIN con hash y salt, no texto plano', () async {
    expect(await authRepository.hasAdmin(), isFalse);

    await authRepository.createFirstAdmin(
      username: 'admin.local',
      password: 'ClaveSegura123',
      now: DateTime.utc(2026),
    );

    final db = await appDatabase.instance;
    final admin = (await db.query('usuarios')).single;
    final storedHash = admin['contrasena_hash'] as String;

    expect(await authRepository.hasAdmin(), isTrue);
    expect(admin['rol'], AppRole.admin.databaseValue);
    expect(storedHash, isNot('ClaveSegura123'));
    expect(storedHash.startsWith(r'pbkdf2_sha256$'), isTrue);
    expect(
        await passwordHasher.verify(
          password: 'ClaveSegura123',
          encodedHash: storedHash,
        ),
        isTrue);
  });

  test('no permite recrear configuracion inicial si ya existe ADMIN', () async {
    await authRepository.createFirstAdmin(
      username: 'admin.local',
      password: 'ClaveSegura123',
    );

    await expectLater(
      authRepository.createFirstAdmin(
        username: 'otro.admin',
        password: 'OtraClave123',
      ),
      throwsA(isA<AuthorizationException>()),
    );
  });

  test('login valido carga usuario ADMIN', () async {
    await authRepository.createFirstAdmin(
      username: 'admin.local',
      password: 'ClaveSegura123',
    );

    final session = await authRepository.login(
      username: 'admin.local',
      password: 'ClaveSegura123',
    );

    expect(session.role, AppRole.admin);
    expect(session.policeProfile, isNull);
  });

  test('login de POLICE carga datos del policia', () async {
    await _createPoliceUser(
      userRepository: userRepository,
      policeRepository: policeRepository,
      passwordHasher: passwordHasher,
    );

    final session = await authRepository.login(
      username: 'policia.local',
      password: 'ClavePolicia123',
    );

    expect(session.role, AppRole.police);
    expect(session.policeProfile?.grado, 'Sgto.');
    expect(session.policeProfile?.nombreCompleto, 'Ana Quispe');
    expect(session.policeProfile?.unidad, 'Transito');
    expect(session.policeProfile?.idPolicia, isPositive);
  });

  test('rechaza contrasena incorrecta, usuario inexistente e inactivo',
      () async {
    await authRepository.createFirstAdmin(
      username: 'admin.local',
      password: 'ClaveSegura123',
    );

    await expectLater(
      authRepository.login(username: 'admin.local', password: 'incorrecta123'),
      throwsA(isA<InvalidCredentialsException>()),
    );
    await expectLater(
      authRepository.login(username: 'nadie', password: 'ClaveSegura123'),
      throwsA(isA<InvalidCredentialsException>()),
    );

    final db = await appDatabase.instance;
    await db.update(
      'usuarios',
      {'estado': 0},
      where: 'nombre_usuario = ?',
      whereArgs: ['admin.local'],
    );
    await expectLater(
      authRepository.login(username: 'admin.local', password: 'ClaveSegura123'),
      throwsA(isA<InactiveUserException>()),
    );
  });

  test('aplica roles en logica y permite reset local de contrasena policial',
      () async {
    await authRepository.createFirstAdmin(
      username: 'admin.local',
      password: 'ClaveSegura123',
    );
    await _createPoliceUser(
      userRepository: userRepository,
      policeRepository: policeRepository,
      passwordHasher: passwordHasher,
    );
    final admin = await authRepository.login(
      username: 'admin.local',
      password: 'ClaveSegura123',
    );
    final police = await authRepository.login(
      username: 'policia.local',
      password: 'ClavePolicia123',
    );

    expect(
      () => authRepository.requireRole(police, AppRole.admin),
      throwsA(isA<AuthorizationException>()),
    );

    await authRepository.resetPolicePassword(
      actor: admin,
      policeUsername: 'policia.local',
      newPassword: 'NuevaClave123',
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
        isA<Object>());
  });
}

Future<void> _createPoliceUser({
  required UserRepository userRepository,
  required PoliceRepository policeRepository,
  required PasswordHasher passwordHasher,
}) async {
  final idUsuario = await userRepository.createUser(
    username: 'policia.local',
    passwordHash: await passwordHasher.hash('ClavePolicia123'),
    role: AppRole.police.databaseValue,
    now: DateTime.utc(2026),
  );
  await policeRepository.createPolice(
    idUsuario: idUsuario,
    numeroPlaca: 'PL-001',
    grado: 'Sgto.',
    nombres: 'Ana',
    apellidos: 'Quispe',
    unidad: 'Transito',
    sigla: 'UT',
    ci: '1234567',
    now: DateTime.utc(2026),
  );
}
