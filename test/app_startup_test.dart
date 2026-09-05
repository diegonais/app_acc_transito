import 'package:app_acc_transito/app/app.dart';
import 'package:app_acc_transito/app/routes/app_routes.dart';
import 'package:app_acc_transito/app/theme/app_theme.dart';
import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/police_repository.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/data/repositories/user_repository.dart';
import 'package:app_acc_transito/features/auth/application/auth_controller.dart';
import 'package:app_acc_transito/features/auth/application/auth_scope.dart';
import 'package:app_acc_transito/features/auth/data/auth_repository.dart';
import 'package:app_acc_transito/features/auth/data/password_hasher.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/auth_exceptions.dart';
import 'package:app_acc_transito/features/auth/domain/authenticated_user.dart';
import 'package:app_acc_transito/features/dashboard/application/dashboard_controller.dart';
import 'package:app_acc_transito/features/officers/application/officer_management_controller.dart';
import 'package:app_acc_transito/features/officers/data/officer_management_repository.dart';
import 'package:app_acc_transito/features/officers/domain/officer_record.dart';
import 'package:app_acc_transito/features/officers/officer_management_page.dart';
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
            _unusedDashboardController(),
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

  testWidgets('gestion de policias mueve acciones administrativas al detalle',
      (tester) async {
    final authController = _FakeAuthController(hasAdmin: true)
      .._user = const AuthenticatedUser(
        idUsuario: 1,
        username: 'admin.local',
        role: AppRole.admin,
      );
    final officerController = _FakeOfficerManagementController(
      officers: const [
        OfficerRecord(
          idPolicia: 1,
          idUsuario: 2,
          numeroPlaca: 'PL-001',
          grado: 'Sgto.',
          nombres: 'Ana Maria',
          apellidos: 'Quispe Rojas',
          unidad: 'Transito Norte',
          sigla: 'UTN',
          ci: '1234567',
          username: 'ana.quispe',
          estadoPolicia: 1,
          estadoUsuario: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      AuthScope(
        controller: authController,
        child: MaterialApp(
          theme: AppTheme.light,
          home: OfficerManagementPage(controller: officerController),
        ),
      ),
    );
    await _pumpUntilVisible(tester, find.text('Ver'));

    expect(find.text('Policias registrados'), findsOneWidget);
    expect(find.text('1 policia registrado'), findsOneWidget);
    expect(find.text('Sgto. Ana Maria Quispe Rojas'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Restablecer contrasena'), findsNothing);
    expect(find.text('Desactivar usuario'), findsNothing);

    await tester.tap(find.text('Ver'));
    await _pumpUntilVisible(tester, find.text('Detalle del policia'));

    expect(find.text('Informacion del policia'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Acciones'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Restablecer contrasena'), findsOneWidget);
    expect(find.text('Desactivar usuario'), findsOneWidget);
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

class _FakeOfficerManagementController extends OfficerManagementController {
  _FakeOfficerManagementController({
    required List<OfficerRecord> officers,
  })  : _officers = officers,
        super(
          repository: OfficerManagementRepository(
            AppDatabase(databasePath: ':memory:'),
          ),
          passwordHasher: PasswordHasher(
            algorithm: Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: 1000,
              bits: 256,
            ),
          ),
        );

  final List<OfficerRecord> _officers;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  List<OfficerRecord> get officers => _officers;

  @override
  Future<void> load(AuthenticatedUser actor) async {}
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

DashboardController _unusedDashboardController() {
  final database = AppDatabase(databasePath: ':memory:');
  return DashboardController(repository: ReportRepository(database));
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
