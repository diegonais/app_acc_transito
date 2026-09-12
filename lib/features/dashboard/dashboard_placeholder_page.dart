import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_theme.dart';
import '../../data/repositories/report_repository.dart';
import '../../shared/scaffold_shell.dart';
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
          tooltip: 'Cerrar sesión',
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _WelcomeCard(
                username: user.username,
                role: user.isAdmin ? 'ADMIN' : 'Policía',
                subtitle: user.isAdmin
                    ? 'Consulta operativa local del dispositivo.'
                    : 'Consulta y registro operativo del dispositivo.',
                profileSummary: user.isAdmin
                    ? 'Administrador'
                    : profile == null
                        ? null
                        : '${profile.grado} ${profile.nombreCompleto}'.trim(),
              ),
              const SizedBox(height: 20),
              if (controller.isLoading && stats == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: AppLoadingState(message: 'Cargando resumen'),
                )
              else if (error != null && stats == null)
                AppErrorState(
                  title: 'No se pudo cargar el resumen',
                  message: error,
                  onRetry: () => controller.load(user),
                )
              else if (stats != null) ...[
                _MetricGrid(
                  twoColumns: user.isAdmin,
                  children: [
                    _MetricCard(
                      compact: user.isAdmin,
                      icon: Icons.assignment_turned_in_outlined,
                      accentColor: AppColors.primaryGreen,
                      backgroundColor: const Color(0xFFEAF8EE),
                      label: user.isAdmin
                          ? 'Informes activos'
                          : 'Mis informes activos',
                      value: stats.totalActiveReports.toString(),
                    ),
                    if (user.isAdmin)
                      _MetricCard(
                        compact: true,
                        icon: Icons.local_police_outlined,
                        accentColor: AppColors.institutionalBlue,
                        backgroundColor: const Color(0xFFEAF5FF),
                        label: 'Policías activos',
                        value: stats.activePoliceCount.toString(),
                      ),
                    _MetricCard(
                      compact: user.isAdmin,
                      icon: Icons.today_outlined,
                      accentColor: AppColors.darkGold,
                      backgroundColor: const Color(0xFFFFF4E3),
                      label: 'Informes del día',
                      value: stats.reportsToday.toString(),
                    ),
                    _MetricCard(
                      compact: user.isAdmin,
                      icon: Icons.calendar_month_outlined,
                      accentColor: const Color(0xFF7B2CBF),
                      backgroundColor: const Color(0xFFF3EAFF),
                      label: 'Informes del mes',
                      value: stats.reportsThisMonth.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _QuickSummarySection(
                  selectedDate: controller.selectedDate,
                  onPickDate: () => _pickDashboardDate(user),
                  children: [
                    if (user.isAdmin)
                      _PoliceSummaryCard(values: stats.reportsByPolice),
                    _MonthlySummaryCard(values: stats.reportsByMonth),
                    _DateSummaryCard(
                      selectedDate: controller.selectedDate,
                      total: stats.reportsBySelectedDate,
                      onPickDate: () => _pickDashboardDate(user),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              if (user.role == AppRole.admin) const _InformationBanner(),
              if (user.role == AppRole.admin) const SizedBox(height: 20),
              _ActionGrid(
                children: [
                  _DashboardActionButton(
                    label: user.isAdmin
                        ? 'Consultar informes'
                        : 'Registrar informe',
                    icon: user.isAdmin
                        ? Icons.assignment_outlined
                        : Icons.note_add_outlined,
                    onPressed: () async {
                      await Navigator.of(context).pushNamed(AppRoutes.reports);
                      if (mounted) await widget.controller.load(user);
                    },
                  ),
                  if (user.role == AppRole.admin)
                    _DashboardActionButton(
                      label: 'Gestionar policías',
                      icon: Icons.groups_2_outlined,
                      onPressed: () async {
                        await Navigator.of(context)
                            .pushNamed(AppRoutes.officers);
                        if (mounted) await widget.controller.load(user);
                      },
                    ),
                ],
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
    required this.username,
    required this.role,
    required this.subtitle,
    this.profileSummary,
  });

  final String username;
  final String role;
  final String subtitle;
  final String? profileSummary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final userInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido,',
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              username,
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _RoleBadge(role: role),
            if (profileSummary != null) ...[
              const SizedBox(height: 10),
              Text(
                profileSummary!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );

        final institutionalText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprometidos\ncon una ciudad\nmás segura',
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.ink.withValues(alpha: 0.92),
                height: 1.22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        );

        return Container(
          decoration: _softCardDecoration(
            background: const Color(0xFFEFFAF2),
            borderColor: AppColors.primaryGreen.withValues(alpha: 0.08),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNarrow) ...[
                  userInfo,
                  const SizedBox(height: 16),
                  institutionalText,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: userInfo),
                      const SizedBox(width: 16),
                      Container(
                        width: 1,
                        height: 92,
                        color: AppColors.ink.withValues(alpha: 0.12),
                      ),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: institutionalText),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              color: AppColors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              role,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children, required this.twoColumns});

  final List<Widget> children;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    if (twoColumns) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index += 2) ...[
            if (index > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[index]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: index + 1 < children.length
                        ? children[index + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth < 560
                ? 1
                : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 150 * MediaQuery.textScalerOf(context).scale(1),
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
    this.compact = false,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final bool compact;
  final Color accentColor;
  final Color backgroundColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      decoration: _softCardDecoration(
        background: backgroundColor,
        borderColor: accentColor.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: compact ? 36 : 54,
              height: compact ? 36 : 54,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accentColor, size: compact ? 24 : 30),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: compact ? null : 2,
                    overflow: compact ? null : TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.86),
                      height: 1.14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSummarySection extends StatelessWidget {
  const _QuickSummarySection({
    required this.selectedDate,
    required this.onPickDate,
    required this.children,
  });

  final DateTime selectedDate;
  final VoidCallback onPickDate;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: _softCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.primaryGreen,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Resumen rápido',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_formatDate(selectedDate)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final useColumns = constraints.maxWidth >= 620;
                final width = useColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: children
                      .map(
                        (child) => SizedBox(
                          width: width,
                          child: child,
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSummaryCard extends StatelessWidget {
  const _DateSummaryCard({
    required this.selectedDate,
    required this.total,
    required this.onPickDate,
  });

  final DateTime selectedDate;
  final int total;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final status = total == 1 ? '1 informe activo' : '$total informes activos';
    return _SummaryCard(
      title: 'Informes por fecha',
      icon: Icons.event_available_outlined,
      emptyMessage: 'No existen informes activos para esta fecha.',
      action: IconButton(
        tooltip: 'Elegir fecha',
        onPressed: onPickDate,
        icon: const Icon(Icons.edit_calendar_outlined),
      ),
      children: [
        _SummaryLine(label: _formatDate(selectedDate), value: status),
      ],
    );
  }
}

class _PoliceSummaryCard extends StatelessWidget {
  const _PoliceSummaryCard({required this.values});

  final List<PoliceReportCount> values;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      title: 'Informes por policía',
      icon: Icons.groups_2_outlined,
      emptyMessage: 'No hay policías activos para resumir.',
      children: values
          .map(
            (value) => _SummaryLine(
              label: value.displayName,
              value: value.total.toString(),
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
            (value) => _SummaryLine(
              label: '${_monthName(value.mes)} ${value.gestion}',
              value: value.total.toString(),
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
    this.action,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: _softCardDecoration(
        background: AppColors.surface,
        borderColor: AppColors.ink.withValues(alpha: 0.04),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryGreen, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            if (children.isEmpty)
              Text(
                emptyMessage,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.62),
                  height: 1.28,
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.ink.withValues(alpha: 0.78),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationBanner extends StatelessWidget {
  const _InformationBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: _softCardDecoration(
        background: const Color(0xFFEAF5FF),
        borderColor: AppColors.institutionalBlue.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.institutionalBlue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.institutionalBlue,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manten tu información actualizada',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestiona policías y revisa los informes para un mejor control operativo.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.64),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns = children.length > 1 && constraints.maxWidth >= 360;
        final width =
            useColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map(
                (child) => SizedBox(
                  width: width,
                  child: child,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _DashboardActionButton extends StatelessWidget {
  const _DashboardActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.primaryGreen,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _softCardDecoration({
  Color background = AppColors.white,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: borderColor ?? AppColors.ink.withValues(alpha: 0.08),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.ink.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
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
