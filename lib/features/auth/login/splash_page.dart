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
      final hasAdmin = await AuthScope.of(context).hasAdmin();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        hasAdmin ? AppRoutes.login : AppRoutes.initialSetup,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'No se pudo preparar la autenticacion local.';
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
                    'Sistema local de informes de accidentes de transito',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  if (errorMessage == null)
                    const AppLoadingState(message: 'Preparando aplicacion')
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
