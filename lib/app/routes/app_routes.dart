import 'package:flutter/material.dart';

import '../../features/auth/login/login_placeholder_page.dart';
import '../../features/auth/login/initial_admin_setup_page.dart';
import '../../features/auth/login/splash_page.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/dashboard/dashboard_placeholder_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String initialSetup = '/setup';
  static const String login = '/login';
  static const String dashboard = '/dashboard';

  static Route<void> onGenerateRoute(
    RouteSettings settings,
    AuthController authController,
  ) {
    return switch (settings.name) {
      splash => _buildRoute(settings, const SplashPage()),
      initialSetup => _buildRoute(settings, const InitialAdminSetupPage()),
      login => _buildRoute(settings, const LoginPage()),
      dashboard when authController.isAuthenticated =>
        _buildRoute(settings, const DashboardPage()),
      dashboard => _buildRoute(settings, const LoginPage()),
      _ => _buildRoute(settings, const LoginPage()),
    };
  }

  static MaterialPageRoute<void> _buildRoute(
    RouteSettings settings,
    Widget page,
  ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => page,
    );
  }
}
