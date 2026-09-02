import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class AccTransitoApp extends StatelessWidget {
  const AccTransitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACC Transito',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
