import 'package:flutter/material.dart';

import '../../shared/scaffold_shell.dart';
import '../../shared/ui/app_state_view.dart';

class DashboardPlaceholderPage extends StatelessWidget {
  const DashboardPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Inicio',
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: AppEmptyState(
          icon: Icons.space_dashboard_outlined,
          title: 'Dashboard pendiente',
          message: 'Los indicadores se implementaran en una fase posterior.',
        ),
      ),
    );
  }
}
