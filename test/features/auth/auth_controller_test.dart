import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/features/auth/application/auth_controller.dart';
import 'package:app_acc_transito/features/auth/data/auth_repository.dart';
import 'package:app_acc_transito/features/auth/data/password_hasher.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late UserRepository userRepository;
  late PoliceRepository policeRepository;
  late PasswordHasher passwordHasher;
  late AuthController controller;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
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
    controller = AuthController(
      AuthRepository(
        userRepository: userRepository,
        policeRepository: policeRepository,
        passwordHasher: passwordHasher,
      ),
    );
    await userRepository.createUser(
      username: 'admin.local',
      passwordHash: await passwordHasher.hash('ClaveSegura123'),
      role: AppRole.admin.databaseValue,
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('mantiene sesion solo en memoria y logout la limpia', () async {
    expect(controller.isAuthenticated, isFalse);

    await controller.login(
      username: 'admin.local',
      password: 'ClaveSegura123',
    );

    expect(controller.isAuthenticated, isTrue);
    expect(controller.currentUser?.role, AppRole.admin);

    controller.logout();

    expect(controller.isAuthenticated, isFalse);
    expect(controller.currentUser, isNull);
  });

  test('reset desde controlador exige ADMIN y cambia solo el hash', () async {
    final idUsuario = await userRepository.createUser(
      username: 'policia.local',
      passwordHash: await passwordHasher.hash('ClavePolicia123'),
      role: AppRole.police.databaseValue,
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
    );

    await controller.login(
      username: 'admin.local',
      password: 'ClaveSegura123',
    );
    await controller.resetPolicePassword(
      policeUsername: 'policia.local',
      newPassword: 'NuevaClave123',
    );
    controller.logout();

    await expectLater(
      controller.login(
        username: 'policia.local',
        password: 'ClavePolicia123',
      ),
      throwsA(isA<Exception>()),
    );
    await controller.login(
      username: 'policia.local',
      password: 'NuevaClave123',
    );
    expect(controller.currentUser?.role, AppRole.police);

    await expectLater(
      controller.resetPolicePassword(
        policeUsername: 'policia.local',
        newPassword: 'OtraClave123',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
