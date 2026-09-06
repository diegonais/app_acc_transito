import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/database/app_database.dart';
import '../data/repositories/police_repository.dart';
import '../data/repositories/report_repository.dart';
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
  })  : _database = database,
        _authController = authController;

  final AppDatabase? _database;
  final AuthController? _authController;

  @override
  State<AccTransitoApp> createState() => _AccTransitoAppState();
}

class _AccTransitoAppState extends State<AccTransitoApp> {
  late final AuthController _authController;
  late final OfficerManagementController _officerManagementController;
  late final DashboardController _dashboardController;
  late final ReportController _reportController;

  @override
  void initState() {
    super.initState();
    final database = widget._database ?? AppDatabase();
    final passwordHasher = PasswordHasher();
    _authController = widget._authController ??
        AuthController(
          AuthRepository(
            userRepository: UserRepository(database),
            policeRepository: PoliceRepository(database),
            passwordHasher: passwordHasher,
          ),
        );
    _officerManagementController = OfficerManagementController(
      repository: OfficerManagementRepository(database),
      passwordHasher: passwordHasher,
    );
    final reportRepository = ReportRepository(database);
    _dashboardController = DashboardController(repository: reportRepository);
    _reportController = ReportController(
      repository: reportRepository,
    );
    _authController.addListener(_resetSessionData);
  }

  void _resetSessionData() {
    _reportController.reset();
    _dashboardController.reset();
    _officerManagementController.reset();
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
