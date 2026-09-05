import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_theme.dart';
import '../../shared/scaffold_shell.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_state_view.dart';
import '../auth/application/auth_scope.dart';
import '../auth/domain/app_role.dart';
import '../auth/domain/authenticated_user.dart';
import 'application/officer_management_controller.dart';
import 'domain/officer_record.dart';

class OfficerManagementPage extends StatefulWidget {
  const OfficerManagementPage({
    super.key,
    required this.controller,
  });

  final OfficerManagementController controller;

  @override
  State<OfficerManagementPage> createState() => _OfficerManagementPageState();
}

class _OfficerManagementPageState extends State<OfficerManagementPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).currentUser;
      if (user != null && user.role == AppRole.admin) {
        widget.controller.load(user);
      }
    });
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
    if (user.role != AppRole.admin) {
      return AppScaffoldShell(
        title: 'Policias',
        body: AppErrorState(
          title: 'Acceso restringido',
          message: 'La gestion de policias esta disponible solo para ADMIN.',
          onRetry: () => Navigator.of(context).pushReplacementNamed(
            AppRoutes.dashboard,
          ),
        ),
      );
    }

    return AppScaffoldShell(
      title: 'Gestion de policias',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => widget.controller.load(user),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          if (controller.isLoading && controller.officers.isEmpty) {
            return const Center(
              child: AppLoadingState(message: 'Cargando policias'),
            );
          }
          final error = controller.errorMessage;
          if (error != null && controller.officers.isEmpty) {
            return AppErrorState(
              title: 'No se pudo cargar',
              message: error,
              onRetry: () => controller.load(user),
            );
          }
          if (controller.officers.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(
                  total: controller.officers.length,
                  onCreate: () => _openForm(actor: user),
                ),
                const SizedBox(height: 40),
                _EmptyOfficers(onCreate: () => _openForm(actor: user)),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(
                  total: controller.officers.length,
                  onCreate: () => _openForm(actor: user),
                );
              }
              final officer = controller.officers[index - 1];
              return _OfficerListCard(
                officer: officer,
                onView: () => _openDetail(actor: user, officer: officer),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: controller.officers.length + 1,
          );
        },
      ),
    );
  }

  Future<void> _openDetail({
    required AuthenticatedUser actor,
    required OfficerRecord officer,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _OfficerDetailPage(
          controller: widget.controller,
          actor: actor,
          officer: officer,
        ),
      ),
    );
  }

  Future<void> _openForm({
    required AuthenticatedUser actor,
    OfficerRecord? officer,
  }) async {
    final didSave = await showDialog<bool>(
      context: context,
      builder: (_) => _OfficerFormDialog(
        controller: widget.controller,
        actor: actor,
        officer: officer,
      ),
    );
    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            officer == null ? 'Policia registrado.' : 'Policia actualizado.',
          ),
        ),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.onCreate,
  });

  final int total;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Policias registrados',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$total ${total == 1 ? 'policia registrado' : 'policias registrados'}',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _EmptyOfficers extends StatelessWidget {
  const _EmptyOfficers({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppEmptyState(
              title: 'Sin policias registrados',
              message: 'Registre el primer funcionario policial.',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Registrar policia',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficerListCard extends StatelessWidget {
  const _OfficerListCard({
    required this.officer,
    required this.onView,
  });

  final OfficerRecord officer;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${officer.grado} ${officer.nombreCompleto}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Placa ${officer.numeroPlaca} · ${officer.unidad}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink.withValues(alpha: 0.68),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Usuario: ${officer.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PoliceStatusBadge(isActive: officer.isActive),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(112, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficerDetailPage extends StatefulWidget {
  const _OfficerDetailPage({
    required this.controller,
    required this.actor,
    required this.officer,
  });

  final OfficerManagementController controller;
  final AuthenticatedUser actor;
  final OfficerRecord officer;

  @override
  State<_OfficerDetailPage> createState() => _OfficerDetailPageState();
}

class _OfficerDetailPageState extends State<_OfficerDetailPage> {
  OfficerRecord get _currentOfficer {
    for (final officer in widget.controller.officers) {
      if (officer.idPolicia == widget.officer.idPolicia) {
        return officer;
      }
    }
    return widget.officer;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Detalle del policia',
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final officer = _currentOfficer;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OfficerDetailHeader(officer: officer),
              const SizedBox(height: 16),
              _OfficerInfoSection(officer: officer),
              const SizedBox(height: 16),
              _OfficerActionsSection(
                officer: officer,
                onEdit: () => _openForm(officer),
                onResetPassword: () => _openResetPassword(officer),
                onToggleStatus: () => _confirmStatusChange(officer),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(OfficerRecord officer) async {
    final didSave = await showDialog<bool>(
      context: context,
      builder: (_) => _OfficerFormDialog(
        controller: widget.controller,
        actor: widget.actor,
        officer: officer,
      ),
    );
    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Policia actualizado.')),
      );
    }
  }

  Future<void> _confirmStatusChange(OfficerRecord officer) async {
    final activate = !officer.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activate ? 'Activar policia' : 'Desactivar policia'),
        content: Text(
          activate
              ? 'El usuario asociado podra iniciar sesion nuevamente.'
              : 'El usuario asociado quedara sin acceso. No se borraran datos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(activate ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.controller.setOfficerActive(
        actor: widget.actor,
        officer: officer,
        isActive: activate,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activate ? 'Policia activado.' : 'Policia inactivo.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _openResetPassword(OfficerRecord officer) async {
    final didReset = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(
        controller: widget.controller,
        actor: widget.actor,
        officer: officer,
      ),
    );
    if (didReset == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contrasena restablecida.')),
      );
    }
  }
}

class _PoliceStatusBadge extends StatelessWidget {
  const _PoliceStatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final foreground = isActive
        ? AppColors.primaryGreen
        : AppColors.ink.withValues(alpha: 0.64);
    final background = isActive
        ? AppColors.secondaryGreen.withValues(alpha: 0.14)
        : AppColors.ink.withValues(alpha: 0.08);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_outline_rounded,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'Activo' : 'Inactivo',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficerDetailHeader extends StatelessWidget {
  const _OfficerDetailHeader({required this.officer});

  final OfficerRecord officer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.secondaryGreen.withValues(alpha: 0.16),
              child: Text(
                _initialsFor(officer.nombreCompleto),
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${officer.grado} ${officer.nombreCompleto}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usuario: ${officer.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PoliceStatusBadge(isActive: officer.isActive),
          ],
        ),
      ),
    );
  }

  String _initialsFor(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return '--';
    }
    final initials = words.take(2).map((word) => word[0].toUpperCase()).join();
    return initials.padRight(2, '-');
  }
}

class _OfficerInfoSection extends StatelessWidget {
  const _OfficerInfoSection({required this.officer});

  final OfficerRecord officer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informacion del policia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 16),
            _OfficerInfoField(
              label: 'Nombre completo',
              value: '${officer.grado} ${officer.nombreCompleto}',
            ),
            _OfficerInfoField(label: 'Placa', value: officer.numeroPlaca),
            _OfficerInfoField(label: 'Unidad', value: officer.unidad),
            _OfficerInfoField(
              label: 'Sigla',
              value: officer.sigla.trim().isEmpty
                  ? 'No registrada'
                  : officer.sigla,
            ),
            _OfficerInfoField(label: 'C.I.', value: officer.ci),
            _OfficerInfoField(label: 'Usuario', value: officer.username),
            const _OfficerInfoField(label: 'Rol', value: 'POLICE'),
          ],
        ),
      ),
    );
  }
}

