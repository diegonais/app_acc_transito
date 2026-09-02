import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../shared/scaffold_shell.dart';
import '../../../shared/ui/app_logo.dart';
import '../../../shared/ui/app_state_view.dart';

class LoginPlaceholderPage extends StatelessWidget {
  const LoginPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Ingreso',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo(size: 96)),
                const SizedBox(height: 24),
                AppEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Login pendiente',
                  message:
                      'La autenticacion local se implementara en la Fase 2.',
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.dashboard);
                  },
                  icon: const Icon(Icons.route_rounded),
                  label: const Text('Validar ruta base'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
