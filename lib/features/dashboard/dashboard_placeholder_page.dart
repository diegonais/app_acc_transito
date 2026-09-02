import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../shared/scaffold_shell.dart';
import '../../shared/ui/app_button.dart';
import '../auth/application/auth_controller.dart';
import '../auth/application/auth_scope.dart';
import '../auth/domain/app_role.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _policeUsernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isResetting = false;
  String? _resetMessage;

  @override
  void dispose() {
    _policeUsernameController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

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
          if (user.role == AppRole.admin) _buildResetPanel(context, auth),
        ],
      ),
    );
  }

  Widget _buildResetPanel(BuildContext context, AuthController auth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Restablecer contrasena de policia',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _policeUsernameController,
              decoration: const InputDecoration(
                labelText: 'Usuario policia',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'Nueva contrasena',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _resetPassword(auth),
            ),
            if (_resetMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _resetMessage!,
                style: TextStyle(
                  color: _resetMessage == 'Contrasena restablecida.'
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: _isResetting ? 'Restableciendo' : 'Restablecer',
              icon: Icons.password_rounded,
              onPressed: _isResetting ? null : () => _resetPassword(auth),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPassword(AuthController auth) async {
    setState(() {
      _isResetting = true;
      _resetMessage = null;
    });
    try {
      await auth.resetPolicePassword(
        policeUsername: _policeUsernameController.text,
        newPassword: _newPasswordController.text,
      );
      _newPasswordController.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _resetMessage = 'Contrasena restablecida.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resetMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }
}
