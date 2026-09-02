import 'package:flutter/material.dart';

import '../data/database/app_database.dart';
import '../data/repositories/police_repository.dart';
import '../data/repositories/user_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_scope.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/password_hasher.dart';
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

  @override
  void initState() {
    super.initState();
    final database = widget._database ?? AppDatabase();
    _authController = widget._authController ??
        AuthController(
          AuthRepository(
            userRepository: UserRepository(database),
            policeRepository: PoliceRepository(database),
            passwordHasher: PasswordHasher(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _authController,
      child: MaterialApp(
        title: 'ACC Transito',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: (settings) {
          return AppRoutes.onGenerateRoute(settings, _authController);
        },
      ),
    );
  }
}