class _OfficerInfoField extends StatelessWidget {
  const _OfficerInfoField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.ink.withValues(alpha: 0.66),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.ink.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              value,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficerActionsSection extends StatelessWidget {
  const _OfficerActionsSection({
    required this.officer,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleStatus,
  });

  final OfficerRecord officer;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Acciones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onResetPassword,
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Restablecer contrasena'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onToggleStatus,
              icon: Icon(
                officer.isActive
                    ? Icons.person_off_outlined
                    : Icons.person_outline_rounded,
              ),
              label: Text(
                  officer.isActive ? 'Desactivar usuario' : 'Activar usuario'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficerFormDialog extends StatefulWidget {
  const _OfficerFormDialog({
    required this.controller,
    required this.actor,
    this.officer,
  });

  final OfficerManagementController controller;
  final AuthenticatedUser actor;
  final OfficerRecord? officer;

  @override
  State<_OfficerFormDialog> createState() => _OfficerFormDialogState();
}

class _OfficerFormDialogState extends State<_OfficerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateController;
  late final TextEditingController _gradeController;
  late final TextEditingController _namesController;
  late final TextEditingController _lastNamesController;
  late final TextEditingController _unitController;
  late final TextEditingController _acronymController;
  late final TextEditingController _ciController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late bool _isActive;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.officer != null;

  @override
  void initState() {
    super.initState();
    final officer = widget.officer;
    _plateController = TextEditingController(text: officer?.numeroPlaca);
    _gradeController = TextEditingController(text: officer?.grado);
    _namesController = TextEditingController(text: officer?.nombres);
    _lastNamesController = TextEditingController(text: officer?.apellidos);
    _unitController = TextEditingController(text: officer?.unidad);
    _acronymController = TextEditingController(text: officer?.sigla);
    _ciController = TextEditingController(text: officer?.ci);
    _usernameController = TextEditingController(text: officer?.username);
    _passwordController = TextEditingController();
    _isActive = officer?.isActive ?? true;
  }

  @override
  void dispose() {
    _plateController.dispose();
    _gradeController.dispose();
    _namesController.dispose();
    _lastNamesController.dispose();
    _unitController.dispose();
    _acronymController.dispose();
    _ciController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar policia' : 'Registrar policia'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_plateController, 'Numero de placa', Icons.badge),
                _field(_gradeController, 'Grado', Icons.military_tech),
                _field(_namesController, 'Nombres', Icons.person_outline),
                _field(_lastNamesController, 'Apellidos', Icons.people_outline),
                _field(_unitController, 'Unidad', Icons.apartment_outlined),
                _field(_acronymController, 'Sigla', Icons.short_text,
                    required: false),
                _field(_ciController, 'C.I.', Icons.credit_card),
                _field(_usernameController, 'Usuario', Icons.account_circle),
                if (!_isEditing)
                  _field(
                    _passwordController,
                    'Contrasena inicial',
                    Icons.lock_outline,
                    obscureText: true,
                    validator: _validatePassword,
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Estado activo'),
                  value: _isActive,
                  onChanged: _isEditing
                      ? null
                      : (value) => setState(() {
                            _isActive = value;
                          }),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Guardando' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        obscureText: obscureText,
        textInputAction: TextInputAction.next,
        validator: validator ??
            (value) {
              if (required && (value ?? '').trim().isEmpty) {
                return 'Campo obligatorio.';
              }
              if (label == 'Usuario' && (value ?? '').trim().length < 3) {
                return 'Ingrese al menos 3 caracteres.';
              }
              return null;
            },
      ),
    );
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) {
      return 'Ingrese al menos 8 caracteres.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final officer = widget.officer;
      if (officer == null) {
        await widget.controller.createOfficer(
          actor: widget.actor,
          numeroPlaca: _plateController.text,
          grado: _gradeController.text,
          nombres: _namesController.text,
          apellidos: _lastNamesController.text,
          unidad: _unitController.text,
          sigla: _acronymController.text,
          ci: _ciController.text,
          username: _usernameController.text,
          initialPassword: _passwordController.text,
          isActive: _isActive,
        );
      } else {
        await widget.controller.updateOfficer(
          actor: widget.actor,
          idPolicia: officer.idPolicia,
          idUsuario: officer.idUsuario,
          numeroPlaca: _plateController.text,
          grado: _gradeController.text,
          nombres: _namesController.text,
          apellidos: _lastNamesController.text,
          unidad: _unitController.text,
          sigla: _acronymController.text,
          ci: _ciController.text,
          username: _usernameController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({
    required this.controller,
    required this.actor,
    required this.officer,
  });

  final OfficerManagementController controller;
  final AuthenticatedUser actor;
  final OfficerRecord officer;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restablecer contrasena'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Usuario: ${widget.officer.username}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Nueva contrasena',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              obscureText: true,
              validator: (value) {
                if ((value ?? '').length < 8) {
                  return 'Ingrese al menos 8 caracteres.';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Guardando' : 'Restablecer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.controller.resetPassword(
        actor: widget.actor,
        officer: widget.officer,
        newPassword: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
