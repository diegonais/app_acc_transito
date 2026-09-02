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
  late AuthController controller;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    appDatabase = AppDatabase(databasePath: inMemoryDatabasePath);
    final userRepository = UserRepository(appDatabase);
    final passwordHasher = PasswordHasher(
      algorithm: Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 256,
      ),
    );
    controller = AuthController(
      AuthRepository(
        userRepository: userRepository,
        policeRepository: PoliceRepository(appDatabase),
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
}
