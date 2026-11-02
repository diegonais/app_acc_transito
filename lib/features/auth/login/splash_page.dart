import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../application/auth_scope.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/ui/app_logo.dart';
import '../../../shared/ui/app_state_view.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveInitialRoute();
    });
  }

  Future<void> _resolveInitialRoute() async {
    setState(() {
      _errorMessage = null;
    });
    try {
      final auth = AuthScope.of(context);
      await auth.restoreSession();
      final hasAdmin = await auth.hasAdmin();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        auth.isAuthenticated
            ? AppRoutes.dashboard
            : hasAdmin
                ? AppRoutes.login
                : AppRoutes.initialSetup,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = (AuthScope.maybeOf(context)?.isOnline ?? false)
            ? 'No se pudo restaurar la sesión en línea. Compruebe Internet y reintente.'
            : 'No se pudo preparar la autenticación local.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorMessage = _errorMessage;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 132),
                  const SizedBox(height: 28),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (AuthScope.maybeOf(context)?.isOnline ?? false)
                        ? 'DEFENSA EN LÍNEA · Requiere Internet'
                        : 'Sistema local de informes de accidentes de tránsito',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  if (errorMessage == null)
                    const AppLoadingState(message: 'Preparando aplicación')
                  else
                    AppErrorState(
                      title: 'Error de inicio',
                      message: errorMessage,
                      onRetry: _resolveInitialRoute,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
