import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../data/remote/remote_gateway.dart';
import '../data/remote/online_report_repository.dart';
import '../features/auth/data/online_auth_repository.dart';
import '../features/officers/data/online_officer_management_repository.dart';

import '../data/database/app_database.dart';
import '../data/repositories/police_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/report_repository_contract.dart';
import '../data/repositories/user_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_scope.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/password_hasher.dart';
import '../features/dashboard/application/dashboard_controller.dart';
import '../features/officers/application/officer_management_controller.dart';
import '../features/officers/data/officer_management_repository.dart';
import '../features/reports/application/report_controller.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class AccTransitoApp extends StatefulWidget {
  const AccTransitoApp({
    super.key,
    AppDatabase? database,
    AuthController? authController,
    this.remoteGateway,
  })  : _database = database,
        _authController = authController;

  final AppDatabase? _database;
  final RemoteGateway? remoteGateway;
  final AuthController? _authController;

  @override
  State<AccTransitoApp> createState() => _AccTransitoAppState();
}

class _AccTransitoAppState extends State<AccTransitoApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _hadSession = false;
  late final AuthController _authController;
  late final OfficerManagementController _officerManagementController;
  late final DashboardController _dashboardController;
  late final ReportController _reportController;

  @override
  void initState() {
    super.initState();
    // ONLINE no construye ni abre AppDatabase, incluso con fallos de conexión.
    final remote = widget.remoteGateway;
    final database = remote == null ? widget._database ?? AppDatabase() : null;
    final passwordHasher = PasswordHasher();
    _authController = widget._authController ??
        AuthController(
          remote != null
              ? OnlineAuthRepository(remote)
              : AuthRepository(
                  userRepository: UserRepository(database!),
                  policeRepository: PoliceRepository(database),
                  passwordHasher: passwordHasher,
                ),
        );
    _officerManagementController = OfficerManagementController(
      repository: remote != null
          ? OnlineOfficerManagementRepository()
          : OfficerManagementRepository(database!),
      passwordHasher: passwordHasher,
    );
    final ReportRepositoryContract reportRepository = remote != null
        ? OnlineReportRepository(remote)
        : ReportRepository(database!);
    _dashboardController = DashboardController(repository: reportRepository);
    _reportController = ReportController(
      repository: reportRepository,
    );
    _authController.addListener(_resetSessionData);
  }

  void _resetSessionData() {
    final lostSession = _hadSession && !_authController.isAuthenticated;
    _hadSession = _authController.isAuthenticated;
    _reportController.reset();
    _dashboardController.reset();
    _officerManagementController.reset();
    if (lostSession && _authController.isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_authController.isAuthenticated) {
          _navigatorKey.currentState
              ?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        }
      });
    }
  }

  @override
  void dispose() {
    _authController.removeListener(_resetSessionData);
    _reportController.dispose();
    _dashboardController.dispose();
    _officerManagementController.dispose();
    if (widget._authController == null) _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _authController,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'ACC Tránsito',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'BO'),
        supportedLocales: const [Locale('es', 'BO')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        theme: AppTheme.light,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: (settings) {
          return AppRoutes.onGenerateRoute(
            settings,
            _authController,
            _officerManagementController,
            _dashboardController,
            _reportController,
          );
        },
      ),
    );
  }
}
