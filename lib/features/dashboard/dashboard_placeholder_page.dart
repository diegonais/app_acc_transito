import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../shared/scaffold_shell.dart';
import '../../shared/ui/app_button.dart';
import '../auth/application/auth_scope.dart';
import '../auth/domain/app_role.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const SizedBox.shrink();
    }

    final profile = user.policeProfile;

    return AppScaffoldShell(
      title: 'Inicio',
      actions: [
        IconButton(
          tooltip: 'Cerrar sesion',
          onPressed: () {
            auth.logout();
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          },
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            user.isAdmin ? 'Administrador' : 'Policia',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text('Usuario: ${user.username}'),
          Text('Rol: ${user.role.databaseValue}'),
          if (profile != null) ...[
            const SizedBox(height: 16),
            Text('Grado: ${profile.grado}'),
            Text('Nombre: ${profile.nombreCompleto}'),
            Text('Unidad: ${profile.unidad}'),
            Text('Placa: ${profile.numeroPlaca}'),
            Text('ID policia: ${profile.idPolicia}'),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: user.isAdmin ? 'Consultar informes' : 'Registrar informe',
            icon: user.isAdmin
                ? Icons.assignment_outlined
                : Icons.note_add_outlined,
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.reports);
            },
          ),
          const SizedBox(height: 12),
          if (user.role == AppRole.admin)
            AppButton(
              label: 'Gestionar policias',
              icon: Icons.admin_panel_settings_outlined,
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.officers);
              },
            ),
        ],
      ),
    );
  }
}
