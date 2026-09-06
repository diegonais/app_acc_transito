import 'dart:async';

import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/authenticated_user.dart';
import 'package:app_acc_transito/features/reports/application/report_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const actor = AuthenticatedUser(
  idUsuario: 1,
  username: 'policia',
  role: AppRole.police,
  policeProfile: PoliceProfile(
      idPolicia: 1,
      numeroPlaca: '01',
      grado: 'Sgto.',
      nombres: 'José',
      apellidos: 'Muñoz Peña',
      unidad: 'Tránsito',
      sigla: 'UT',
      ci: '01'),
);

void main() {
  test('una consulta antigua no sobreescribe el filtro más reciente', () async {
    final repository = _DelayedRepository();
    final controller = ReportController(repository: repository);
    final first = controller.load(actor);
    final second = controller.load(actor);
    repository.calls[1].complete([]);
    await second;
    repository.calls[0].completeError(StateError('error antiguo'));
    await first;
    expect(controller.errorMessage, isNull);
    expect(controller.isLoading, isFalse);
    controller.dispose();
  });

  test('cerrar sesión invalida consultas pendientes y limpia filtros',
      () async {
    final repository = _DelayedRepository();
    final controller = ReportController(repository: repository);
    final pending =
        controller.load(actor, filter: ReportQueryFilter(from: DateTime(2026)));
    controller.reset();
    repository.calls.single.completeError(StateError('sesión anterior'));
    await pending;
    expect(controller.filter.isEmpty, isTrue);
    expect(controller.reports, isEmpty);
    expect(controller.errorMessage, isNull);
    controller.dispose();
  });

  test('consulta que termina después de dispose no notifica', () async {
    final repository = _DelayedRepository();
    final controller = ReportController(repository: repository);
    final pending = controller.load(actor);
    controller.dispose();
    repository.calls.single.complete([]);
    await pending;
  });
}

class _DelayedRepository extends ReportRepository {
  _DelayedRepository() : super(AppDatabase());
  final calls = <Completer<List<ReportRecord>>>[];

  @override
  Future<List<ReportRecord>> queryActiveReportsForPolice(
      {required int idPolicia,
      ReportQueryFilter filter = const ReportQueryFilter()}) {
    final call = Completer<List<ReportRecord>>();
    calls.add(call);
    return call.future;
  }
}
