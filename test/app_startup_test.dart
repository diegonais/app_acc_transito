import 'package:app_acc_transito/app/app.dart';
import 'package:app_acc_transito/app/routes/app_routes.dart';
import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/features/auth/application/auth_controller.dart';
import 'package:app_acc_transito/features/auth/data/auth_repository.dart';
import 'package:app_acc_transito/features/auth/data/password_hasher.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/auth_exceptions.dart';
import 'package:app_acc_transito/features/auth/domain/authenticated_user.dart';
import 'package:app_acc_transito/features/officers/application/officer_management_controller.dart';
import 'package:app_acc_transito/features/officers/data/officer_management_repository.dart';
import 'package:app_acc_transito/features/reports/application/report_controller.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts with setup when no ADMIN exists', (tester) async {
    final controller = _FakeAuthController(hasAdmin: false);

    await tester.pumpWidget(_buildTestApp(controller));
    await _pumpUntilVisible(tester, find.text('Configuracion inicial'));

    expect(find.byType(Image), findsAtLeastNWidgets(1));
    expect(find.text('Configuracion inicial'), findsOneWidget);
    expect(find.text('Crear primer Administrador'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'ClaveSegura123');
    await tester.enterText(find.byType(TextFormField).at(2), 'ClaveSegura123');
    await tester.tap(find.text('Crear ADMIN'));
    await _pumpUntilVisible(tester, find.text('Ingreso'));

    expect(find.text('Ingreso'), findsAtLeastNWidgets(1));
    expect(find.text('Login local'), findsOneWidget);
  });

  testWidgets('login valido abre dashboard y logout protege navegacion',
      (tester) async {
    final controller = _FakeAuthController(hasAdmin: true);

    await tester.pumpWidget(_buildTestApp(controller));
    await _pumpUntilVisible(tester, find.text('Ingreso'));

    expect(find.text('Ingreso'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'ClaveSegura123');
    await tester.tap(find.text('Ingresar'));
    await _pumpUntilVisible(tester, find.text('Inicio'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout_rounded));
    await _pumpUntilVisible(tester, find.text('Ingreso'));

    expect(find.text('Ingreso'), findsOneWidget);

    Navigator.of(tester.element(find.text('Ingreso'))).pushNamed(
      AppRoutes.dashboard,
    );
    await _pumpUntilVisible(tester, find.text('Ingreso'));

    expect(find.text('Ingreso'), findsAtLeastNWidgets(1));
  });

  testWidgets('login muestra error para credenciales incorrectas',
      (tester) async {
    final controller = _FakeAuthController(hasAdmin: true);

    await tester.pumpWidget(_buildTestApp(controller));
    await _pumpUntilVisible(tester, find.text('Ingreso'));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'incorrecta123');
    await tester.tap(find.text('Ingresar'));
    await _pumpUntilVisible(
      tester,
      find.textContaining('Usuario o contrasena incorrectos'),
    );

    expect(
      find.textContaining('Usuario o contrasena incorrectos'),
      findsOneWidget,
    );
  });

  testWidgets('unknown routes resolve to login', (tester) async {
    final controller = _FakeAuthController(hasAdmin: true);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          return AppRoutes.onGenerateRoute(
            settings,
            controller,
            _unusedOfficerController(),
            _unusedReportController(),
          );
        },
        initialRoute: '/ruta-no-registrada',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ingreso'), findsOneWidget);
    expect(find.text('Login local'), findsOneWidget);
  });
}

Widget _buildTestApp(AuthController controller) {
  return AccTransitoApp(authController: controller);
}

class _FakeAuthController extends AuthController {
  _FakeAuthController({required bool hasAdmin})
      : _hasAdmin = hasAdmin,
        super(_unusedRepository());

  bool _hasAdmin;
  AuthenticatedUser? _user;

  @override
  AuthenticatedUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  Future<bool> hasAdmin() async => _hasAdmin;

  @override
  Future<void> createFirstAdmin({
    required String username,
    required String password,
  }) async {
    _hasAdmin = true;
  }

  @override
  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (username.trim() != 'admin.local' || password != 'ClaveSegura123') {
      throw const InvalidCredentialsException();
    }
    _user = const AuthenticatedUser(
      idUsuario: 1,
      username: 'admin.local',
      role: AppRole.admin,
    );
    notifyListeners();
  }

  @override
  void logout() {
    _user = null;
    notifyListeners();
  }

  @override
  Future<void> resetPolicePassword({
    required String policeUsername,
    required String newPassword,
  }) async {}
}

AuthRepository _unusedRepository() {
  final database = AppDatabase(databasePath: ':memory:');
  return AuthRepository(
    userRepository: UserRepository(database),
    policeRepository: PoliceRepository(database),
    passwordHasher: PasswordHasher(
      algorithm: Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 256,
      ),
    ),
  );
}

OfficerManagementController _unusedOfficerController() {
  final database = AppDatabase(databasePath: ':memory:');
  return OfficerManagementController(
    repository: OfficerManagementRepository(database),
    passwordHasher: PasswordHasher(
      algorithm: Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 256,
      ),
    ),
  );
}

ReportController _unusedReportController() {
  final database = AppDatabase(databasePath: ':memory:');
  return ReportController(repository: ReportRepository(database));
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder,
) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}
