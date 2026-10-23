import 'package:app_acc_transito/data/models/report_date_bounds.dart';
import 'package:app_acc_transito/data/repositories/report_repository_contract.dart';
import 'package:app_acc_transito/features/auth/application/auth_controller.dart';
import 'package:app_acc_transito/features/auth/data/password_hasher.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/auth_repository_contract.dart';
import 'package:app_acc_transito/features/auth/domain/authenticated_user.dart';
import 'package:app_acc_transito/features/dashboard/application/dashboard_controller.dart';
import 'package:app_acc_transito/features/officers/application/officer_management_controller.dart';
import 'package:app_acc_transito/features/officers/domain/officer_management_repository_contract.dart';
import 'package:app_acc_transito/features/officers/domain/officer_record.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

const _admin = AuthenticatedUser(
  idUsuario: 1,
  username: 'admin.ficticio',
  role: AppRole.admin,
);
const _police = AuthenticatedUser(
  idUsuario: 2,
  username: 'policia.ficticio',
  role: AppRole.police,
  policeProfile: PoliceProfile(
    idPolicia: 7,
    numeroPlaca: 'F-7',
    grado: 'Sgto.',
    nombres: 'Ana',
    apellidos: 'Muñoz',
    unidad: 'Tránsito',
    sigla: 'UT',
    ci: 'F-7',
  ),
);

void main() {
  test('AuthController admite un contrato sin SQLite y conserva sesión local',
      () async {
    final repository = _AuthFake();
    final controller = AuthController(repository);
    addTearDown(controller.dispose);

    expect(await controller.hasAdmin(), isTrue);
    await controller.login(
        username: 'admin.ficticio', password: 'ClaveFicticia');
    expect(controller.currentUser, same(_admin));
    controller.requireRole(AppRole.admin);
    expect(repository.checkedRole, AppRole.admin);
    controller.logout();
    expect(controller.currentUser, isNull);
  });

  test('gestión usa el contrato y conserva hash local y restricción ADMIN',
      () async {
    final repository = _OfficersFake();
    final hasher = PasswordHasher(
      algorithm: Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 256,
      ),
    );
    final controller = OfficerManagementController(
      repository: repository,
      passwordHasher: hasher,
    );
    addTearDown(controller.dispose);

    await expectLater(controller.load(_police), throwsStateError);
    expect(repository.loads, 0);
    await controller.createOfficer(
      actor: _admin,
      numeroPlaca: 'F-7',
      grado: 'Sgto.',
      nombres: 'Ana',
      apellidos: 'Muñoz',
      unidad: 'Tránsito',
      sigla: 'UT',
      ci: 'F-7',
      username: 'policia.ficticio',
      initialPassword: 'ClaveFicticia',
      isActive: true,
    );
    expect(repository.loads, 1);
    expect(repository.created?.username, 'policia.ficticio');
    expect(
      await hasher.verify(
        password: 'ClaveFicticia',
        encodedHash: repository.created!.passwordHash,
      ),
      isTrue,
    );
    expect(controller.errorMessage, isNull);
  });

  for (final actor in [_admin, _police]) {
    test('dashboard usa contrato, reloj y ámbito de ${actor.role.name}',
        () async {
      final repository = _DashboardFake();
      final controller = DashboardController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load(actor);
      final expectedPolice = actor.isAdmin ? null : actor.requiredPoliceId;
      expect(repository.boundsPolice, expectedPolice);
      expect(repository.queriedPolice, expectedPolice);
      expect(repository.adminQuery, actor.isAdmin);
      expect(repository.referenceDate, repository.clock());
      expect(controller.selectedDate, DateTime(2026, 9, 13));
      expect(controller.stats?.totalActiveReports, 3);
      expect(controller.errorMessage, isNull);
    });
  }
}

// Una llamada no configurada falla; los dobles no heredan implementaciones SQLite.
mixin _UnexpectedCalls {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'Operación no prevista en esta prueba: ${invocation.memberName}');
}

class _AuthFake with _UnexpectedCalls implements AuthRepositoryContract {
  AppRole? checkedRole;

  @override
  Future<bool> hasAdmin() async => true;

  @override
  Future<AuthenticatedUser> login({
    required String username,
    required String password,
  }) async =>
      _admin;

  @override
  void requireRole(AuthenticatedUser user, AppRole role) {
    expect(user, same(_admin));
    checkedRole = role;
  }
}

class _OfficersFake
    with _UnexpectedCalls
    implements OfficerManagementRepositoryContract {
  OfficerAccountInput? created;
  int loads = 0;

  @override
  Future<int> createOfficerAccount(OfficerAccountInput input,
      {DateTime? now}) async {
    created = input;
    return 7;
  }

  @override
  Future<List<OfficerRecord>> listOfficers() async {
    loads++;
    return [];
  }
}

class _DashboardFake with _UnexpectedCalls implements ReportRepositoryContract {
  int? boundsPolice;
  int? queriedPolice;
  bool? adminQuery;
  DateTime? referenceDate;

  @override
  DateTime Function() get clock => () => DateTime(2026, 9, 13, 12);

  @override
  Future<ReportDateBounds> loadDateBounds({int? idPolicia}) async {
    boundsPolice = idPolicia;
    return ReportDateBounds(today: clock());
  }

  @override
  Future<DashboardStats> loadAdminDashboard({
    required DateTime referenceDate,
    DateTime? selectedDate,
  }) async {
    adminQuery = true;
    this.referenceDate = referenceDate;
    return _stats;
  }

  @override
  Future<DashboardStats> loadPoliceDashboard({
    required int idPolicia,
    required DateTime referenceDate,
    DateTime? selectedDate,
  }) async {
    adminQuery = false;
    queriedPolice = idPolicia;
    this.referenceDate = referenceDate;
    return _stats;
  }

  static const _stats = DashboardStats(
    totalActiveReports: 3,
    activePoliceCount: 1,
    reportsToday: 0,
    reportsThisMonth: 0,
    reportsBySelectedDate: 0,
    reportsByPolice: [],
    reportsByMonth: [],
  );
}
