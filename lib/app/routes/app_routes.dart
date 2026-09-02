import 'package:flutter/material.dart';

import '../../features/auth/login/login_placeholder_page.dart';
import '../../features/auth/login/splash_page.dart';
import '../../features/dashboard/dashboard_placeholder_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';

  static Route<void> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      splash => _buildRoute(settings, const SplashPage()),
      login => _buildRoute(settings, const LoginPlaceholderPage()),
      dashboard => _buildRoute(settings, const DashboardPlaceholderPage()),
      _ => _buildRoute(settings, const LoginPlaceholderPage()),
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
