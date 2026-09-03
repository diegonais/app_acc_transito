import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../data/repositories/report_repository.dart';
import '../../shared/scaffold_shell.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_state_view.dart';
import '../auth/application/auth_scope.dart';
import '../auth/domain/app_role.dart';
import '../auth/domain/authenticated_user.dart';
import 'application/dashboard_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).currentUser;
      if (user != null) {
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

    final profile = user.policeProfile;

    return AppScaffoldShell(
      title: 'Inicio',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => widget.controller.load(user),
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Cerrar sesion',
          onPressed: () {
            auth.logout();
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          },
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final stats = controller.stats;
          final error = controller.errorMessage;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WelcomeCard(
                title: user.isAdmin ? 'Administrador' : 'Policia',
                subtitle: user.isAdmin
                    ? 'Consulta operativa local del dispositivo.'
                    : '${profile?.grado ?? ''} ${profile?.nombreCompleto ?? user.username}'
                        .trim(),
                details: [
                  'Usuario: ${user.username}',
                  'Rol: ${user.role.databaseValue}',
                  if (profile != null) 'Unidad: ${profile.unidad}',
                  if (profile != null) 'Placa: ${profile.numeroPlaca}',
                ],
              ),
              const SizedBox(height: 16),
              if (controller.isLoading && stats == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: AppLoadingState(message: 'Cargando dashboard'),
                )
              else if (error != null && stats == null)
                AppErrorState(
                  title: 'No se pudo cargar el dashboard',
                  message: error,
                  onRetry: () => controller.load(user),
                )
              else if (stats != null) ...[
                _MetricGrid(
                  children: [
                    _MetricCard(
                      icon: Icons.assignment_turned_in_outlined,
                      label: user.isAdmin
                          ? 'Informes activos'
                          : 'Mis informes activos',
                      value: stats.totalActiveReports.toString(),
                    ),
                    if (user.isAdmin)
                      _MetricCard(
                        icon: Icons.local_police_outlined,
                        label: 'Policias activos',
                        value: stats.activePoliceCount.toString(),
                      ),
                    _MetricCard(
                      icon: Icons.today_outlined,
                      label: 'Informes del dia',
                      value: stats.reportsToday.toString(),
                    ),
                    _MetricCard(
                      icon: Icons.calendar_month_outlined,
                      label: 'Informes del mes',
                      value: stats.reportsThisMonth.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DateMetricCard(
                  selectedDate: controller.selectedDate,
                  total: stats.reportsBySelectedDate,
                  onPickDate: () => _pickDashboardDate(user),
                ),
                const SizedBox(height: 16),
                if (user.isAdmin)
                  _PoliceSummaryCard(values: stats.reportsByPolice),
                if (user.isAdmin) const SizedBox(height: 16),
                _MonthlySummaryCard(values: stats.reportsByMonth),
              ],
              const SizedBox(height: 16),
              AppButton(
                label:
                    user.isAdmin ? 'Consultar informes' : 'Registrar informe',
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
          );
        },
      ),
    );
  }

  Future<void> _pickDashboardDate(AuthenticatedUser user) async {
    final current = widget.controller.selectedDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 10),
      lastDate: DateTime(current.year + 1),
    );
    if (selected == null || !mounted) {
      return;
    }
    await widget.controller.load(user, selectedDate: selected);
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.title,
    required this.subtitle,
    required this.details,
  });

  final String title;
  final String subtitle;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            ...details.map((detail) => Text(detail)),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 4 ? 1.35 : 1.15,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _DateMetricCard extends StatelessWidget {
  const _DateMetricCard({
    required this.selectedDate,
    required this.total,
    required this.onPickDate,
  });

  final DateTime selectedDate;
  final int total;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_available_outlined),
        title: Text('Informes por fecha: ${_formatDate(selectedDate)}'),
        subtitle:
            Text(total == 1 ? '1 informe activo' : '$total informes activos'),
        trailing: IconButton(
          tooltip: 'Elegir fecha',
          onPressed: onPickDate,
          icon: const Icon(Icons.edit_calendar_outlined),
        ),
      ),
    );
  }
}

class _PoliceSummaryCard extends StatelessWidget {
  const _PoliceSummaryCard({required this.values});

  final List<PoliceReportCount> values;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      title: 'Informes por policia',
      icon: Icons.badge_outlined,
      emptyMessage: 'No hay policias activos para resumir.',
      children: values
          .map(
            (value) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(value.displayName),
              trailing: Text(
                value.total.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({required this.values});

  final List<MonthlyReportCount> values;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      title: 'Informes por mes',
      icon: Icons.stacked_bar_chart_outlined,
      emptyMessage: 'No existen informes activos en el periodo registrado.',
      children: values
          .map(
            (value) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${_monthName(value.mes)} ${value.gestion}'),
              trailing: Text(
                value.total.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (children.isEmpty) Text(emptyMessage) else ...children,
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}

String _monthName(int month) {
  const months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return months[month - 1];
}
